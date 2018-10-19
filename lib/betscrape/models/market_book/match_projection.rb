module Models
  class MatchProjection
    # only applicable if we asked to return orders
    NO_ROLLUP = 'NO_ROLLUP'.freeze
    ROLLED_UP_BY_PRICE = 'ROLLED_UP_BY_PRICE'.freeze
    ROLLED_UP_BY_AVG_PRICE = 'ROLLED_UP_BY_AVG_PRICE'.freeze
  end
end