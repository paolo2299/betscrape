.PHONY : build console help
.DEFAULT_GOAL := build-image

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## Build image with python and go dependencies
	docker build -t betscrape-etl .

console: ## Run the container and log you into a bash shell inside it
	docker run --rm -v ${CURDIR}:/etl:Z -it betscrape-etl bash

run_for_date: ## Import logs for a specific date to BigQuery (use RUN_DATE env variable)
	docker run --rm -v ${CURDIR}:/etl:Z betscrape-etl python logs_to_bigquery.py --run-in-cloud=True --run-date=${RUN_DATE}
