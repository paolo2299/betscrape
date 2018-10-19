module Models
  class MarketSort
    RANK = 'RANK'.freeze # black box sort based on lots of criteria
    MINIMUM_TRADED = 'MINIMUM_TRADED'.freeze
    MAXIMUM_TRADED = 'MAXIMUM_TRADED'.freeze
    MINIMUM_AVAILABLE = 'MINIMUM_AVAILABLE'.freeze
    MAXIMUM_AVAILABLE = 'MAXIMUM_AVAILABLE'.freeze
    FIRST_TO_START = 'FIRST_TO_START'.freeze
    LAST_TO_START = 'LAST_TO_START'.freeze
  end
end