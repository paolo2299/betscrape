module Models
  class BestOffer
    attr_reader :data

    def initialize(data)
      @data = data
    end
    
    def price
      data.fetch('price')
    end

    def size
      data.fetch('size')
    end
  end
end