.PHONY : build console help
.DEFAULT_GOAL := build-image

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## Build image with python and go dependencies - requires a vm-name to copy credentitials from, i.e. make build myvm=of1-dev-eescalante
	docker build -t betscrape-etl .

console: ## Run the container and log you into a bash shell inside it
	docker run -v ${CURDIR}:/etl -it betscrape-etl bash

