require "test_helper"
require_relative "../../scripts/post_deploy_check"

class PostDeployCheckTest < ActiveSupport::TestCase
  setup do
    @calls = []
    @routes = {}
    @css = "/assets/style-#{'a' * 8}.css"
    @js = "/assets/application-#{'b' * 8}.js"
    @zip = "/ctf/resources/#{'c' * 64}"
    @pdf = "/ctf/resources/#{'d' * 64}"
    PostDeployCheck::PAGES.each do |path|
      @routes[path] = response(200, { "content-type" => "text/html" }, <<~HTML)
        <link rel="canonical" href="https://adrianjunge.de#{path}">
        <link rel="stylesheet" href="#{@css}"><link rel="modulepreload" href="#{@js}">
        <main><h1>Published content</h1><a class="download-btn" href="#{@zip}">ZIP</a><a class="open-pdf-btn" href="#{@pdf}">PDF</a></main>
      HTML
    end
    PostDeployCheck::DATA.each do |path|
      @routes[path] = response(200, { "content-type" => path.end_with?(".json") ? "application/json" : "application/xml", "etag" => '"fixture"' }, "fixture")
    end
    [ @css, @js ].each { |path| @routes[path] = response(200, { "cache-control" => "public, max-age=31536000, immutable", "content-encoding" => "gzip", "vary" => "Accept-Encoding" }) }
    @routes[@zip] = response(200, { "content-type" => "application/zip", "content-disposition" => 'attachment; filename="file.zip"' }, "PKfixture")
    @routes[@pdf] = response(200, { "content-type" => "application/pdf", "content-disposition" => 'inline; filename="file.pdf"' }, "%PDF-fixture")
    @wkd_key = "/.well-known/openpgpkey/hu/53a3k6s45xb3w5niiaq14mjsf1xeuoz3?l=stdin"
    @advanced_wkd_key = @wkd_key.sub("openpgpkey/", "openpgpkey/adrianjunge.de/")
    {
      "/.well-known/openpgpkey/policy" => "text/plain",
      @wkd_key => "application/octet-stream",
      "/.well-known/openpgpkey/adrianjunge.de/policy" => "text/plain",
      @advanced_wkd_key => "application/octet-stream",
      SiteProfile.pgp_path => "application/pgp-keys"
    }.each do |path, type|
      body = File.binread(Rails.root.join("public", path.split("?", 2).first.delete_prefix("/")))
      @routes[path] = response(200, {
        "content-type" => type, "access-control-allow-origin" => "*", "x-content-type-options" => "nosniff",
        "cache-control" => "public, max-age=0, must-revalidate", "content-length" => body.bytesize.to_s
      }, body)
    end
    %w[/.well-known/openpgpkey /.well-known/openpgpkey/adrianjunge.de].each do |base|
      [ base, "#{base}/", "#{base}/hu/", "#{base}/hu/#{'0' * 32}?l=unpublished" ].each do |path|
        @routes[path] = response(404)
      end
    end
    @routes["/robots.txt"] = response(200, { "cache-control" => "public, max-age=0, must-revalidate" }, "User-agent: *")
    @routes["/this-page-does-not-exist"] = response(404)
  end

  test "checks representative routes canonical URLs downloads validators and gzip without external requests" do
    report = checker.run
    assert_equal 44, report[:checks].length
    assert @calls.all? { |uri, _method, _headers| uri.host == "127.0.0.1" }
    assert_equal 2, report[:checks].count { |check| check[:sha256] }
    assert @calls.any? { |uri, method, headers| uri.path == @css && method == "HEAD" && headers["Accept-Encoding"] == "gzip" }
    assert_equal 3, report[:checks].count { |check| check[:status] == 304 }
  end

  test "requires explicit safe origins and the configured canonical public host" do
    [ "http://adrianjunge.de", "https://other.example", "https://user@adrianjunge.de", "https://adrianjunge.de/path", "https://adrianjunge.de?q=1", "http://[" ].each do |url|
      assert_raises(PostDeployCheck::Failure, url) { PostDeployCheck.new(base_url: url) }
    end
  end

  test "public WKD checks use the advanced hostname only for the advanced layout" do
    checker(base_url: SiteProfile.origin).send(:check_openpgp)
    assert_equal 26, @calls.length
    @calls.each do |uri, _method, _headers|
      advanced = uri.path.start_with?("/.well-known/openpgpkey/adrianjunge.de")
      assert_equal advanced ? "openpgpkey.adrianjunge.de" : "adrianjunge.de", uri.host
      assert_equal "https", uri.scheme
    end
  end

  test "advanced WKD refuses redirects to the website or an external hostname" do
    %w[https://adrianjunge.de https://external.example].each do |origin|
      @calls.clear
      @routes[@advanced_wkd_key] = response(302, { "location" => "#{origin}#{@advanced_wkd_key}" })
      assert_raises(PostDeployCheck::Failure) { checker(base_url: SiteProfile.origin).send(:check_openpgp) }
      assert @calls.none? { |uri, _method, _headers| uri.request_uri == @advanced_wkd_key && uri.host != "openpgpkey.adrianjunge.de" }
    end
  end

  test "fails wrong canonical host missing gzip and incorrect cache policy" do
    @routes["/"].body.sub!("https://adrianjunge.de/", "https://wrong.example/")
    assert_raises(PostDeployCheck::Failure) { checker.run }
    @routes["/"].body.sub!("https://wrong.example/", "https://adrianjunge.de/")
    @routes[@css].headers.delete("content-encoding")
    assert_raises(PostDeployCheck::Failure) { checker.run }
    @routes[@css].headers["content-encoding"] = "gzip"
    @routes[@css].headers["cache-control"] = "no-cache"
    assert_raises(PostDeployCheck::Failure) { checker.run }
  end

  test "follows bounded same-origin redirects and refuses external redirects before requesting them" do
    @routes["/first"] = response(302, { "location" => "/second" })
    @routes["/second"] = response(200, {}, "final")
    assert_equal "final", checker.send(:request, "/first").body
    @routes["/first"] = response(302, { "location" => "https://external.example/" })
    assert_raises(PostDeployCheck::Failure) { checker.send(:request, "/first") }
    assert @calls.none? { |uri, _method, _headers| uri.host == "external.example" }
    @routes["/first"] = response(302, { "location" => "/first" })
    assert_raises(PostDeployCheck::Failure) { checker.send(:request, "/first") }
    7.times { |index| @routes["/hop#{index}"] = response(302, { "location" => "/hop#{index + 1}" }) }
    assert_raises(PostDeployCheck::Failure) { checker.send(:request, "/hop0") }
  end

  test "refuses a stale WKD export missing CORS or a directory listing" do
    [ @wkd_key, @advanced_wkd_key ].each do |path|
      original = @routes[path].body
      @routes[path].body = "stale certificate"
      assert_raises(PostDeployCheck::Failure) { checker.send(:check_openpgp) }
      @routes[path].body = original
      @routes[path].headers.delete("access-control-allow-origin")
      assert_raises(PostDeployCheck::Failure) { checker.send(:check_openpgp) }
      @routes[path].headers["access-control-allow-origin"] = "*"
    end
    @routes["/.well-known/openpgpkey/hu/"] = response(200, {}, "directory listing")
    assert_raises(PostDeployCheck::Failure) { checker.send(:check_openpgp) }
  end

  test "fails broken routes truncated downloads and unexpected download bodies" do
    @routes["/about"] = response(500)
    assert_raises(PostDeployCheck::Failure) { checker.run }
    @routes.delete("/about")
    @routes[@zip].headers["content-length"] = "500"
    assert_raises(PostDeployCheck::Failure) { checker.send(:check_downloads, { zip: @zip, pdf: @pdf }) }
    @routes[@zip].headers.delete("content-length")
    @routes[@zip].body = "An HTML error masquerading as an archive"
    assert_raises(PostDeployCheck::Failure) { checker.send(:check_downloads, { zip: @zip, pdf: @pdf }) }
  end

  private

  def response(status, headers = {}, body = "")
    PostDeployCheck::Response.new(status: status, headers: headers, body: body)
  end

  def checker(base_url: "http://127.0.0.1:1234")
    transport = lambda do |uri, method, headers|
      @calls << [ uri, method, headers ]
      if headers["If-None-Match"] == '"fixture"'
        response(304)
      else
        result = @routes.fetch(uri.request_uri) { flunk "unexpected network request #{uri}" }
        method == "HEAD" ? response(result.status, result.headers) : result
      end
    end
    PostDeployCheck.new(base_url: base_url, transport: transport)
  end
end
