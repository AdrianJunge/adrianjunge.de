module MarkdownHelper
  require "redcarpet"
  require "rouge"
  require "rouge/plugins/redcarpet"

  def render_markdown(text, headings: nil)
    sanitized_text = text.to_s.sub(/\A---\s*\n.*?\n---\s*\n/m, "").strip

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
    rendered_markdown = Redcarpet::Markdown.new(renderer, extensions).render(sanitized_text)
    headings.replace(renderer.headings) if headings

    html_content = "<div class='markdown-content'>
      #{rendered_markdown}
    </div>"

    replace_asset_paths(html_content)

    html_content.html_safe
  end

  def replace_asset_paths(html_content)
    html_content.gsub!(/(src|href)="([^"]*)"/) do
      attr = Regexp.last_match(1)
      path = Regexp.last_match(2)
      new_path = local_asset_reference?(path) ? ActionController::Base.helpers.asset_path(path) : path
      "#{attr}=\"#{new_path}\""
    end
  end

  def local_asset_reference?(path)
    path.present? &&
      !path.start_with?("#", "/", "//") &&
      !path.match?(/\A[a-z][a-z0-9+\-.]*:/i) &&
      path.match?(/\A(?:blog|ctf)\//)
  end
end
