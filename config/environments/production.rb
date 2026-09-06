require "active_support/core_ext/integer/time"
require "rack/static"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true

  config.consider_all_requests_local = false

  config.action_controller.perform_caching = true

  # Stable public URLs (PGP key, robots, PDFs) must be revalidated. The separate
  # fingerprinted-assets middleware configured below supplies immutable caching.
  config.public_file_server.headers = { "cache-control" => "public, max-age=0, must-revalidate" }
  config.middleware.insert_before ActionDispatch::Static, Rack::Static,
    urls: [ "/assets" ], root: Rails.root.join("public").to_s, cascade: true, gzip: true,
    header_rules: [
      [ :all, { "cache-control" => "public, max-age=0, must-revalidate", "vary" => "Accept-Encoding" } ],
      [ /-[0-9a-f]{8,64}\.[^\/]+\z/, { "cache-control" => "public, max-age=#{1.year.to_i}, immutable" } ]
    ]

  config.assume_ssl = true
  config.force_ssl = true

  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  config.silence_healthcheck_path = "/up"

  config.active_support.report_deprecations = false

  config.i18n.fallbacks = true

  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]

  Rails.application.routes.default_url_options[:host] = "adrianjunge.de"
  Rails.application.routes.default_url_options[:protocol] = "https"
end
