require "rack/static"

# Serve WKD before Rails' general static server so extensionless keys receive
# the protocol's MIME type and CORS headers in every environment.
Rails.application.config.middleware.insert_before ActionDispatch::Static, Rack::Static,
  urls: [ "/.well-known/openpgpkey", "/pgp-vurlo.asc" ],
  root: Rails.root.join("public").to_s,
  header_rules: [
    [ :all, {
      "access-control-allow-origin" => "*",
      "cache-control" => "public, max-age=0, must-revalidate",
      "x-content-type-options" => "nosniff"
    } ],
    [ %r{\A/\.well-known/openpgpkey/hu/[a-z0-9]{32}\z}, { "content-type" => "application/octet-stream" } ],
    [ %r{\A/\.well-known/openpgpkey/policy\z}, { "content-type" => "text/plain; charset=utf-8" } ],
    [ %r{\A/pgp-vurlo\.asc\z}, { "content-type" => "application/pgp-keys" } ]
  ]
