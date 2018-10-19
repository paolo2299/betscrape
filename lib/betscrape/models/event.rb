module Models
  class Event
    def self.all_for_competition(competition)
      market_filter = MarketFilter.new.add_competition(competition)
      # TODO can we add an option for in-play only here?
      # TODO does this also return events that are ended?
      event_datas = API::Client.list_events(market_filter.to_hash)
      event_datas.map {|data| new(data.fetch('event'), data.fetch('marketCount'))}
    end

    attr_reader :data, :market_count

    # market count is returned when calling list_events in the API,
    # but not when it is part of a projection from another call
    def initialize(data, market_count = nil)
      @data = data
    end

    def id
      data.fetch('id')
    end

    def name
      data.fetch('name')
    end

    def country_code
      data.fetch('countryCode')
    end

    def timezone
      data.fetch('timezone')
    end

    # TODO check this works for non-UK events
    # TODO what happens for in play markets?
    # TODO what happens for closed markets?
    def open_datetime
      Time.parse(data.fetch('openDate'))
    end

    def in_play?
      # TODO (if possible, or could use marketFilter)
    end

    def closed?
      # TODO (if possible)
    end
  end
end
