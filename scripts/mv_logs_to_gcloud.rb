Dir["*logs/.log.*"].each do |file|
  bucket.create_file file, file
end
