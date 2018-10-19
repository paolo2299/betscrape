module Models
  class EventType
    attr_reader :data

    def initialize(data)
      @data = data
    end

    def id
      @data.fetch('id')
    end

    def name
      @data.fetch('name')
    end

    # Pretty sure these never change, so safe to hard-code them
    FOOTBALL = new({'id' => '1', 'name' => 'Soccer'})
  end
end