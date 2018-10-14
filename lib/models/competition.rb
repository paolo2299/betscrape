module Models
  class Competition
    def self.find(name, market_filter)
      find_all(market_filter)
    end

    def self.find_all(market_filter)
      market_datas = API::Client.list_competitions(market_filter.to_hash)
      market_datas.map {|data| new(data)}
    end

    def initialize(data)
      @name = name
      @event_type_id = event_type_id
      @country_code = country_code
    end

    def self.english_premier_league
      @english_premier_league ||= find("English Premier League", MarketFilter::BRITISH_FOOTBALL)
    end

    private

    def id
      @id ||= begin
        API::Client.list_competitions({
          eventTypeIds:[@event_type_id],
          marketCountries:[@country_code],
        })
      end
    end
  end
end