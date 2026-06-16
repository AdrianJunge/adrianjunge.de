require "cgi"
require "rouge"
require "rouge/plugins/redcarpet"

class HtmlWithCopy < Redcarpet::Render::HTML
  include Rouge::Plugins::Redcarpet

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

  def link(link, title, content)
    href = link.to_s
    attributes = { href: href }.merge(link_attributes_for(href))
    attributes[:title] = title unless title.to_s.empty?

    %(<a#{html_attributes(attributes)}>#{content}</a>)
  end

  private

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

      %( #{name}="#{CGI.escapeHTML(value.to_s)}")
    end.join
  end

  def code_for_display(code)
    code.to_s.sub(/\r?\n\z/, "")
  end

  def line_count(code)
    [ code.split("\n", -1).length, 1 ].max
  end
end
