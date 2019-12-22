class EPLMatch
  attr_reader :json
  
  def initialize(match_json)
    @json = match_json
  end
  
  def to_s
    "#{home_team} vs #{away_team} (#{result_str}) #{kickoff_str}"
  end

  def metadata
    @metadata ||= begin
      m = {}
      m = m.merge(team_metadata)
      m = m.merge(kickoff_metadata)
      m["outcome"] = json.fetch("outcome")
      m = m.merge(half_time_score)
      m
    end
  end

  def team_metadata
    teams = json.fetch("teams")
    teams = teams.zip(["home", "away"]).map do |team_data, home_or_away|
      EPLMatch.flatten_hash(team_data).reduce({}) do |memo, k_v|
        k, v = k_v
        memo["teams_#{home_or_away}_#{k}"] = v
        memo
      end
    end
    teams[0].merge(teams[1])
  end

  def kickoff_metadata
    EPLMatch.flatten_hash({"kickoff" => json.fetch("kickoff")})
  end

  def half_time_score
    EPLMatch.flatten_hash({"halfTime" => json.fetch("halfTimeScore")})
  end

  def home_team
    metadata.fetch("teams_home_team_name")
  end

  def away_team
    metadata.fetch("teams_away_team_name")
  end

  def home_score
    metadata.fetch("teams_home_score")
  end

  def away_score
    metadata.fetch("teams_away_score")
  end

  def result_str
    "#{home_score} - #{away_score}"
  end

  def kickoff_str
    metadata.fetch("kickoff_label")
  end

  def events
    events = json.fetch("events").map do |event_json|
      event_data = EPLMatch.flatten_hash({"event" => event_json})
      event_data.merge(metadata)
    end
  end

  def self.flatten_hash(hash)
    hash.each_with_object({}) do |(k, v), h|
      if v.is_a? Hash
        flatten_hash(v).map do |h_k, h_v|
          h["#{k}_#{h_k}"] = h_v
        end
      elsif v.is_a? Array
        h[k] = v.map do |v_x|
          if v_x.is_a? Hash
            flatten_hash(v_x)
          else
            v_x
          end
        end
      else 
        h[k] = v
      end
      end
  end
end