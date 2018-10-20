require_relative '../../lib/betscrape'

class EnglishPremierLeague
  def self.markets_per_event_upper_estimate
    50
  end

  def self.name
    "English Premier League"
  end

  def self.market_filter
    Models::MarketFilter::BRITISH_FOOTBALL
  end
end

scraper = CompetitionScraper.new(EnglishPremierLeague)
scraper.scrape!
