require "digest"
require "pathname"
require "uri"

# The same HTTP contract runs against a production snapshot, the built
# container, and the deployed origin. Callers supply the bounded transport.
module OpenpgpChecks
  class Failure < StandardError; end

  def self.run(root:)
    public_root = Pathname(root).join("public")
    base = "/.well-known/openpgpkey"
    keys = public_root.join(base.delete_prefix("/"), "hu").children
    raise Failure, "Expected exactly one published WKD key" unless keys.one? && keys.first.file?

    key_path = "#{base}/hu/#{keys.first.basename}"
    paths = { "#{base}/policy" => "text/plain", key_path => "application/octet-stream", SiteProfile.pgp_path => "application/pgp-keys" }
    checks = paths.map do |path, type|
      expected = public_root.join(path.delete_prefix("/")).binread
      request_path = path == key_path ? "#{path}?#{URI.encode_www_form(l: SiteProfile.email.split('@', 2).first)}" : path
      %w[GET HEAD].each do |method|
        status, headers, body = yield(request_path, method)
        raise Failure, "#{method} #{path}: expected HTTP 200, received #{status}" unless status == 200
        raise Failure, "#{path}: incorrect MIME type" unless headers["content-type"].to_s.split(";").first == type
        raise Failure, "#{path}: missing public CORS header" unless headers["access-control-allow-origin"] == "*"
        raise Failure, "#{path}: missing cache revalidation" unless headers["cache-control"].to_s.include?("must-revalidate") && !headers["cache-control"].include?("immutable")
        raise Failure, "#{path}: missing nosniff header" unless headers["x-content-type-options"] == "nosniff"
        raise Failure, "#{method} #{path}: incorrect response bytes" unless body.to_s.b == (method == "GET" ? expected : "".b)
        raise Failure, "#{method} #{path}: incorrect content length" unless headers["content-length"].to_i == expected.bytesize
      end
      { path: path, bytes: expected.bytesize, sha256: Digest::SHA256.hexdigest(expected) }
    end
    [ base, "#{base}/", "#{base}/hu/", "#{base}/hu/#{'0' * 32}?l=unpublished" ].each do |path|
      %w[GET HEAD].each do |method|
        status, = yield(path, method)
        raise Failure, "#{method} #{path}: expected HTTP 404, received #{status}" unless status == 404
      end
    end
    checks
  end
end
