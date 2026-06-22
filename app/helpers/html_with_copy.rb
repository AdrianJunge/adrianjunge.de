require "cgi"
require "rouge"
require "rouge/plugins/redcarpet"
require "set"

class HtmlWithCopy < Redcarpet::Render::HTML
  include Rouge::Plugins::Redcarpet

  attr_reader :headings

  ANCHOR_PATTERN = /<a\b[^>]*\bid=(["'])(.*?)\1[^>]*>\s*<\/a>/i
  MANUAL_NUMBER_PATTERN = /\A(?<number>\d+(?:\.\d+)+(?:\.)?|\d+\.)\s+/
  UNNUMBERED_HEADING_PATTERN = /\A(?:tl;?dr|tldr)\z/i

  class CodeBlockLineFormatter < Rouge::Formatter
    def initialize(formatter, line_count)
      @formatter = Rouge::Formatters::HTML.assert_html_formatter!(formatter)
      @line_count = [ line_count.to_i, 1 ].max
    end

    def stream(tokens)
      line_number = 0

      token_lines(tokens) do |line_tokens|
        line_number += 1
        stream_line(line_number, line_tokens) { |piece| yield piece }
      end

      while line_number < @line_count
        line_number += 1
        stream_line(line_number, []) { |piece| yield piece }
      end
    end

    private

    def stream_line(line_number, line_tokens)
      yield %(<span class="code-line" data-line="#{line_number}"><span class="code-line-content">)
      line_tokens.each do |token, value|
        yield @formatter.span(token, value)
      end
      yield %(</span></span>)
    end
  end

  def initialize(options = {})
    super
    @headings = []
    @heading_counters = []
    @used_anchor_ids = Set.new
  end

  def block_code(code, language)
    display_code = code_for_display(code)
    lexer        = Rouge::Lexer.find_fancy(language || "text", display_code)
    formatter    = Rouge::Formatters::HTML.new
    highlighted  = CodeBlockLineFormatter.new(formatter, line_count(display_code)).format(lexer.lex(display_code))

    escaped = CGI.escapeHTML(code.to_s)

    <<~HTML
      <div class="code-block">
        <button class="copy-btn" data-code="#{escaped}" title="Copy to clipboard">
          📋
        </button>
        <pre class="highlight"><code>#{highlighted}</code></pre>
      </div>
    HTML
  end

  def header(text, level)
    heading = heading_details(text.to_s, level.to_i)
    number = next_heading_number(heading[:depth], heading[:plain_text])
    toc_text = [ number, heading[:plain_text] ].compact.join(" ")
    anchor = unique_anchor(slugify(heading[:plain_text]))
    alias_anchors = heading[:explicit_ids].filter_map { |id| reserve_anchor_alias(id, anchor) }

    @headings << {
      text: toc_text,
      anchor: anchor,
      depth: heading[:depth]
    }

    <<~HTML
      <h#{level}>
        #{heading_number_span(number)}<span class="markdown-heading-text">#{heading[:html]}</span><a id="#{escape_attribute(anchor)}"></a>#{alias_anchors.join}
      </h#{level}>
    HTML
  end

  def paragraph(text)
    stripped_text = text.to_s.strip
    return "#{stripped_text}\n" if standalone_figure?(stripped_text)

    "<p>#{text}</p>\n"
  end

  def link(link, title, content)
    href = link.to_s
    attributes = { href: href }.merge(link_attributes_for(href))
    attributes[:title] = title unless title.to_s.empty?

    %(<a#{html_attributes(attributes)}>#{content}</a>)
  end

  def image(link, title, alt)
    image_attributes = {
      src: link.to_s,
      alt: alt.to_s,
      title: title.to_s.presence,
      loading: "lazy"
    }
    caption = alt.to_s.presence

    image_html = %(<img#{html_attributes(image_attributes)}>)
    caption_html = caption ? %(<figcaption>#{CGI.escapeHTML(caption)}</figcaption>) : ""

    %(<figure class="markdown-figure">#{image_html}#{caption_html}</figure>)
  end

  private

  def heading_details(text, level)
    explicit_ids = text.scan(ANCHOR_PATTERN).map { |_, id| CGI.unescapeHTML(id.to_s.strip) }.reject(&:empty?)
    heading_html = text.gsub(ANCHOR_PATTERN, "").strip
    manual_number = heading_html[MANUAL_NUMBER_PATTERN, :number].to_s
    heading_html = heading_html.sub(MANUAL_NUMBER_PATTERN, "").strip
    plain_text = plain_text(heading_html)
    manual_depth = manual_number_depth(manual_number)
    markdown_depth = [ level - 1, 0 ].max

    {
      html: heading_html,
      plain_text: plain_text,
      explicit_ids: explicit_ids,
      depth: [ markdown_depth, manual_depth ].compact.max
    }
  end

  def next_heading_number(depth, plain_text)
    return nil if plain_text.match?(UNNUMBERED_HEADING_PATTERN)

    (0...depth).each do |index|
      @heading_counters[index] = 1 if @heading_counters[index].to_i.zero?
    end

    @heading_counters[depth] = @heading_counters[depth].to_i + 1
    @heading_counters = @heading_counters[0..depth]

    "#{@heading_counters.join(".")}."
  end

  def heading_number_span(number)
    return "" unless number

    %(<span class="markdown-heading-number">#{CGI.escapeHTML(number)}</span> )
  end

  def manual_number_depth(number)
    return nil if number.empty?

    number.delete_suffix(".").split(".").length - 1
  end

  def plain_text(html)
    CGI.unescapeHTML(html.gsub(/<[^>]+>/, "")).strip
  end

  def slugify(text)
    slug = text.to_s.downcase.gsub(/[^\p{Alnum}]+/u, "-").gsub(/\A-+|-+\z/, "")
    slug.presence || "section"
  end

  def unique_anchor(base)
    candidate = base
    suffix = 1

    while @used_anchor_ids.include?(candidate)
      suffix += 1
      candidate = "#{base}-#{suffix}"
    end

    @used_anchor_ids.add(candidate)
    candidate
  end

  def reserve_anchor_alias(id, canonical_anchor)
    return nil if id.blank? || id == canonical_anchor || @used_anchor_ids.include?(id)

    @used_anchor_ids.add(id)
    %(<a id="#{escape_attribute(id)}"></a>)
  end

  def standalone_figure?(text)
    text.match?(/\A<figure\b.*<\/figure>\z/m)
  end

  def link_attributes_for(href)
    return { rel: "noopener" } if internal_link?(href)
    return { target: "_blank", rel: "noopener noreferrer" } if external_link?(href)

    {}
  end

  def internal_link?(href)
    href.start_with?("#") || (href.start_with?("/") && !href.start_with?("//"))
  end

  def external_link?(href)
    href.match?(%r{\Ahttps?://}i)
  end

  def html_attributes(attributes)
    attributes.filter_map do |name, value|
      next if value.nil? || value.to_s.empty?

      %( #{name}="#{escape_attribute(value)}")
    end.join
  end

  def escape_attribute(value)
    CGI.escapeHTML(value.to_s)
  end

  def code_for_display(code)
    code.to_s.sub(/\r?\n\z/, "")
  end

  def line_count(code)
    [ code.split("\n", -1).length, 1 ].max
  end
end
