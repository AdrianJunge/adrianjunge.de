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
