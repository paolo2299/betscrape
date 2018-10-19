module Models
  class MarketBook
    def self.for_markets(markets, price_projection = nil)
      price_projection ||= PriceProjection.new
      market_ids = markets.map(&:id)
      book_datas = API::Client.list_market_book(market_ids, price_projection)
      book_datas.map{|data| new(data)}
    end

    attr_reader :data

    def initialize(data)
      @data = data
    end

    def market_id
      data.fetch('marketId')
    end

    # not sure what this is.
    # always true for delayed key, false for non-delayed key?
    def data_delayed?
      data.fetch('isMarketDataDelayed')
    end

    # Possible values: OPEN, ???
    def status
      data.fetch('status')
    end

    # Example value 0
    # Not sure what this is
    def bet_delay
      data.fetch('betDelay')
    end

    # Don't know what this is
    def bsp_reconciled?
      data.fetch('bspReconciled')
    end

    # Does this mean market is done?
    def complete?
      data.fetch('complete')
    end

    # does this mean whether or not it is an in-play market,
    # or whether it is currently in play? Does Betfair have non
    # in play markets?
    def in_play?
      data.fetch('inplay')
    end

    def number_of_winners
      data.fetch('numberOfWinners')
    end

    def number_of_runners
      data.fetch('numberOfRunners')
    end

    def number_of_active_runners
      data.fetch('numberOfRunners')
    end

    def last_match_time
      Time.parse(data.fetch('lastMatchTime'))
    end

    # (float)
    def total_matched
      data.fetch('totalMatched')
    end

    # (float)
    # what is this?
    def total_available
      data.fetch('totalAvailable')
    end

    # what is this? Something to do with virtual matched bets?
    def cross_matching?
      data.fetch('crossMatching')
    end

    # what is this?
    def runners_voidable?
      data.fetch('runnersVoidable')
    end

    # (integer) e.g. 2383210940
    # what is this?
    def version
      data.fetch('version')
    end

    # TODO check this is correct, missed it first time round
    def runners
      data.fetch('runners').map do |runner_data|
        MarketRunner.new(runner_data)
      end
    end
  end
end