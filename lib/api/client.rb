require 'httparty'
require 'json'

require_relative 'login_client'

module API
  class Client
    include HTTParty

    KEYS_FOLDER = "#{File.expand_path('.')}/keys".freeze

    base_uri "https://api.betfair.com/exchange/betting/rest/v1.0/"
    #debug_output $stdout

    def self.session_token
      @session_token ||= begin
        API::LoginClient.log_in!
        API::LoginClient.session_token
      end
    end

    def self.get_event_types
      body = '{"filter":{}}'
      response = post('/listEventTypes/', body: body, headers: headers)
      data = response.parsed_response
      pp data
    end

    private

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
