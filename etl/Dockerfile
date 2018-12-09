FROM python:2.7-alpine3.7

# OS level dependencies
RUN apk add --no-cache gcc linux-headers musl-dev build-base openssl openssl-dev libffi-dev python-dev bash

# Python setup
RUN mkdir python
ADD python/requirements.txt python/requirements.txt
RUN pip install virtualenv
RUN virtualenv python
RUN . python/bin/activate
RUN cd python && pip install -r requirements.txt
ADD gcp/service_account.json /gcp/service_account.json
ENV GOOGLE_APPLICATION_CREDENTIALS=/gcp/service_account.json

WORKDIR etl
