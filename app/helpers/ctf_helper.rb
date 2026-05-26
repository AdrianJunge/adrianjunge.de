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
    description = info["description"] || "No description available"
    published = info["published"] || "Unknown date"

    content_tag(:a, href: writeup_path) do
      concat(content_tag(:div, class: "flex items-center") do
        concat(get_category_svg(first_category).html_safe)

        concat(content_tag(:h5, class: "ml-4 text-2xl font-semibold tracking-tight text-white") do
          writeup.capitalize
        end)
      end)

      concat(
        content_tag(:div, class: "writeup-details") do
          concat(content_tag(:div, class: "mb-4 flex flex-wrap gap-2") do
            categories.each do |category|
              concat(content_tag(:span, category, class: "inline-block px-2 py-1 text-xs font-medium text-black bg-gray-200 rounded"))
            end
          end)
          truncated_description = description.length > max_description_length ? "#{description[0, max_description_length]}..." : description
          concat(content_tag(:p, class: "text-white italic") do
            truncated_description
          end)
        end
      )

      concat(content_tag(:div, class: "mt-4") do
        concat(content_tag(:span, "#{published}", class: "text-sm text-gray-400"))
      end)
    end
  end
end
