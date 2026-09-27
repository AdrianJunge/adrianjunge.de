# Run with: RAILS_ENV=test bin/rails runner scripts/profile_content.rb
# This measures normalized catalog construction, not HTTP response latency.
require "json"

iterations = Integer(ENV.fetch("CONTENT_PROFILE_RUNS", "30"))
abort "CONTENT_PROFILE_RUNS must be between 1 and 1000" unless (1..1000).cover?(iterations)

ContentCatalog.clear
ContentSnapshot.clear
measure = lambda do
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  count = ContentIndex.new.all_items.length
  [ (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000, count ]
end
cold_ms, item_count = measure.call
samples = Array.new(iterations) { measure.call.first }
puts JSON.pretty_generate(
  ruby: RUBY_VERSION,
  environment: Rails.env,
  items: item_count,
  samples: iterations,
  cold_ms: cold_ms.round(3),
  warm_mean_ms: (samples.sum / samples.length).round(3),
  warm_min_ms: samples.min.round(3),
  warm_max_ms: samples.max.round(3)
)
