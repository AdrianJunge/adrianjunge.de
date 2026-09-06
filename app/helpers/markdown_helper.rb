module MarkdownHelper
  require "redcarpet"
  require "rouge"
  require "rouge/plugins/redcarpet"
  require "digest"

  # Rendered HTML is public, author-controlled content, not user input. Cache
  # only the expensive deterministic rendering, never request-specific URLs.
  RENDER_CACHE = ActiveSupport::Cache::MemoryStore.new(size: 16.megabytes)
  RENDER_VERSION = "2".freeze

  def render_markdown(text, headings: nil, parsed: false)
    body = parsed ? text.to_s : FrontMatterParser::Parser.new(:md).call(text.to_s).content
    key = [ RENDER_VERSION, Digest::SHA256.hexdigest(body), ContentImageHelper.manifest_version ]
    result = RENDER_CACHE.fetch(key) { render_markdown_body(body) }
    headings.replace(result[:headings].deep_dup) if headings
    html_content = "<div class='markdown-content'>#{result[:html]}</div>"
    replace_asset_paths(html_content)
    html_content.html_safe
  end

  private

  def render_markdown_body(body)
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
    { html: rendered_markdown, headings: renderer.headings }
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
      path.match?(/\A(?:blog|ctf|variants|landing|other|task-bar|terminal)\//)
  end
end
