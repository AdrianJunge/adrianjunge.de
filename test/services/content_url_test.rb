require "test_helper"

class ContentUrlTest < ActiveSupport::TestCase
  test "local paths encode segments once and preserve query templates and fragments" do
    assert_equal "/ctf/event/Hello%20World", ContentUrl.encoded_path("/ctf/event/Hello World")
    assert_equal "/ctf/event/Hello%20World", ContentUrl.encoded_path("/ctf/event/Hello%20World")
    assert_equal "/blog/C%2B%2B/", ContentUrl.encoded_path("/blog/C++/")
    assert_equal "/posts?q={search_term_string}#results", ContentUrl.encoded_path("/posts?q={search_term_string}#results")
    assert_equal "/about#contact", ContentUrl.encoded_path("/about#contact")
    assert_equal "/", ContentUrl.encoded_path("/")
    assert_equal "https://example.com/path", ContentUrl.encoded_path("https://example.com/path")
  end
end
