import sys
import logging
import json
import re
from datetime import datetime
import warnings
with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    import apache_beam as beam
from apache_beam.io.gcp.internal.clients import bigquery
from apache_beam.metrics import Metrics
from etl_job import ETLJob
from apache_beam.io import ReadFromText


class LogParser:
    def __init__(self):
        self.comments_counter = Metrics.counter(
            self.__class__, 'comments')

    def parse_line(self, line):
        if '# Logfile created on' in line:
            self.comments_counter.inc()
            return

        yield json.loads(line)

class LogFilter:
    def is_api_response(self, data):
        return data['data']['log_type'] == 'api_response'

    def is_empty_response(self, data):
        return data['data']['response'] is None

    def is_error(self, data):
        if self.is_empty_response(data):
            return False
        return ('faultstring' in data['data']['response'])

    def is_error_response(self, data):
        return self.is_api_response(data) and self.is_error(data)

    def is_success_response(self, data):
        if not self.is_api_response(data):
            return False
        if self.is_empty_response(data):
            return False
        return not self.is_error(data)

    def is_list_competition_response(self, data):
        return self.is_success_response(data) and (data['data']['action'] == 'listCompetitions')

    def is_list_events_response(self, data):
        return self.is_success_response(data) and (data['data']['action'] == 'listEvents')

    def is_list_market_catalogue_response(self, data):
        return self.is_success_response(data) and (data['data']['action'] == 'listMarketCatalogue')

    def is_list_market_book_response(self, data):
        return self.is_success_response(data) and (data['data']['action'] == 'listMarketBook')

class DataExtractor:
    def __init__(self):
        self.invalid_counter = Metrics.counter(
            self.__class__, 'invalid competition lines')

    def timestamp(self, data):
        from datetime import datetime
        dt = datetime.strptime(data['timestamp'][0:19], "%Y-%m-%d %H:%M:%S" )
        return dt.isoformat()

    def format_datetime(self, dt):
        from datetime import datetime
        parsed = datetime.strptime(dt[0:19], "%Y-%m-%dT%H:%M:%S" )
        return parsed.isoformat()

    def extract_competitions(self, data):
        ts = self.timestamp(data)
        competitions = data['data']['response']
        for competition in competitions:
            yield {
                'timestamp': ts,
                'id': competition['competition']['id'],
                'name': competition['competition']['name'],
                'region': competition['competitionRegion'],
                'market_count': competition['marketCount'],
            }

    def extract_error(self, data):
        ts = self.timestamp(data)
        return {
            'timestamp' : ts,
            'log_message': json.dumps(data)
        }

    def extract_events(self, data):
        ts = self.timestamp(data)
        events = data['data']['response']
        for event in events:
            yield {
                'timestamp': ts,
                'timezone': event['event']['timezone'],
                'open_date_str': event['event']['openDate'],
                'id': event['event']['id'],
                'country_code': event['event']['countryCode'],
                'name': event['event']['name'],
                'market_count': event['marketCount'],
            }

    def extract_markets_from_catalogue(self, data):
        ts = self.timestamp(data)
        markets = data['data']['response']
        for market in markets:
            data = {
                'timestamp': ts,
                'total_matched': market['totalMatched'], # float
                'name': market['marketName'],
                'event_id': market['event']['id'],
                'id': market['marketId']
            }
            if 'marketStartTime' in market:
                data['start_time'] = self.format_datetime(market['marketStartTime'])
            yield data 

    def extract_runner_metadata_from_catalogue(self, data):
        ts = self.timestamp(data)
        markets = data['data']['response']
        for market in markets:
            market_id = market['marketId']
            event_id = market['event']['id']
            runners = market['runners']
            for runner in runners:
                yield {
                    'timestamp': ts,
                    'market_id': market_id,
                    'event_id': event_id,
                    'selection_id': runner['selectionId'],
                    'name': runner['runnerName'],
                    'sort_priority': runner['sortPriority'],
                    'handicap': runner['handicap'], # float
                }

    def extract_market_book(self, data):
        import copy
        ts = self.timestamp(data)
        virtualise = data['data']['options']['priceProjection']['virtualise']
        books = data['data']['response']
        for book in books:
            for runner in book['runners']:
                runner_data = {
                    'timestamp': ts,
                    'book_status': book['status'],
                    'market_data_delayed': book['isMarketDataDelayed'], #bool
                    'number_of_runners': book['numberOfRunners'],
                    'complete': book['complete'], #bool
                    'bsp_reconciled': book['bspReconciled'], #bool
                    'runners_voidable': book['runnersVoidable'], # bool
                    'bet_delay': book['betDelay'], # int
                    'market_id': book['marketId'], #str
                    'cross_matching': book['crossMatching'], #bool
                    'version': book['version'], # int
                    'number_of_winners': book['numberOfWinners'],
                    'inplay': book['inplay'], #bool
                    'number_of_active_runners': book['numberOfActiveRunners'],
                    'total_available': book['totalAvailable'], #float
                    'runner_status': runner['status'],
                    'runner_handicap': runner['handicap'], # float
                    'runner_selection_id': runner['selectionId'], #int
                    'virtualized_prices': virtualise, #bool
                }
                if 'lastMatchTime' in book:
                    runner_data['last_match_time_str'] = book['lastMatchTime']
                if 'totalMatched' in book:
                    runner_data['total_matched'] = book['totalMatched'] #float
                if 'lastPriceTraded' in runner:
                    runner_data['runner_last_price_traded'] = runner['lastPriceTraded']
                if 'totalMatched' in runner:
                    runner_data['runner_total_matched'] = runner['totalMatched']
                for back in runner['ex']['availableToBack']:
                    data = copy.copy(runner_data)
                    data['bet_type'] = 'back'
                    data['price'] = back['price']
                    data['size'] = back['size']
                    yield data
                for lay in runner['ex']['availableToLay']:
                    data = copy.copy(runner_data)
                    data['bet_type'] = 'lay'
                    data['price'] = lay['price']
                    data['size'] = lay['size']
                    yield data

