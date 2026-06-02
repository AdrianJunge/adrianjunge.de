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

  test "legacy section feeds point to the generic website feed" do
    get ctf_feed_path
    assert_redirected_to feed_path

    get "/ctf/feed.atom"
    assert_redirected_to feed_path(format: :atom)

    get blog_feed_path
    assert_redirected_to feed_path

    get "/blog/feed.atom"
    assert_redirected_to feed_path(format: :atom)
  end
end
