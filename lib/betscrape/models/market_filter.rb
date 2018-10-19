module Models
  class MarketFilter
    def initialize(filter = {})
      @filter = Hash.new do |h, k|
        h[k] = []
      end
      @filter.merge!(filter)
    end

    def add_country(country)
      @filter[:marketCountries] << country.code
      self
    end

    def add_event_type(event_type)
      @filter[:eventTypeIds] << event_type.id
      self
    end

    def add_competition(competition)
      @filter[:competitionIds] << competition.id
      self
    end

    def add_event(event)
      @filter[:eventIds] << event.id
      self
    end

    def add_events(events)
      events.each {|event| add_event(event)}
      self
    end

    def to_hash
      @filter
    end

    # Pre-defined filters for convenience
    BRITISH_FOOTBALL = MarketFilter.new.add_country(Country::GB).add_event_type(EventType::FOOTBALL)
  end
end
