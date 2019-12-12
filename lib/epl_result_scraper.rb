require 'httparty'
require 'json'

class EPLResultScraper
  def self.download_all_matches(fixture_type)
    all_fixtures_html_path = "lib/epl_result_scraper/html/all_fixtures_#{type}.html"
    all_fixtures_html = File.open(all_fixtures_html_path, :encoding => 'utf-8').read
    match_ids = all_fixtures_html.scan(/data-matchid="(\d+)"/).flatten.map(&:to_i)
    match_ids.each_with_index do |match_id, idx|
      puts "match #{idx + 1} of #{match_ids.count}"
      download_match(match_id, fixture_type)
    end
  end

  def self.download_match(match_id, fixture_type)
    html = HTTParty.get("https://www.premierleague.com/match/#{match_id}")
    File.open("lib/epl_result_scraper/html/all_fixtures_#{fixture_type}/#{match_id}.html", "w") do |file|
      file.write(html)
    end
  end

  def self.parse_all_matches(fixture_type)
    all_fixtures_folder_path = "lib/epl_result_scraper/html/all_fixtures_#{fixture_type}"
    files = Dir.glob("#{all_fixtures_folder_path}/*.html")
    files.each do |file|
      html = File.read(file, :encoding => 'utf-8')
      json = parse_match(html)
    end
  end

  def self.parse_match(match_html)
    json_data = match_html.match(/data-fixture='({[^']+})'/)[1]
    JSON.parse(json_data)
  end

  def self.extract_data_from_match_json(match_json)
    events = match_json.fetch("events").map do |event_json|
      extract_data_from_event_json(event_json)
    end
  end

  def self.extract_data_from_event_json(event_json)
    flatten_hash(event_json)
  end

  def self.flatten_hash(hash)
    hash.each_with_object({}) do |(k, v), h|
      if v.is_a? Hash
        flatten_hash(v).map do |h_k, h_v|
          h["#{k}_#{h_k}".to_sym] = h_v
        end
      else 
        h[k] = v
      end
     end
  end
end

fixture_type = '2018_2019'
#EPLResultScraper.download_all_matches(fixture_type)
EPLResultScraper.parse_all_matches(fixture_type)