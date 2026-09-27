require "uri"
require "strscan"

# Shared by local request tests and the disposable production smoke check.
# Never fetches an external URL: callers provide the local request adapter.
module SiteIntegrity
  class Failure < StandardError; end

  # Follow the srcset URL-token boundary rules, including commas inside data
  # URLs. Descriptors are deliberately ignored; this collects every candidate.
  def self.srcset_urls(value)
    scanner = StringScanner.new(value.to_s)
    urls = []
    until scanner.eos?
      scanner.skip(/[\s,]+/)
      break if scanner.eos?

      url = scanner.scan(/\S+/)
      if url.end_with?(",")
        urls << url.sub(/,+\z/, "")
        next
      end
      urls << url
      depth = 0
      until scanner.eos?
        character = scanner.getch
        depth += 1 if character == "("
        depth -= 1 if character == ")" && depth.positive?
        break if character == "," && depth.zero?
      end
    end
    urls
  end

  def self.document_urls(document)
    document.css("[href], [src], [srcset]").flat_map do |element|
      [ element["href"], element["src"], *srcset_urls(element["srcset"]) ].compact
    end.uniq
  end

  class LocalLinks
    REDIRECTS = [ 301, 302, 303, 307, 308 ].freeze
    Result = Struct.new(:uri, :body, :status, keyword_init: true)

    def initialize(origins:, max_redirects: 5, &request)
      @origins = origins.map { |value| origin(URI(value)) }
      @base = URI(origins.first)
      @max_redirects = max_redirects
      @request = request
      @responses = {}
    end

    def target(href, from: "/")
      base = URI.join(@base.to_s, from.to_s)
      uri = URI.join(base.to_s, href.to_s)
      return unless %w[http https].include?(uri.scheme) && @origins.include?(origin(uri)) && !uri.userinfo

      uri
    rescue URI::InvalidURIError
      nil
    end

    def resolve(uri)
      seen = []
      loop do
        raise Failure, "Redirect loop at #{uri}" if seen.include?(uri.to_s)

        seen << uri.to_s
        status, headers, body = @responses[uri.request_uri] ||= @request.call(uri.request_uri)
        unless REDIRECTS.include?(status)
          raise Failure, "#{uri}: final HTTP status #{status}" unless status == 200

          return Result.new(uri: uri, body: body, status: status)
        end
        raise Failure, "Too many redirects for #{seen.first}" if seen.length > @max_redirects

        location = headers["location"] || headers["Location"]
        next_uri = target(location, from: uri) if location && !location.empty?
        raise Failure, "#{uri}: missing, invalid, or external redirect #{location.inspect}" unless next_uri

        next_uri.fragment = uri.fragment unless location.include?("#")
        uri = next_uri
      end
    end

    def fragment_exists?(result, document:)
      fragment = result.uri.fragment
      return true if fragment.nil? || fragment.empty?

      decoded = URI::DEFAULT_PARSER.unescape(fragment)
      document.css("[id], a[name]").any? { |element| element["id"] == decoded || element["name"] == decoded }
    end

    private

    def origin(uri)
      [ uri.scheme, uri.host&.downcase, uri.port ]
    end
  end
end
