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

API::Logger.initialize('english-premier-league', "#{rand(36**4).to_s(36)}")

scraper = CompetitionScraper.new(EnglishPremierLeague)
scraper.scrape!
