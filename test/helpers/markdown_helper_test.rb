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
    assert_equal "puts \"one\"\n\nputs \"two\"\n", fragment.at_css(".code-block code").text
    assert_nil fragment.at_css(".copy-btn")["data-code"]
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
    html = render_markdown("[section](/blog/example-post#example-section)")
    fragment = Nokogiri::HTML.fragment(html)
    link = fragment.at_css(".markdown-content a[href='/blog/example-post#example-section']")

    assert_nil link["target"]
    assert_equal "noopener", link["rel"]
  end

  test "markdown links to same-page anchors stay in the same tab" do
    html = render_markdown("[section](#example-section)")
    fragment = Nokogiri::HTML.fragment(html)
    link = fragment.at_css(".markdown-content a[href='#example-section']")

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

    assert_empty fragment.css("h1")
    assert_equal [ "1. Intro", "1.1. Subintro", "1.1.1. Details" ], fragment.css("h2, h3, h4").map { |heading| heading.text.squish }
    assert_equal [ "intro", "subintro", "details" ], fragment.css("h2 a[id], h3 a[id], h4 a[id]").map { |anchor| anchor["id"] }
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

    assert_equal [ "TL;DR", "1. Intro", "1.1. Child", "2. Next" ], fragment.css("h2, h3").map { |heading| heading.text.squish }
    assert_equal "1.1. Child", fragment.at_css("h3").text.squish
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
    html = render_markdown('![Diagram alt text](ctf/categories/default.svg "Diagram caption")')
    fragment = Nokogiri::HTML.fragment(html)
    figure = fragment.at_css(".markdown-content > figure.markdown-figure")

    assert figure
    assert_equal "Diagram alt text", figure.at_css("img")["alt"]
    assert_includes figure.at_css("img")["src"], "#{asset_path_prefix}/ctf/categories/default"
    assert_equal "Diagram alt text", figure.at_css("figcaption").text
  end

  test "clipboard text preserves whitespace without a second copy of the source" do
    [ "", "\n", "\n\n", "one", "one\n", "one\n\n", "\t  λ <>&\n\n  two\t\n", "one\r\ntwo\r\n" ].each do |source|
      fragment = Nokogiri::HTML.fragment(HtmlWithCopy.new.block_code(source, "text"))
      assert_equal source, fragment.at_css("code").text, source.inspect
      assert_nil fragment.at_css("button")["data-code"]
      assert_equal "Copy code", fragment.at_css("button")["aria-label"]
      assert fragment.at_css(".copy-status[role=status]")
    end
  end

  test "unknown or ambiguous language labels fall back to escaped plain text" do
    source = "<example> & text\n"
    fragment = Nokogiri::HTML.fragment(HtmlWithCopy.new.block_code(source, "not-a-language"))
    assert_equal source, fragment.at_css("code").text
    assert_nil fragment.at_css("example")
    original = Rouge::Lexer.method(:find_fancy)
    Rouge::Lexer.define_singleton_method(:find_fancy) { |*| raise Rouge::Guesser::Ambiguous.new([]) }
    assert_equal source, Nokogiri::HTML.fragment(HtmlWithCopy.new.block_code(source, "guess")).at_css("code").text
  ensure
    Rouge::Lexer.define_singleton_method(:find_fancy, original) if original
  end

  test "parsed bodies preserve body separators and unparsed input uses the shared parser" do
    markdown = "---\ntitle: Hidden metadata\n---\n# Visible\n\n---\n\nBody"
    fragment = Nokogiri::HTML.fragment(render_markdown(markdown))
    assert_not_includes fragment.text, "Hidden metadata"
    assert fragment.at_css("hr")
    parsed_fragment = Nokogiri::HTML.fragment(render_markdown("---\n\nBody", parsed: true))
    assert parsed_fragment.at_css("hr")
    assert_includes parsed_fragment.text, "Body"
  end

  test "cached renders cannot leak mutable headings and change when the body changes" do
    MarkdownHelper::RENDER_CACHE.clear
    first = []
    render_markdown("# Original", headings: first, parsed: true)
    first.first[:text].replace("mutated")
    second = []
    render_markdown("# Original", headings: second, parsed: true)
    assert_equal "1. Original", second.first[:text]
    third = []
    render_markdown("# Changed", headings: third, parsed: true)
    assert_equal "1. Changed", third.first[:text]
  end

  test "responsive markdown images resolve fingerprinted variants and intrinsic dimensions" do
    fragment = Nokogiri::HTML.fragment(render_markdown("![CTF](ctf/lactf.png)"))
    image = fragment.at_css("img")
    assert image["width"].to_i.positive?
    assert image["height"].to_i.positive?
    assert_equal "lazy", image["loading"]
    assert_equal "async", image["decoding"]
    assert_includes image["src"], "#{asset_path_prefix}/variants/ctf/lactf"
    assert image["srcset"].split(",").all? { |candidate| candidate.strip.start_with?("#{asset_path_prefix}/variants/") }
  end

  test "non ASCII duplicate headings and legacy aliases remain stable below the page title" do
    fragment = Nokogiri::HTML.fragment(render_markdown("# Grüße\n# Grüße\n###### Deep"))
    assert_equal [ "grüße", "grüße-2", "deep" ], fragment.css("a[id]").map { |anchor| anchor["id"] }
    assert_equal [ "h2", "h2", "h6" ], fragment.css("h2, h6").map(&:name)
  end
end
