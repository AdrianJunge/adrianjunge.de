require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  include MarkdownHelper

  test "code blocks render logical line numbers without changing copy text" do
    html = render_markdown(<<~MARKDOWN)
      ```ruby
      puts "one"

      puts "two"
      ```
    MARKDOWN

    fragment = Nokogiri::HTML.fragment(html)
    lines = fragment.css(".code-block pre.highlight code .code-line")

    assert_equal [ "1", "2", "3" ], lines.map { |line| line["data-line"] }
    assert_equal 3, fragment.css(".code-block pre.highlight code .code-line-content").length
    assert_equal "puts \"one\"\n\nputs \"two\"\n", fragment.at_css(".copy-btn")["data-code"]
  end

  test "markdown links opened in new tabs include noopener noreferrer" do
    html = render_markdown("[external](https://example.com)")
    fragment = Nokogiri::HTML.fragment(html)
    link = fragment.at_css(".markdown-content a[href='https://example.com']")

    assert_equal "_blank", link["target"]
    assert_includes link["rel"].split, "noopener"
    assert_includes link["rel"].split, "noreferrer"
  end

  test "markdown links to local article sections stay in the same tab" do
    html = render_markdown("[section 2.1](/blog/joomla-sqli#how-joomla-interacts-with-the-database)")
    fragment = Nokogiri::HTML.fragment(html)
    link = fragment.at_css(".markdown-content a[href='/blog/joomla-sqli#how-joomla-interacts-with-the-database']")

    assert_nil link["target"]
    assert_equal "noopener", link["rel"]
  end

  test "markdown links to same-page anchors stay in the same tab" do
    html = render_markdown("[section 2.1](#how-joomla-interacts-with-the-database)")
    fragment = Nokogiri::HTML.fragment(html)
    link = fragment.at_css(".markdown-content a[href='#how-joomla-interacts-with-the-database']")

    assert_nil link["target"]
    assert_equal "noopener", link["rel"]
  end
end
