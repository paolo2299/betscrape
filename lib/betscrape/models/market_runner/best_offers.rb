module Models
  class BestOffers
    attr_reader :data, :virtualised

    def initialize(data, virtualised)
      @data = data
      @virtualised = virtualised
    end

    def virtualised?
      virtualised
    end

    def available_to_back
      data.fetch('availableToBack').map do |best_offer_data|
        BestOffer.new(best_offer_data, virtualised)
      end
    end

    def available_to_lay
      data.fetch('availableToLay').map do |best_offer_data|
        BestOffer.new(best_offer_data, virtualised)
      end
    end

    # always an empty array at the moment?
    # perhaps this is because using delayed API key?
    # or need to include OrderProjection?
    def traded_volume
      data.fetch('tradedVolume')
    end
  end
end
