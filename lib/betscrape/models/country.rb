module Models
  class Country
    def initialize(code)
      @code = code
    end

    def code
      @code
    end

    GB = new("GB")
  end
end