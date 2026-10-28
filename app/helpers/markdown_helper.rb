module MarkdownHelper
  require "redcarpet"
  require "rouge"
  require "rouge/plugins/redcarpet"
  require "digest"

  # Rendered HTML is public, author-controlled content, not user input. Cache
  # only the expensive deterministic rendering, never request-specific URLs.
  RENDER_CACHE = ActiveSupport::Cache::MemoryStore.new(size: 16.megabytes)
  RENDER_VERSION = "5".freeze
  INLINE_MATH_PATTERN = /(?<![\\$])\$(?!\$)(?:\\.|[^$\\])+\$(?!\$)|\\\(.*?\\\)/m

  def render_markdown(text, headings: nil, parsed: false, has_math: false)
    body = parsed ? text.to_s : FrontMatterParser::Parser.new(:md).call(text.to_s).content
    key = [ RENDER_VERSION, Digest::SHA256.hexdigest(body), ContentImageHelper.manifest_version, has_math == true ]
    result = RENDER_CACHE.fetch(key) { render_markdown_body(body, has_math: has_math == true) }
    headings.replace(result[:headings].deep_dup) if headings
    html_content = "<div class='markdown-content'>#{result[:html]}</div>"
    replace_asset_paths(html_content)
    html_content.html_safe
  end

  private

  def render_markdown_body(body, has_math: false)
    render_options = {
      no_links: false,
      hard_wrap: true
    }
    extensions = {
      disable_indented_code_blocks: true,
      hard_wrap: true,
      autolink: true,
      no_intra_emphasis: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      lax_spacing: true,
      space_after_headers: true,
      quote: true,
      footnotes: true,
      highlight: true,
      underline: true
    }
    renderer = HtmlWithCopy.new(render_options)
    rendered_markdown = Redcarpet::Markdown.new(renderer, extensions).render(body)
    rendered_markdown = isolate_inline_math(rendered_markdown) if has_math
    { html: rendered_markdown, headings: renderer.headings }
  end

  def isolate_inline_math(html)
    fragment = Nokogiri::HTML.fragment(html)
    fragment.xpath(".//text()[not(ancestor::code or ancestor::pre or ancestor::script or ancestor::style or ancestor::textarea)]").each do |node|
      text = node.text
      offset = 0
      text.to_enum(:scan, INLINE_MATH_PATTERN).each do
        match = Regexp.last_match
        node.add_previous_sibling(Nokogiri::XML::Text.new(text[offset...match.begin(0)], node.document))
        equation = Nokogiri::XML::Node.new("span", node.document)
        equation["class"] = "math-inline"
        equation.content = match[0]
        node.add_previous_sibling(equation)
        offset = match.end(0)
      end
      next if offset.zero?

      # MathJax can replace the equation's text node without removing native
      # text-fragment highlights from the surrounding prose.
      node.add_previous_sibling(Nokogiri::XML::Text.new(text[offset..], node.document))
      node.remove
    end
    fragment.to_html
  end

  def replace_asset_paths(html_content)
    html_content.gsub!(/(src|href)="([^"]*)"/) do
      attr = Regexp.last_match(1)
      path = Regexp.last_match(2)
      new_path = local_asset_reference?(path) ? ActionController::Base.helpers.asset_path(path) : path
      "#{attr}=\"#{new_path}\""
    end
    html_content.gsub!(/srcset="([^"]*)"/) do
      candidates = CGI.unescapeHTML(Regexp.last_match(1)).split(",").map do |candidate|
        path, descriptor = candidate.strip.split(/\s+/, 2)
        path = ActionController::Base.helpers.asset_path(path) if local_asset_reference?(path)
        [ path, descriptor ].compact.join(" ")
      end
      %(srcset="#{CGI.escapeHTML(candidates.join(", "))}")
    end
  end

  def local_asset_reference?(path)
    path.present? &&
      !path.start_with?("#", "/", "//") &&
      !path.match?(/\A[a-z][a-z0-9+\-.]*:/i) &&
      path.match?(/\A(?:blog|ctf|variants|landing|other|task-bar)\//)
  end
end
