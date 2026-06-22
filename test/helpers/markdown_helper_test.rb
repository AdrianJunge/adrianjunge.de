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

  test "markdown headings are numbered and anchored automatically" do
    headings = []
    html = render_markdown(<<~MARKDOWN, headings: headings)
      # Intro
      ## Subintro
      ### Details
    MARKDOWN

    fragment = Nokogiri::HTML.fragment(html)

    assert_equal [ "1. Intro", "1.1. Subintro", "1.1.1. Details" ], fragment.css("h1, h2, h3").map { |heading| heading.text.squish }
    assert_equal [ "intro", "subintro", "details" ], fragment.css("h1 a[id], h2 a[id], h3 a[id]").map { |anchor| anchor["id"] }
    assert_equal [
      { text: "1. Intro", anchor: "intro", depth: 0 },
      { text: "1.1. Subintro", anchor: "subintro", depth: 1 },
      { text: "1.1.1. Details", anchor: "details", depth: 2 }
    ], headings
  end

  test "manual heading numbers are replaced while legacy anchors remain available" do
    headings = []
    html = render_markdown(<<~MARKDOWN, headings: headings)
      # TL;DR<a id="legacy-summary"></a>
      # 1. Intro<a id="legacy intro"></a>
      # 1.1. Child<a id="legacy child"></a>
      # 2. Next<a id="next"></a>
    MARKDOWN

    fragment = Nokogiri::HTML.fragment(html)

    assert_equal [ "TL;DR", "1. Intro", "1.1. Child", "2. Next" ], fragment.css("h1").map { |heading| heading.text.squish }
    assert_equal [
      { text: "TL;DR", anchor: "tl-dr", depth: 0 },
      { text: "1. Intro", anchor: "intro", depth: 0 },
      { text: "1.1. Child", anchor: "child", depth: 1 },
      { text: "2. Next", anchor: "next", depth: 0 }
    ], headings
    assert fragment.at_xpath(".//a[@id='legacy intro']")
    assert fragment.at_xpath(".//a[@id='legacy child']")
  end

  test "markdown images render as figures with visible captions" do
    html = render_markdown('![Diagram alt text](blog/posts/java-strings/java-string-pool.png "Diagram caption")')
    fragment = Nokogiri::HTML.fragment(html)
    figure = fragment.at_css(".markdown-content > figure.markdown-figure")

    assert figure
    assert_equal "Diagram alt text", figure.at_css("img")["alt"]
    assert_includes figure.at_css("img")["src"], "/assets/blog/posts/java-strings/java-string-pool"
    assert_equal "Diagram alt text", figure.at_css("figcaption").text
  end
end
