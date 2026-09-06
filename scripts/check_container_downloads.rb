# Invoked inside the built container by container-check.sh through Rails runner.
# Read the smallest published example of each resource kind; never execute it.
require "digest"
require "net/http"

assets = ContentRepository.new.ctf_assets
checks = %i[challenge writeup].map do |kind|
  asset = assets.select { |entry| entry[:kind] == kind }.min_by { |entry| entry[:size] }
  abort "The production image contains no published #{kind} resource" unless asset

  response = Net::HTTP.start("127.0.0.1", 80, nil, open_timeout: 3, read_timeout: 15) do |http|
    http.get("/ctf/resources/#{asset[:id]}")
  end
  abort "#{kind}: download returned #{response.code}" unless response.code == "200"
  abort "#{kind}: incorrect content type" unless response["content-type"].to_s.split(";").first == asset[:content_type]
  abort "#{kind}: incorrect disposition" unless response["content-disposition"].to_s.start_with?("#{asset[:disposition]};")
  abort "#{kind}: incorrect byte length" unless response.body.bytesize == asset[:size] && asset[:size].positive?
  expected_hash = Digest::SHA256.file(asset[:path]).hexdigest
  abort "#{kind}: response differs from the published source" unless Digest::SHA256.hexdigest(response.body) == expected_hash

  { kind: kind, filename: asset[:basename], bytes: asset[:size], sha256: expected_hash }
end

puts JSON.pretty_generate(checks)
