require "test_helper"
require_relative "../../scripts/support/site_integrity"

class SiteIntegrityTest < ActiveSupport::TestCase
  test "collects href src and every width or density candidate including picture sources" do
    document = Nokogiri::HTML(<<~HTML)
      <link href="/assets/site.css">
      <picture><source srcset="/assets/small.avif 400w, /assets/large.avif 1200w">
      <img src="/assets/fallback.png" srcset="/assets/one.png 1x, /assets/two.png 2x"></picture>
      <a href="/assets/download.png" src="/assets/also.png">both</a>
    HTML
    assert_equal %w[/assets/site.css /assets/small.avif /assets/large.avif /assets/fallback.png /assets/one.png /assets/two.png /assets/download.png /assets/also.png], SiteIntegrity.document_urls(document)
    assert_equal [ "data:image/svg+xml;base64,AAAA", "/assets/next.png" ], SiteIntegrity.srcset_urls("data:image/svg+xml;base64,AAAA 1x, /assets/next.png 2x")
    assert_equal %w[/assets/one.png /assets/two.png], SiteIntegrity.srcset_urls(" /assets/one.png, /assets/two.png 2x ")
    assert_empty SiteIntegrity.srcset_urls(nil)
  end

  test "recognizes canonical and test origins with relative query and encoded fragments" do
    links = resolver
    assert_equal "https://adrianjunge.de/about#caf%C3%A9", links.target("https://adrianjunge.de/about#caf%C3%A9").to_s
    assert_equal "http://www.example.com/blog/post?q=term#heading", links.target("post?q=term#heading", from: "/blog/").to_s
    assert_equal "http://www.example.com/about#summary", links.target("#summary", from: "/about").to_s
    [ "https://external.example/about", "//external.example/about", "https://adrianjunge.de:444/about", "https://adrianjunge.de.evil.example/about", "https://user@adrianjunge.de/about", "mailto:test@example.com", "http://[" ].each do |url|
      assert_nil links.target(url), url
    end
  end

  test "follows relative and canonical redirects and inherits then replaces fragments" do
    routes = {
      "/old" => [ 301, { "Location" => "https://adrianjunge.de/middle" }, "" ],
      "/middle" => [ 308, { "location" => "/final#caf%C3%A9" }, "" ],
      "/final" => [ 200, {}, '<h1 id="café">Hello</h1>' ]
    }
    links = resolver(routes)
    result = links.resolve(links.target("/old#original"))
    assert_equal "/final", result.uri.path
    assert_equal "caf%C3%A9", result.uri.fragment
    assert links.fragment_exists?(result, document: Nokogiri::HTML(result.body))

    routes["/inherit"] = [ 302, { "Location" => "/final" }, "" ]
    inherited = links.resolve(links.target("/inherit#caf%C3%A9"))
    assert links.fragment_exists?(inherited, document: Nokogiri::HTML(inherited.body))
    missing = links.resolve(links.target("/inherit#missing"))
    assert_not links.fragment_exists?(missing, document: Nokogiri::HTML(missing.body))
  end

  test "rejects redirect loops excessive hops broken final destinations and external redirects without requesting them" do
    {
      loop: { "/start" => [ 301, { "Location" => "/start" }, "" ] },
      excessive: { "/start" => [ 301, { "Location" => "/middle" }, "" ], "/middle" => [ 302, { "Location" => "/final" }, "" ] },
      broken: { "/start" => [ 301, { "Location" => "/missing" }, "" ], "/missing" => [ 404, {}, "Missing" ] },
      external: { "/start" => [ 302, { "Location" => "https://external.example/" }, "" ] },
      empty: { "/start" => [ 302, {}, "" ] }
    }.each do |label, routes|
      links = resolver(routes, max_redirects: 1)
      assert_raises(SiteIntegrity::Failure, label.to_s) { links.resolve(links.target("/start")) }
    end
  end

  private

  def resolver(routes = {}, max_redirects: 5)
    SiteIntegrity::LocalLinks.new(origins: [ "http://www.example.com", "https://adrianjunge.de" ], max_redirects: max_redirects) do |path|
      routes.fetch(path) { flunk "unexpected request #{path}" }
    end
  end
end
