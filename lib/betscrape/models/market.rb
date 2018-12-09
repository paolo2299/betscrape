module Models
  class Market
    class MissingProjectionError < StandardError; end

    def self.top_for_events(events, limit = 1000, market_projection = [MarketProjection::EVENT, MarketProjection::MARKET_START_TIME])
      market_filter = MarketFilter.new.add_events(events)
      market_datas = API::Client.list_market_catalogue(market_filter.to_hash, limit, market_projection)
      market_datas.map{|data| new(data)}
    end

    attr_reader :data

    def initialize(data)
      @data = data
    end

    def id
      data.fetch('marketId')
    end

    def name
      data.fetch('marketName')
    end

    def total_matched
      data.fetch('totalMatched')
    end

    def market_start_time
      if data['marketStartTime'].nil?
        msg = 'You need to specify MarketProjection::MARKET_START_TIME as a projection'
        raise MissingProjectionError msg
      end
      Time.parse(data.fetch('marketStartTime'))
    end

    def started?
      Time.now >= market_start_time
    end

    def event
      if data['event'].nil?
        msg = 'You need to specify MarketProjection::EVENT as a projection'
        raise MissingProjectionError msg
      end
      Event.new(data.fetch('event'))
    end

    def competition
      if data['competition'].nil?
        msg = 'You need to specify MarketProjection::COMPETITION as a projection'
        raise MissingProjectionError msg
      end
      Competition.new(data.fetch('competition'))
    end

    def event_type
      if data['eventType'].nil?
        msg = 'You need to specify MarketProjection::EVENT_TYPE as a projection'
        raise MissingProjectionError msg
      end
      EventType.new(data.fetch('eventType'))
    end

    def description
      if data['description'].nil?
        msg = 'You need to specify MarketProjection::MARKET_DESCRIPTION as a projection'
        raise MissingProjectionError msg
      end
      MarketDescription.new(data.fetch('description'))
    end

    def runners
      if data['runners'].nil?
        msg = 'You need to specify MarketProjection::RUNNER_DESCRIPTION or MarketProjection::RUNNER_METADATA as a projection'
        raise MissingProjectionError msg
      end
      data.fetch('runners').map do |runner_data|
        MarketRunner.new(runner_data)
      end
    end
  end
end
