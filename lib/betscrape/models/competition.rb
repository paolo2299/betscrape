module Models
  class Competition
    class CompetitionNotFoundError < StandardError; end

    # market count and region are returned when calling list_competitions in the API,
    # but not when it is part of a projection from another call
    def self.find(name, market_filter)
      match = find_all(market_filter).detect{|c| c.name == name}
      raise CompetitionNotFoundError "name: #{name}" unless match
      return match
    end

    def self.find_all(market_filter)
      market_datas = API::Client.list_competitions(market_filter.to_hash)
      market_datas.map {|data| new(data.fetch('competition'), data.fetch('marketCount'), data.fetch('competitionRegion'))}
    end

    attr_reader :data, :competition_region
    # TODO: is this just the count of markets for betting on the competition itself
    # (.i.e. overall winner, overall loser etc.) or the count of markets available
    # for individual games in that competition? 
    attr_reader :market_count

    def initialize(data, market_count = nil, competition_region = nil)
      @data = data
      @market_count = market_count
      @competition_region = competition_region
    end

    def id
      data.fetch('id')
    end

    def name
      data.fetch('name')
    end
  end
end