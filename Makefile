build:
	sudo docker build -t betscrape:latest .

console:
	docker run --rm -it -v $(shell pwd):/betscrape betscrape:latest bash
