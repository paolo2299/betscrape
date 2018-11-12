class CompetitionScraper
  MARKETS_TO_REQUEST = 1000
  MARKET_BOOKS_TO_REQUEST = 40
  REFRESH_TIME = 60

  # TODO replace this with a proper caching layer at the api level
  CACHE_TIMES = {
    competition: 60 * 60,
    events: 60 * 20,
    markets: 60 * 20,
  }

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
    @competition = nil if invalidate_cache?(:competition, @competition_last_fetch)
    @competition ||= begin
      @competition_last_fetch = Time.now
      Models::Competition.find(target.name, target.market_filter)
    end
  end

  def events
    @events = nil if invalidate_cache?(:events, @events_last_fetch)
    @events ||= begin
      @events_last_fetch = Time.now
      Models::Event.all_for_competition(competition)
    end
  end

  def markets
    @markets = nil if invalidate_cache?(:markets, @markets_last_fetch)
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
      @markets_last_fetch = Time.now
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

  # TODO replace this with a proper caching layer at the api level
  def invalidate_cache?(resource, last_fetch_time)
    return false unless last_fetch_time
    Time.now - last_fetch_time >= CACHE_TIMES.fetch(resource)
  end
end
