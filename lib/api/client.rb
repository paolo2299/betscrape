require 'httparty'
require 'json'

require_relative 'login_client'

module API
  class Client
    include HTTParty

    KEYS_FOLDER = "#{File.expand_path('.')}/keys".freeze

    base_uri "https://api.betfair.com/exchange/betting/rest/v1.0/"
    debug_output $stdout

    def self.list_event_types(market_filter = {})
      request('listEventTypes', {filter: market_filter})
    end

    def self.list_competitions(market_filter = {})
      request('listCompetitions', {filter: market_filter})
    end

    def self.list_events(market_filter = {})
      request('listEvents', {filter: market_filter})
    end

    def self.list_market_types(market_filter = {})
      request('listMarketTypes', {filter: market_filter})
    end

    def self.list_countries(market_filter = {})
      request('listCountries', {filter: market_filter})
    end

    class MarketProjection
      COMPETITION = 'COMPETITION'.freeze
      EVENT = 'EVENT'.freeze
      EVENT_TYPE = 'EVENT_TYPE'.freeze
      MARKET_START_TIME = 'MARKET_START_TIME'.freeze
      MARKET_DESCRIPTION = 'MARKET_DESCRIPTION'.freeze
      RUNNER_DESCRIPTION = 'RUNNER_DESCRIPTION'.freeze # just for horses?
      RUNNER_METADATA = 'RUNNER_METADATA'.freeze # just for horses?
    end

    class MarketSort
      RANK = 'RANK'.freeze # black box sort based on lots of criteria
      MINIMUM_TRADED = 'MINIMUM_TRADED'.freeze
      MAXIMUM_TRADED = 'MAXIMUM_TRADED'.freeze
      MINIMUM_AVAILABLE = 'MINIMUM_AVAILABLE'.freeze
      MAXIMUM_AVAILABLE = 'MAXIMUM_AVAILABLE'.freeze
      FIRST_TO_START = 'FIRST_TO_START'.freeze
      LAST_TO_START = 'LAST_TO_START'.freeze
    end

    def self.list_market_catalogue(market_filter = {}, max_results = 100, market_projection = [], market_sort = nil)
      raise 'max_results must be <= 1000' unless max_results <= 1000
      options = {filter: market_filter, maxResults: max_results}
      options[:marketProjection] = market_projection if market_projection.any?
      options[:sort] = market_sort if market_sort
      request('listMarketCatalogue', options)
    end

    class PriceProjection
      def to_hash
        {}
      end
    end

    class OrderProjection
    end

    def self.list_market_book(market_ids = [], price_projection = nil, order_projection = nil)
      options = {marketIds: market_ids.map(&:to_str)}
      options[:priceProjection] = price_projection.to_hash if price_projection
      options[:orderProjection] = order_projection if order_projection
      request('listMarketBook', options)
    end

    private

    def self.request(action, options = nil)
      body = options ? options.to_json : ''
      response = post("/#{action}/", body: body, headers: headers)
      #TODO - error handling
      response.parsed_response
    end

    def self.session_token
      @session_token ||= begin
        API::LoginClient.log_in!
        API::LoginClient.session_token
      end
    end

    def self.headers
      {
        'X-Application' => betfair_app_token,
        'X-Authentication' => session_token,
        'Content-Type'  => 'application/json',
        'Accept' => 'application/json'
      }
    end
    
    def self.betfair_app_token
      File.read(betfair_app_token_path)
    end

    def self.betfair_app_token_path
      "#{KEYS_FOLDER}/betfair_app_token"
    end
  end
end
