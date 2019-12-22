require_relative './epl_result_scraper/epl_match'
require 'httparty'
require 'json'
require 'pp'

class EPLMatchDownloader
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
end



class EPLMatchParser
  def self.extract_events_from_all_matches(fixture_type, outfile_path)
    events = []
    all_fixtures_folder_path = "lib/epl_result_scraper/html/all_fixtures_#{fixture_type}"
    files = Dir.glob("#{all_fixtures_folder_path}/*.html")
    File.open(outfile_path, 'w') do |outfile|
      files.each do |file|
        html = File.read(file, :encoding => 'utf-8')
        json = parse_match(html)
        match = EPLMatch.new(json)
        puts match.to_s
        match.events.each do |event_hash|
          outfile.puts(JSON.generate(event_hash))
        end
      end
    end
  end

  def self.parse_match(match_html)
    json_data = match_html.match(/data-fixture='({[^']+})'/)[1]
    JSON.parse(json_data)
  end
end

FIXTURE_TYPE = '2018_2019'
OUTFILE = "./events_epl_#{FIXTURE_TYPE}.json"
#EPLMatchDownloader.download_all_matches(FIXTURE_TYPE)
EPLMatchParser.extract_events_from_all_matches(FIXTURE_TYPE, OUTFILE)