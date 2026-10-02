#!/usr/bin/env ruby
require "bundler/setup"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "nokogiri"
require "optparse"
require "time"
require "uri"
require_relative "../app/models/site_profile"
require_relative "support/openpgp_checks"

# Read-only release verification. URLs are bounded to the supplied origin and
# the configured WKD hostname; pages cannot cause requests to other origins.
class PostDeployCheck
  class Failure < StandardError; end
  Response = Struct.new(:status, :headers, :body, keyword_init: true)
  PAGES = %w[/ /about /timeline /blog/java-strings /blog/climbing-stairs /ctf/cscg/KDF%20dream].freeze
  DATA = %w[/search/index.json /feed.xml /sitemap.xml].freeze
  REDIRECTS = [ 301, 302, 303, 307, 308 ].freeze
  MAX_BYTES = 12 * 1024 * 1024

  def initialize(base_url:, canonical_origin: SiteProfile.origin, transport: nil)
    @base = origin_uri(base_url)
    @canonical = origin_uri(canonical_origin)
    loopback = %w[127.0.0.1 localhost ::1 [::1]].include?(@base.host)
    raise Failure, "Public checks require HTTPS" unless @base.scheme == "https" || loopback
    raise Failure, "Base URL must use the expected canonical origin" unless loopback || @base == @canonical

    @advanced_wkd = loopback ? @base : origin_uri("https://openpgpkey.#{SiteProfile.email.split('@', 2).last.downcase}")
    @transport = transport || method(:http_request)
    @checks = []
  end

  def run
    assets = []
    downloads = {}
    PAGES.each do |path|
      response = request(path)
      require_header(response, "content-type", /text\/html/, path)
      document = Nokogiri::HTML(response.body)
      canonical = document.css('link[rel="canonical"]').map { |node| node["href"] }
      expected = URI.join(@canonical.to_s, path).to_s
      raise Failure, "#{path}: incorrect canonical URL #{canonical.inspect}" unless canonical == [ expected ]
      raise Failure, "#{path}: missing main content" unless document.at_css("main")

      assets.concat(document.css('link[rel="stylesheet"][href], link[rel="modulepreload"][href], script[src]').filter_map { |node| node["href"] || node["src"] })
      { zip: ".download-btn[href]", pdf: ".open-pdf-btn[href]" }.each do |kind, selector|
        downloads[kind] ||= document.at_css(selector)&.[]("href")
      end
    end
    DATA.each do |path|
      response = request(path)
      expected_type = path.end_with?(".json") ? /json/ : /xml/
      require_header(response, "content-type", expected_type, path)
      raise Failure, "#{path}: missing cache validator" unless response.headers["etag"] || response.headers["last-modified"]
      if (etag = response.headers["etag"])
        request(path, headers: { "If-None-Match" => etag }, expected: 304)
      end
    end
    [ ".css", ".js" ].each do |extension|
      path = assets.find { |url| URI(url).path.end_with?(extension) }
      raise Failure, "No #{extension} asset found" unless path
      raise Failure, "Unfingerprinted release asset #{path}" unless URI(path).path.match?(/-[0-9a-f]{8,64}\.[a-z]+\z/)

      response = request(path, method: "HEAD", headers: { "Accept-Encoding" => "gzip" })
      require_header(response, "cache-control", /immutable/, path)
      require_header(response, "content-encoding", /\Agzip\z/i, path)
      require_header(response, "vary", /(?:\A|,)\s*accept-encoding\s*(?:,|\z)/i, path)
    end
    check_downloads(downloads)
    check_openpgp
    robots = request("/robots.txt")
    require_header(robots, "cache-control", /must-revalidate/, "/robots.txt")
    request("/this-page-does-not-exist", expected: 404)
    { checked_at: Time.now.utc.iso8601, base_url: @base.to_s, canonical_origin: @canonical.to_s, checks: @checks }
  end

  private

  def check_openpgp
    OpenpgpChecks.run(root: File.expand_path("..", __dir__)) do |path, method, layout|
      # WKD deliberately returns 404 for directories and unpublished keys.
      origin = layout == :advanced ? @advanced_wkd : @base
      response = request(path, method: method, expected: nil, origin: origin)
      [ response.status, response.headers, response.body ]
    end
  rescue OpenpgpChecks::Failure => error
    raise Failure, error.message
  end

  def check_downloads(downloads)
    { zip: [ /application\/zip/, "PK" ], pdf: [ /application\/pdf/, "%PDF-" ] }.each do |kind, (content_type, signature)|
      path = downloads[kind]
      raise Failure, "Missing published #{kind} download" unless path && URI(path).path.match?(%r{\A/ctf/resources/[a-f0-9]{64}\z})

      response = request(path)
      require_header(response, "content-type", content_type, path)
      require_header(response, "content-disposition", /\A(?:attachment|inline);/, path)
      raise Failure, "#{path}: invalid #{kind} file signature" unless response.body.start_with?(signature)
      if (length = response.headers["content-length"])
        raise Failure, "#{path}: incomplete download" unless length.to_i == response.body.bytesize
      end
      @checks.last[:sha256] = Digest::SHA256.hexdigest(response.body)
    end
  end

  def request(path, method: "GET", headers: {}, expected: 200, origin: @base)
    uri = URI.join(origin.to_s, path)
    seen = []
    loop do
      raise Failure, "External redirect or asset refused: #{uri}" unless same_origin?(uri, origin) && !uri.userinfo
      raise Failure, "Redirect loop at #{uri}" if seen.include?(uri.to_s)
      raise Failure, "Too many redirects for #{path}" if seen.length > 5

      seen << uri.to_s
      response = @transport.call(uri, method, { "Accept-Encoding" => "identity" }.merge(headers))
      raise Failure, "#{path}: response exceeds #{MAX_BYTES} bytes" if response.body.bytesize > MAX_BYTES
      if REDIRECTS.include?(response.status)
        location = response.headers["location"]
        raise Failure, "#{path}: redirect lacks Location" if location.to_s.empty?

        uri = URI.join(uri.to_s, location)
        next
      end
      raise Failure, "#{path}: expected HTTP #{expected}, received #{response.status}" if expected && response.status != expected

      @checks << { path: path, method: method, status: response.status, final_url: uri.to_s, bytes: response.body.bytesize }
      return response
    end
  rescue URI::InvalidURIError => error
    raise Failure, "Invalid URL: #{error.message}"
  end

  def require_header(response, name, pattern, path)
    raise Failure, "#{path}: unexpected #{name}: #{response.headers[name].inspect}" unless pattern.match?(response.headers[name].to_s)
  end

  def origin_uri(value)
    uri = URI(value.to_s)
    unless %w[http https].include?(uri.scheme) && uri.host && !uri.userinfo && !uri.query && !uri.fragment && [ "", "/" ].include?(uri.path)
      raise Failure, "Expected an HTTP(S) origin without credentials, query, or path"
    end
    uri.path = ""
    uri
  rescue URI::InvalidURIError
    raise Failure, "Invalid origin"
  end

  def same_origin?(left, right)
    [ left.scheme, left.host, left.port ] == [ right.scheme, right.host, right.port ]
  end

  def http_request(uri, method, headers)
    response = nil
    Net::HTTP.start(uri.host, uri.port, nil, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 15, write_timeout: 5) do |http|
      message = (method == "HEAD" ? Net::HTTP::Head : Net::HTTP::Get).new(uri.request_uri, headers)
      http.request(message) do |incoming|
        body = +"".b
        incoming.read_body do |chunk|
          body << chunk
          raise Failure, "#{uri.path}: response exceeds #{MAX_BYTES} bytes" if body.bytesize > MAX_BYTES
        end
        response = Response.new(status: incoming.code.to_i, headers: incoming.to_hash.transform_values(&:first), body: body)
      end
    end
    response
  end
end

if $PROGRAM_NAME == __FILE__
  options = { canonical_origin: SiteProfile.origin, output: "tmp/post-deploy-check/report.json" }
  parser = OptionParser.new do |cli|
    cli.banner = "Usage: bundle exec ruby scripts/post_deploy_check.rb --base-url ORIGIN [--canonical-origin ORIGIN] [--output FILE]"
    cli.on("--base-url URL") { |value| options[:base_url] = value }
    cli.on("--canonical-origin URL") { |value| options[:canonical_origin] = value }
    cli.on("--output FILE") { |value| options[:output] = value }
  end
  begin
    parser.parse!
    raise PostDeployCheck::Failure, parser.banner unless options[:base_url] && ARGV.empty?

    report = PostDeployCheck.new(**options.except(:output)).run
    FileUtils.mkdir_p(File.dirname(options.fetch(:output)))
    File.write(options.fetch(:output), JSON.pretty_generate(report) + "\n")
    puts "Post-deploy routes, canonical URLs, downloads, WKD, cache validators, and gzip passed. Report: #{options.fetch(:output)}"
  rescue PostDeployCheck::Failure, OptionParser::ParseError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => error
    warn error.message
    exit 1
  end
end
