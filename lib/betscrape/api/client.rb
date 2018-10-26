require 'httparty'
require 'json'

module API
  class Client
    include HTTParty

    KEYS_FOLDER = "#{File.expand_path('.')}/keys".freeze

    base_uri "https://api.betfair.com/exchange/betting/rest/v1.0/"

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

    def self.list_market_catalogue(market_filter = {}, max_results = 1000, market_projection = [], market_sort = nil)
      raise 'max_results must be <= 1000' unless max_results <= 1000
      options = {filter: market_filter, maxResults: max_results}
      options[:marketProjection] = market_projection if market_projection.any?
      options[:sort] = market_sort if market_sort
      request('listMarketCatalogue', options, 20)
    end

    def self.list_market_book(market_ids = [], price_projection = nil, order_projection = nil)
      options = {marketIds: market_ids.map(&:to_str)}
      options[:priceProjection] = price_projection.to_hash if price_projection
      options[:orderProjection] = order_projection if order_projection
      request('listMarketBook', options)
    end

    private

    def self.request(action, options = nil, timeout = 10)
      body = options ? options.to_json : ''
      begin
        retries ||= 0
        response = post("/#{action}/", body: body, headers: headers, timeout: timeout)
      rescue Net::ReadTimeout
        log_timeout_retry(action, options)
        retry if (retries += 1) < 3
        raise "request failed (too many retries): #{action}"
      end
      #TODO - error handling
      log_response(response, action, options)
      response.parsed_response
    end

    def self.log_response(response, action, options)
      logger.info({
        log_type: 'api_response',
        action: action,
        options: options,
        response: response.parsed_response
      })
    end

    def self.log_request_error(error_msg, action, options)
      logger.error({
        log_type: 'api_error',
        action: action,
        options: options,
        error_msg: error_msg
      })
    end

    def self.log_timeout_retry(action, options)
      logger.warn({
        log_type: 'api_retry',
        action: action,
        options: options,
      })
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
      @betfair_app_token ||= File.read(betfair_app_token_path)
    end

    def self.betfair_app_token_path
      "#{KEYS_FOLDER}/betfair_app_token"
    end

    def self.logger
      @logger ||= API::Logger.new
    end
  end
end
