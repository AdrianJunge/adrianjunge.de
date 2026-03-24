module MarkdownHelper
  require "redcarpet"
  require "rouge"
  require "rouge/plugins/redcarpet"

  def render_markdown(text)
    sanitized_text = text.gsub(/---([\S\s]*)---/, "").strip

    render_options = {
      no_links: false,
      hard_wrap: true,
      link_attributes: { target: "_blank" }
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

    html_content = "<div class='markdown-content'>
      <span style='color:white'>
        #{Redcarpet::Markdown.new(renderer, extensions).render(sanitized_text)}
      </span>
    </div>"

    replace_asset_paths(html_content)

    html_content.html_safe
  end

  def replace_asset_paths(html_content)
    html_content.gsub!(/(src|href)="([^"]*)"/) do
      attr = Regexp.last_match(1)
      path = Regexp.last_match(2)
      new_path = ActionController::Base.helpers.asset_path(path)
      "#{attr}=\"#{new_path}\""
    end
  end
end
