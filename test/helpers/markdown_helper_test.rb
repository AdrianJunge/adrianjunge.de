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
end
