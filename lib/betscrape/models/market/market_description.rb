module Models
  class MarketDescription
    attr_reader :data

    def initialize(data)
      @data = data
    end

    def persistence_enabled
      data.fetch('persistenceEnabled')
    end

    def bsp_market?
      data.fetch('bspMarket')
    end

    def market_time
      Time.parse(data.fetch('marketTime'))
    end

    def suspend_time
      Time.parse(data.fetch('suspendTime'))
    end

    def betting_type
      data.fetch('bettingType')
    end

    def turn_in_play_enabled?
      data.fetch('turnInPlayEnabled')
    end

    def market_type
      data.fetch('marketType')
    end

    def regulator
      data.fetch('regulator')
    end

    def market_base_rate
      data.fetch('marketBaseRate')
    end

    def discount_allowed?
      data.fetch('discountAllowed')
    end

    def wallet
      data.fetch('wallet')
    end

    def rules
      data.fetch('rules')
    end

    def rules_has_date?
      data.fetch('rulesHasDate')
    end

    def price_ladder_description
      data.fetch('priceLadderDescription')
    end
  end
end