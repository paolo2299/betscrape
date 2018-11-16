require 'logger'
require 'forwardable'
require 'json'

module API
  class Logger
    extend Forwardable

    attr_reader :logger

    def self.initialize(namespace1, namespace2)
      @namespace1 = namespace1
      @namespace2 = namespace2
    end

    def self.namespace1
      @namespace1
    end

    def self.namespace2
      @namespace2
    end

    def initialize
      @logger = ::Logger.new("/logs/#{namespace1}.#{Date.today.strftime('%Y%m%d')}.#{namespace2}.log")
      logger.formatter = proc do |severity, datetime, progname, data|
        #msg_data = JSON.parse(msg)
        log_data = {
          timestamp: datetime.to_s,
          severity: severity,
          data: data
        }
        "#{log_data.to_json}\n"
      end
    end

    def namespace1
      self.class.namespace1
    end

    def namespace2
      self.class.namespace2
    end

    def_delegators :logger, :info, :error, :warn, :debug
  end
end
