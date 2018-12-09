import parser
import argparse
import json
import sys
import apache_beam as beam
from datetime import datetime, timedelta
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.options.pipeline_options import StandardOptions
from apache_beam.options.pipeline_options import GoogleCloudOptions
from apache_beam.options.pipeline_options import SetupOptions
from apache_beam.options.pipeline_options import WorkerOptions


class ETLJob:

    def __init__(self, name):
        parser = ETLJob.new_argparser()
        known_args, pipeline_args = parser.parse_known_args()
        options = PipelineOptions(pipeline_args)
        options.view_as(GoogleCloudOptions).project = 'betscrape'
        options.view_as(
            GoogleCloudOptions).staging_location = 'gs://load-jobs-temp/binaries'
        options.view_as(
            GoogleCloudOptions).temp_location = 'gs://load-jobs-temp/temp'
        if known_args.run_in_cloud:
            options.view_as(SetupOptions).setup_file = './setup.py'
            options.view_as(SetupOptions).sdk_location = './dependencies'
            options.view_as(GoogleCloudOptions).job_name = name
            options.view_as(GoogleCloudOptions).view_as(
                StandardOptions).runner = 'DataflowRunner'
        self.name = name
        self.pipeline = beam.Pipeline(options=options)
        self.run_in_cloud = known_args.run_in_cloud
        self.run_date = known_args.run_date

    @staticmethod
    def new_argparser():
        parser = argparse.ArgumentParser()
        parser.add_argument('--run-in-cloud',
                            dest='run_in_cloud',
                            type=bool,
                            default=False,
                            help='set to true to run in Google Cloud Dataflow. Otherwise will run locally')
        parser.add_argument('--run-date',
                            dest='run_date',
                            type=str,
                            help='date of logfiles to add to BigQuery. Should be of form YYYYMMDD')
        return parser

    @property
    def input_base_dir(self):
        if self.run_in_cloud:
            return 'gs://betscrape-api-logs'
            #return 'gs://betscrape-test-data'
        else:
            return './data'
