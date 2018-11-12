FROM ruby:2.4

WORKDIR /betscrape
COPY Gemfile* /betscrape/
RUN bundle install --path=/vendor/bundle

