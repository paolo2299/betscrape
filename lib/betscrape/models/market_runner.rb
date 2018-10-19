module Models
  class MarketRunner
    attr_reader :data

    def initialize(data)
      @data = data
    end

    #(integer)
    def id
      data.fetch('selectionId')
    end

    # e.g. Man City
    # only available in Market via MarketProjection
    # so not available inside MarketBook
    def name
      data.fetch('runnerName')
    end

    #(float)
    def handicap
      data.fetch('handicap')
    end

    # (integer)
    # only available in Market via MarketProjection
    # so not available inside MarketBook
    def sort_priority
      data.fetch('sortPriority')
    end

    # one of ACTIVE, OPEN, ???
    # only available in MarketBook
    # so not available inside Market
    def status
      data.fetch('status')
    end

    # e.g. 1.67
    # only available in MarketBook
    # so not available inside Market
    def last_price_traded
      data.fetch('lastPriceTraded')
    end

    # (float)
    # only available in MarketBook
    # so not available inside Market
    # always 0.0 for delayed access key
    def total_matched
      data.fetch('totalMatched')
    end

    # (hash)
    # only available in Market via MarketProjection::RUNNER_METADATA
    # so not available inside MarketBook
    # not sure in what circumstances this contains useful data (horses maybe?)
    # as all I've seen is a repeat of the runner ID
    def metadata
      data.fetch('metadata')
    end

    def best_offers
      if data['ex'].nil?
        msg = 'You need to specify a PriceProjection'
        raise MissingProjectionError msg
      end
      BestOffer.new(data.fetch('ex'))
    end
  end
end

