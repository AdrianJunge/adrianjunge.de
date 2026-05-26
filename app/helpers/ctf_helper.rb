module CtfHelper
  def get_category_svg(category)
    svg_filename = Rails.root.join("app", "assets", "ctf", "categories", "#{category.downcase}.svg")
    svg_path = File.exist?(svg_filename) ? svg_filename : Rails.root.join("app", "assets", "ctf", "categories", "default.svg")
    svg = File.read(svg_path)
    svg.gsub("<svg", '<svg style="width: 6vh; height: 6vh;" ')
  end

  def render_writeup_card(writeup, writeup_path, info)
    max_description_length = 200
    categories = info["categories"] || [ "Unknown category" ]
    first_category = categories&.first || "unknown"
    title = info["title"].presence || writeup.capitalize
    description = info["description"] || "No description available"
    published = info["published"] || "Unknown date"

    content_tag(:a, href: writeup_path, class: "blog-post-card writeup-post-card") do
      content_tag(:div, class: "blog-post-card-content") do
        logo_html = content_tag(:div, class: "blog-post-card-logo writeup-post-card-logo") do
          get_category_svg(first_category).html_safe
        end

        details_html = content_tag(:div, class: "blog-post-card-details") do
          title_html = content_tag(:h3, title, class: "blog-post-title")

          meta_html = content_tag(:div, class: "blog-post-meta") do
            content_tag(:div, class: "flex flex-wrap gap-2") do
              categories.map do |category|
                content_tag(:span, category, class: "inline-block px-2 py-1 text-xs font-medium text-white bg-slate-700 rounded")
              end.join.html_safe
            end
          end

          truncated_description = description.length > max_description_length ? "#{description[0, max_description_length]}..." : description
          description_html = content_tag(:p, truncated_description, class: "blog-post-description")

          date_html = content_tag(:div, class: "blog-post-date") do
            content_tag(:span, published, class: "blog-post-date-text")
          end

          title_html + meta_html + description_html + date_html
        end

        logo_html + details_html
      end
    end
  end
end
