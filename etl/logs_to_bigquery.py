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
from sk.sk_etl_job import SKETLJob
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

    def is_list_competition_response(self, data):
        return self.is_api_response(data) and data['data']['action'] == 'listCompetitions'

    def is_list_events_response(self, data):
        return self.is_api_response(data) and data['data']['action'] == 'listEvents'

    def is_list_market_catalogue_response(self, data):
        return self.is_api_response(data) and data['data']['action'] == 'listMarketCatalogue'

    def is_list_market_book_response(self, data):
        return self.is_api_response(data) and data['data']['action'] == 'listMarketBook'

class DataExtractor:
    def __init__(self):
        from datetime import datetime

    def timestamp(self, data):
        dt = datetime.strptime(data['timestamp'][0:19], "%Y-%m-%d %H:%M:%S" )
        return dt.isoformat()

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
            yield {
                'timestamp': ts,
                'total_matched': market['totalMatched'], # float
                'name': market['marketName'],
                'event_id': market['event']['id'],
                'id': market['marketId'],
            }

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
                    data['price'] = back['price']
                    data['size'] = back['size']
                    yield data

def run(argv=None):
    start_time = datetime.today()
    now = datetime.now().strftime("%Y-%m-%d-%H-%M-%f")
    job = SKETLJob('parse-betsrape-logs-%s' % now)
    pipeline = job.pipeline
    parser = LogParser()
    filter = LogFilter()
    extractor = DataExtractor()

    filepath = "%s/*" % job.input_base_dir

    # parse the logs
    lines = (pipeline
      | 'read' >> ReadFromText(filepath)
      | 'parse' >> beam.FlatMap(parser.parse_line)
    )

    (lines
      | 'filter list competition' >> beam.Filter(filter.is_list_competition_response)
      | 'extract competition data' >> beam.FlatMap(extractor.extract_competitions)
      | 'write competition' >> beam.io.WriteToText('./output/comp')
    )

    (lines
      | 'filter list events' >> beam.Filter(filter.is_list_events_response)
      | 'extract event data' >> beam.FlatMap(extractor.extract_events)
      | 'write events' >> beam.io.WriteToText('./output/events')
    )

    market_catalogue = (lines
      | 'filter list market catalogue' >> beam.Filter(filter.is_list_market_catalogue_response)
    )

    (market_catalogue
      | 'extract markets' >> beam.FlatMap(extractor.extract_markets_from_catalogue)
      | 'write markets' >> beam.io.WriteToText('./output/markets')
    )

    (market_catalogue
      | 'extract runners' >> beam.FlatMap(extractor.extract_runner_metadata_from_catalogue)
      | 'write runners' >> beam.io.WriteToText('./output/runner_metadata')
    )

    (lines
      | 'filter list market book' >> beam.Filter(filter.is_list_market_book_response)
      | 'extract market book' >> beam.FlatMap(extractor.extract_market_book)
      | 'write market book' >> beam.io.WriteToText('./output/book')
    )


    # save to BigQuery
    #schema = bigquery.TableSchema(
    #    fields=[
    #        bigquery.TableFieldSchema(
    #            name='hostname', type='STRING', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='pid', type='STRING', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='client_ip', type='STRING', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='client_port', type='INTEGER', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='log_time', type='DATETIME', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='frontend_name', type='STRING', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='backend', type='STRING', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='wait_stats', type='STRING', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='status_code', type='INTEGER', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='bytes_read', type='INTEGER', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='connection_stats', type='STRING', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='queue_stats', type='STRING', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='method', type='STRING', mode='REQUIRED'),
    #        bigquery.TableFieldSchema(
    #            name='path', type='STRING', mode='REQUIRED'),
    #    ])

    #(log_data
    #    | 'save' >> beam.io.Write(
    #        beam.io.BigQuerySink(
    #            'scratchpad.haproxy_logs',
    #            schema=schema,
    #            write_disposition=beam.io.BigQueryDisposition.WRITE_TRUNCATE
    #            create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
    #        ))
    # )

    result = pipeline.run()
    result.wait_until_finish()

if __name__ == '__main__':
    logger = logging.getLogger().setLevel(logging.INFO)
    run()