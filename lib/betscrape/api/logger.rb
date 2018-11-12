require 'logger'
require 'forwardable'
require 'json'

module API
  class Logger
    extend Forwardable

    attr_reader :logger

    def initialize
      @logger ||= ::Logger.new('/logs/english_premier_league.log', 'daily')
      logger.formatter = proc do |severity, datetime, progname, data|
        #msg_data = JSON.parse(msg)
        log_data = {
          timestamp: datetime.to_s,
          severity: severity,
          data: data
        }
        "#{data.to_json}\n"
      end
    end

    def_delegators :logger, :info, :error, :warn, :debug
  end
end
