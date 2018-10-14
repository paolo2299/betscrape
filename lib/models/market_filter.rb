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
    end

    def add_countries(countries)
      countries.each do |c|
        country(c)
      end
    end

    def add_event_type(event_type)
      @filter[:eventTypeIds] << event_type.id
    end

    def add_event_types(event_types)
      event_types.each do |et|
        add_event_type(et)
      end
    end

    def to_hash
      @filter
    end

    # Pre-defined filters for convenience
    BRITISH_FOOTBALL = MarketFilter.new.add_country(Country::GB).add_event_type(EventType::FOOTBALL)
  end
end
