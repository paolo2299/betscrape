require "google/cloud/storage"

storage = Google::Cloud::Storage.new(project_id: "betscrape", credentials: "keys/betscrape-58fd4befed68.json")
bucket = storage.bucket "betscrape-api-responses"

Dir["*.log.*"].each do |file|
  bucket.create_file file, file
end