class BigQueryLoader:
    def __init__(self, dataset):
        self.dataset = dataset

    def destination(self, tablename):
        return "%s.%s" % (self.dataset, tablename)

    def competition_sink(self):
        return beam.io.BigQuerySink(
                  self.destination('competitions'),
                  schema=self.competition_schema(),
                  create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER,
                  write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND
                )

    def competition_schema(self):
        return bigquery.TableSchema(
                fields=[
                    bigquery.TableFieldSchema(
                        name='timestamp', type='TIMESTAMP', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='id', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='name', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='region', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='market_count', type='INTEGER', mode='REQUIRED'),
                ])

    def event_sink(self):
        return beam.io.BigQuerySink(
                  self.destination('events'),
                  schema=self.event_schema(),
                  create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER,
                  write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND
                )

    def event_schema(self):
        return bigquery.TableSchema(
                fields=[
                    bigquery.TableFieldSchema(
                        name='timestamp', type='TIMESTAMP', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='id', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='name', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='timezone', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='market_count', type='INTEGER', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='open_date_str', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='country_code', type='STRING', mode='REQUIRED'),
                ])

    def market_sink(self):
        return beam.io.BigQuerySink(
                  self.destination('markets'),
                  schema=self.market_schema(),
                  create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER,
                  write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND
                )

    def market_schema(self):
        return bigquery.TableSchema(
                fields=[
                    bigquery.TableFieldSchema(
                        name='timestamp', type='TIMESTAMP', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='id', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='name', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='total_matched', type='FLOAT', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='event_id', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='start_time', type='TIMESTAMP', mode='NULLABLE'),
                ])

    def runner_sink(self):
        return beam.io.BigQuerySink(
                  self.destination('runners'),
                  schema=self.runner_schema(),
                  create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER,
                  write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND
                )

    def runner_schema(self):
        return bigquery.TableSchema(
                fields=[
                    bigquery.TableFieldSchema(
                        name='timestamp', type='TIMESTAMP', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='selection_id', type='INTEGER', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='name', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='market_id', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='event_id', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='sort_priority', type='INTEGER', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='handicap', type='FLOAT', mode='REQUIRED'),
                ])

    def market_book_sink(self):
        return beam.io.BigQuerySink(
                  self.destination('market_books'),
                  schema=self.market_book_schema(),
                  create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER,
                  write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND
                )

    def market_book_schema(self):
        return bigquery.TableSchema(
                fields=[
                    bigquery.TableFieldSchema(
                        name='timestamp', type='TIMESTAMP', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='book_status', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='market_data_delayed', type='BOOLEAN', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='number_of_runners', type='INTEGER', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='complete', type='BOOLEAN', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='bsp_reconciled', type='BOOLEAN', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='runners_voidable', type='BOOLEAN', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='bet_delay', type='INTEGER', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='market_id', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='cross_matching', type='BOOLEAN', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='version', type='INTEGER', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='number_of_winners', type='INTEGER', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='inplay', type='BOOLEAN', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='number_of_active_runners', type='INTEGER', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='total_available', type='FLOAT', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='runner_status', type='STRING', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='runner_handicap', type='FLOAT', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='runner_selection_id', type='INTEGER', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='virtualized_prices', type='BOOLEAN', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='last_match_time_str', type='STRING', mode='NULLABLE'),
                    bigquery.TableFieldSchema(
                        name='total_matched', type='FLOAT', mode='NULLABLE'),
                    bigquery.TableFieldSchema(
                        name='runner_last_price_traded', type='FLOAT', mode='NULLABLE'),
                    bigquery.TableFieldSchema(
                        name='runner_total_matched', type='FLOAT', mode='NULLABLE'),
                    bigquery.TableFieldSchema(
                        name='price', type='FLOAT', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='size', type='FLOAT', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='bet_type', type='STRING', mode='REQUIRED'),
                ])

    def error_sink(self):
        return beam.io.BigQuerySink(
                  self.destination('errors'),
                  schema=self.error_schema(),
                  create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER,
                  write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND
                )

    def error_schema(self):
        return bigquery.TableSchema(
                fields=[
                    bigquery.TableFieldSchema(
                        name='timestamp', type='DATETIME', mode='REQUIRED'),
                    bigquery.TableFieldSchema(
                        name='log_message', type='STRING', mode='REQUIRED'),
                ])

