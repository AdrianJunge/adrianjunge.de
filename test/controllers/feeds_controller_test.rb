require "test_helper"

class FeedsControllerTest < ActionDispatch::IntegrationTest
  test "rss feed merges blog posts and ctf writeups" do
    get feed_path

    assert_response :success
    assert_equal "application/rss+xml", response.media_type
    document = Nokogiri::XML(response.body)
    assert_empty document.errors
    assert_equal "adrianjunge.de", document.at_xpath("/rss/channel/title").text
    assert_equal expected_feed_urls, document.xpath("/rss/channel/item/link").map(&:text)
    assert_equal expected_feed_sources, document.xpath("/rss/channel/item/category").map(&:text)
    assert_not_includes response.body, "%2520"
  end

  test "xml feed path renders the rss feed as browser-friendly xml" do
    get feed_xml_path

    assert_response :success
    assert_equal "application/xml", response.media_type
    document = Nokogiri::XML(response.body)
    assert_empty document.errors
    assert_equal "adrianjunge.de", document.at_xpath("/rss/channel/title").text
    assert_equal expected_feed_urls, document.xpath("/rss/channel/item/link").map(&:text)
  end

  test "atom feed merges blog posts and ctf writeups" do
    get feed_path(format: :atom)

    assert_response :success
    assert_equal "application/atom+xml", response.media_type
    document = Nokogiri::XML(response.body)
    assert_empty document.errors
    namespace = { "atom" => "http://www.w3.org/2005/Atom" }
    assert_equal "Adrian Junge", document.at_xpath("/atom:feed/atom:author/atom:name", namespace).text
    assert_equal "adrianjunge.de", document.at_xpath("/atom:feed/atom:title", namespace).text
    assert_equal expected_feed_urls,
                 document.xpath("/atom:feed/atom:entry/atom:link[@rel='alternate']", namespace).map { |node| node["href"] }
    assert_equal expected_feed_sources,
                 document.xpath("/atom:feed/atom:entry/atom:category", namespace).map { |node| node["term"] }
    assert_not_includes response.body, "%2520"
  end

  test "json feed merges blog posts and ctf writeups" do
    get feed_json_path

    assert_response :success
    assert_equal "application/feed+json", response.media_type
    feed = JSON.parse(response.body)
    assert_equal "https://jsonfeed.org/version/1.1", feed["version"]
    assert_equal "adrianjunge.de", feed["title"]
    assert_equal feed_json_url, feed["feed_url"]
    assert_equal expected_feed_urls, feed["items"].map { |item| item["url"] }
    assert_equal expected_feed_sources.map { |source| [ source ] }, feed["items"].map { |item| item["tags"] }
    assert_not_includes response.body, "%2520"
  end

  test "legacy section feeds point to the generic website feed" do
    get ctf_feed_path
    assert_redirected_to feed_xml_path

    get "/ctf/feed.atom"
    assert_redirected_to feed_path(format: :atom)

    get "/ctf/feed.json"
    assert_redirected_to feed_json_path

    get blog_feed_path
    assert_redirected_to feed_xml_path

    get "/blog/feed.atom"
    assert_redirected_to feed_path(format: :atom)

    get "/blog/feed.json"
    assert_redirected_to feed_json_path

    get "/blog/feed.xml"
    assert_redirected_to feed_xml_path

    get "/ctf/feed.xml"
    assert_redirected_to feed_xml_path
  end

  test "feeds are stable across requests and honor conditional validators" do
    [ feed_path, feed_xml_path, feed_path(format: :atom), feed_json_path ].each do |path|
      get path
      assert_response :success
      body = response.body
      etag = response.headers.fetch("ETag")
      get path
      assert_equal body, response.body
      assert_equal etag, response.headers["ETag"]
      get path, headers: { "If-None-Match" => etag }
      assert_response :not_modified
      assert_empty response.body
    end
  end

  test "editing relevant feed fields changes the validator without changing publication" do
    repository = fixture_content_repository
    with_stubbed_content_repository(repository) do
      get feed_json_path
      etag = response.headers.fetch("ETag")
      post = repository.blog_posts.first
      published = post[:published]
      post[:title] = "Revised fixture title"
      post[:modified] = published + 1.day
      get feed_json_path, headers: { "If-None-Match" => etag }
      assert_response :success
      assert_not_equal etag, response.headers["ETag"]
      item = JSON.parse(response.body).fetch("items").find { |entry| entry["title"] == post[:title] }
      assert_equal published.iso8601, item["date_published"]
      assert_equal post[:modified].iso8601, item["date_modified"]
    end
  end

  test "empty feeds use a deterministic epoch" do
    repository = Object.new
    repository.define_singleton_method(:feed_posts) { [] }
    with_stubbed_content_repository(repository) do
      get feed_path
      assert_response :success
      document = Nokogiri::XML(response.body)
      assert_equal ContentDate::EPOCH.rfc2822, document.at_xpath("/rss/channel/lastBuildDate").text
    end
  end

  private

  def expected_feed_urls
    production_content_repository.feed_posts.map do |item|
      path, fragment = item[:link].to_s.split("#", 2)
      encoded_path = path.split("/", -1).map { |segment| ERB::Util.url_encode(CGI.unescape(segment)) }.join("/")
      "http://www.example.com#{encoded_path}#{"##{fragment}" if fragment.present?}"
    end
  end

  def expected_feed_sources
    production_content_repository.feed_posts.map { |item| item[:source_label] }
  end
end
