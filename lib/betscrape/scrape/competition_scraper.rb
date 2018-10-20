class CompetitionScraper
  MARKETS_TO_REQUEST = 1000
  MARKET_BOOKS_TO_REQUEST = 40
  REFRESH_TIME = 60

  attr_reader :target

  def initialize(target)
    @target = target
  end
    
  def scrape!
    # TODO accept sensible signal
    while true
      start = Time.now
      market_books
      sleep [0, REFRESH_TIME - (Time.now - start)].max
    end
  end

  def competition
    @competition ||= Models::Competition.find(target.name, target.market_filter)
  end

  def events
    @events ||= Models::Event.all_for_competition(competition)
  end

  def markets
    @markets ||= begin
      markets = []
      events.each_slice(markets_request_slice_size(target.markets_per_event_upper_estimate)) do |events_slice|
        slice_markets = Models::Market.top_for_events(
          events_slice,
          MARKETS_TO_REQUEST,
          [
            Models::MarketProjection::EVENT,
            Models::MarketProjection::RUNNER_DESCRIPTION
          ]
        )
        if slice_markets.size >= MARKETS_TO_REQUEST
          puts "Warning: hit upper bound of markets to request"
        end
        markets += slice_markets
      end
      markets
    end
  end

  def market_books
    market_books = []
    markets.each_slice(MARKET_BOOKS_TO_REQUEST) do |market_slice|
      market_books += Models::MarketBook.for_markets(market_slice)
    end
    market_books
  end

  def markets_request_slice_size(events_per_market)
    MARKETS_TO_REQUEST / events_per_market
  end
end