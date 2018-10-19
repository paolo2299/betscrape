module Models
  class PriceProjection
    attr_reader :options

    def initialize(options = {})
      @options = options
    end

    # not supported yet
    def rollover_stakes?
      options.fetch(:rollover_stakes, false)
    end

    def price_data
      options.fetch(:price_data, DEFAULT_PRICE_DATA)
    end

    def virtualise?
      options.fetch(:virtualise, true)
    end

    def best_offer_overrides
      return nil unless price_data.include?(PriceData::EX_BEST_OFFERS)
      return options.fetch(:best_offer_overrides, nil)
    end

    def to_hash
      h = {
        priceData: price_data,
        virtualise: false
      }
      h[:exBestOfferOverrides] = best_offer_overrides.to_hash if best_offer_overrides
      h[:rolloverStakes] = rollover_stakes? if false # not supported yet
      h
    end

    class PriceData
      SP_AVAILABLE = 'SP_AVAILABLE'.freeze # Amount available for the BSP auction.
      SP_TRADED = 'SP_TRADED'.freeze # Amount traded in the BSP auction
      EX_BEST_OFFERS = 'EX_BEST_OFFERS'.freeze # Only the best prices available for each runner, to requested price depth.
      EX_ALL_OFFERS = 'EX_ALL_OFFERS'.freeze 
      EX_TRADED = 'EX_TRADED'.freeze # Amount traded on the exchange.
    end

    DEFAULT_PRICE_DATA = [ PriceData::EX_BEST_OFFERS ].freeze

    class BestOfferOverrides
      attr_reader :best_prices_depth, :rollup_model, :rollup_limit
  
      def initialize(options)
        # int (default 3)
        @best_prices_depth = options.fetch(:best_prices_depth, nil)
        # RollupModel (default STAKE)
        @rollup_model = options.fetch(:rollup_model, nil)
        # int
        @rollup_limit = options.fetch(:rollup_limit, nil)
      end
  
      def to_hash
        h = {}
        h[:best_prices_depth] = best_prices_depth if best_prices_depth
        h[:rollup_model] = rollup_model if rollup_model
        h[:rollup_limit] = rollup_limit if rollup_limit
        h
      end
  
      class RollupModel
        STAKE = 'STAKE'.freeze
        PAYOUT = 'PAYOUT'.freeze
        MANAGED_LIABILITY = 'MANAGED_LIABILITY'.freeze # not supported yet
        NONE = 'NONE'.freeze
      end
    end
  end
end