def run(argv=None):
    from datetime import datetime
    start_time = datetime.today()
    now = datetime.now().strftime("%Y-%m-%d-%H-%M-%f")
    job = ETLJob('betscrape-%s' % now)
    pipeline = job.pipeline

    parser = LogParser()
    filter = LogFilter()
    extractor = DataExtractor()
    
    loader = BigQueryLoader('logs')

    run_date = job.run_date

    filepath = "%s/*%s*" % (job.input_base_dir, job.run_date)

    # parse the logs
    lines = (pipeline
      | 'read' >> ReadFromText(filepath)
      | 'parse' >> beam.FlatMap(parser.parse_line)
    )

    (lines
      | 'filter list competition' >> beam.Filter(filter.is_list_competition_response)
      | 'extract competition data' >> beam.FlatMap(extractor.extract_competitions)
      #| 'write competition' >> beam.io.WriteToText('./output/comp')
      | 'load competition' >> beam.io.Write(loader.competition_sink())
    )

    (lines
      | 'filter list events' >> beam.Filter(filter.is_list_events_response)
      | 'extract event data' >> beam.FlatMap(extractor.extract_events)
      #| 'write events' >> beam.io.WriteToText('./output/events')
      | 'load events' >> beam.io.Write(loader.event_sink())
    )

    market_catalogue = (lines
      | 'filter list market catalogue' >> beam.Filter(filter.is_list_market_catalogue_response)
    )

    (market_catalogue
      | 'extract markets' >> beam.FlatMap(extractor.extract_markets_from_catalogue)
      #| 'write markets' >> beam.io.WriteToText('./output/markets')
      | 'load markets' >> beam.io.Write(loader.market_sink())
    )

    (market_catalogue
      | 'extract runners' >> beam.FlatMap(extractor.extract_runner_metadata_from_catalogue)
      #| 'write runners' >> beam.io.WriteToText('./output/runner_metadata')
      | 'load runners' >> beam.io.Write(loader.runner_sink())
    )

    (lines
      | 'filter list market book' >> beam.Filter(filter.is_list_market_book_response)
      | 'extract market book' >> beam.FlatMap(extractor.extract_market_book)
      #| 'write market book' >> beam.io.WriteToText('./output/book')
      | 'load market book' >> beam.io.Write(loader.market_book_sink())
    )

    (lines
      | 'filter errors' >> beam.Filter(filter.is_error_response)
      | 'extract errors' >> beam.Map(extractor.extract_error)
      #| 'write errors' >> beam.io.WriteToText('./output/errors')
      | 'load errors' >> beam.io.Write(loader.error_sink())
    )

    result = pipeline.run()
    result.wait_until_finish()

if __name__ == '__main__':
    logger = logging.getLogger().setLevel(logging.INFO)
    run()
