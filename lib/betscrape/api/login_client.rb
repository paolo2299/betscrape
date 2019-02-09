require 'httparty'
require 'yaml'
require 'json'

module API
  class LoginClient
    class LoginFailedError < StandardError; end

    include HTTParty

    KEYS_FOLDER = "#{File.expand_path('.')}/keys".freeze
    SSL_CERT_PATH = "#{KEYS_FOLDER}/client-2048.pem".freeze

    pem File.read(SSL_CERT_PATH)

    def self.session_token
      @session_token
    end

    def self.log_in!
      @session_token = get_session_token
    end

    private

    def self.get_session_token
      response = post('https://identitysso-cert.betfair.com/api/certlogin', body: body, headers: headers)
      data = JSON.parse(response.parsed_response)
      login_status = data.fetch('loginStatus')
      unless login_status == 'SUCCESS'
        raise "login request failed with status: #{login_status}"
      end
      data.fetch('sessionToken')
    end

    def self.headers
      {
        'X-Application' => 'pdlawson_betfair',
        'Content-Type'  => 'application/x-www-form-urlencoded'
      }
    end

    def self.body
      credentials
    end
    
    def self.credentials
      YAML.load(File.read(credentials_path))
    end

    def self.credentials_path
      "#{KEYS_FOLDER}/credentials"
    end
  end
end
