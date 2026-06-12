require "test_helper"

class FeedsControllerTest < ActionDispatch::IntegrationTest
  test "rss feed merges blog posts and ctf writeups" do
    get feed_path

    assert_response :success
    assert_equal "application/rss+xml", response.media_type
    assert_includes response.body, "<title>adrianjunge.de</title>"
    assert_includes response.body, "<category>Blog post</category>"
    assert_includes response.body, "<category>CTF writeup</category>"
    assert_match %r{<link>http://www\.example\.com/blog/}, response.body
    assert_match %r{<link>http://www\.example\.com/ctf/}, response.body
    assert_not_includes response.body, "frankendancer-net-shred-overrun"
  end

  test "xml feed path renders the rss feed as browser-friendly xml" do
    get feed_xml_path

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_includes response.body, "<title>adrianjunge.de</title>"
    assert_match %r{<link>http://www\.example\.com/blog/}, response.body
  end

  test "atom feed merges blog posts and ctf writeups" do
    get feed_path(format: :atom)

    assert_response :success
    assert_equal "application/atom+xml", response.media_type
    assert_includes response.body, "<title>adrianjunge.de</title>"
    assert_includes response.body, '<category term="Blog post"/>'
    assert_includes response.body, '<category term="CTF writeup"/>'
    assert_match %r{href="http://www\.example\.com/blog/}, response.body
    assert_match %r{href="http://www\.example\.com/ctf/}, response.body
    assert_not_includes response.body, "frankendancer-net-shred-overrun"
  end

  test "json feed merges blog posts and ctf writeups" do
    get feed_json_path

    assert_response :success
    assert_equal "application/feed+json", response.media_type
    feed = JSON.parse(response.body)
    assert_equal "https://jsonfeed.org/version/1.1", feed["version"]
    assert_equal "adrianjunge.de", feed["title"]
    assert_equal feed_json_url, feed["feed_url"]
    assert feed["items"].any? { |item| item["url"].start_with?("http://www.example.com/blog/") }
    assert feed["items"].any? { |item| item["url"].start_with?("http://www.example.com/ctf/") }
    assert_not response.body.include?("frankendancer-net-shred-overrun")
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
end
