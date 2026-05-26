module CtfHelper
  def get_category_svg(category)
    svg_filename = Rails.root.join("app", "assets", "ctf", "categories", "#{category.downcase}.svg")
    svg_path = File.exist?(svg_filename) ? svg_filename : Rails.root.join("app", "assets", "ctf", "categories", "default.svg")
    svg = File.read(svg_path)
    svg.gsub("<svg", '<svg style="width: 6vh; height: 6vh;" ')
  end

  def render_writeup_card(writeup, writeup_path, info)
    max_description_length = 200
    categories = Array(info["categories"]).presence || [ "Unknown category" ]
    first_category = categories&.first || "unknown"
    title = info["title"].presence || writeup.capitalize
    description = info["description"] || "No description available"
    published = info["published"] || "Unknown date"
    authors = writeup_authors(info)
    published_year = writeup_year(info)
    filter_text = ([ title, description, published, published_year ] + categories + authors.map { |author| author[:name] }).compact.join(" ")

    content_tag(
      :article,
      class: "blog-post-card writeup-post-card ui-hover-lift",
      data: {
        filter_card: "writeups",
        filter_text: filter_text,
        filter_tags: categories.join("|"),
        filter_years: published_year
      }
    ) do
      hitbox_html = link_to("", writeup_path, class: "blog-post-card-hitbox", aria: { label: "Open #{title} writeup" })

      content_tag(:div, class: "blog-post-card-content") do
        logo_html = content_tag(:div, class: "blog-post-card-logo writeup-post-card-logo") do
          get_category_svg(first_category).html_safe
        end

        details_html = content_tag(:div, class: "blog-post-card-details") do
          title_html = content_tag(:h3, title, class: "blog-post-title")

          meta_html = content_tag(:div, class: "blog-post-meta") do
            content_tag(:div, class: "blog-post-meta-row") do
              safe_join(categories.map do |category|
                content_tag(
                  :button,
                  category,
                  type: "button",
                  class: "filter-chip ui-hover-lift",
                  data: { filter_scope: "writeups", filter_tag: category },
                  aria: { pressed: "false", label: "Filter writeups by #{category}" }
                )
              end)
            end
          end

          authors_html = content_tag(:div, class: "blog-post-authors") do
            safe_join([
              content_tag(:span, "Challenge by"),
              safe_join(authors.map { |author| author_node(author) }, ", ".html_safe)
            ], " ".html_safe)
          end

          truncated_description = description.length > max_description_length ? "#{description[0, max_description_length]}..." : description
          description_html = content_tag(:p, truncated_description, class: "blog-post-description")

          date_html = content_tag(:div, class: "blog-post-date") do
            content_tag(:span, published, class: "blog-post-date-text")
          end

          title_html + meta_html + authors_html + description_html + date_html
        end

        logo_html + details_html
      end + hitbox_html
    end
  end

  private

  def writeup_year(info)
    return Time.parse(info["published"].to_s).year if info["published"].present?

    info["year"].presence
  rescue StandardError
    info["year"].presence
  end

  def writeup_authors(info)
    explicit_authors = info["authors"].presence
    link_map = info["author_urls"].presence || info["author_links"].presence || {}

    authors =
      if explicit_authors.is_a?(Array)
        explicit_authors.filter_map do |author|
          author_from_entry(author, link_map)
        end
      else
        author_names = info["author"].to_s.split(",").map(&:strip).reject(&:blank?)
        author_names.map do |name|
          {
            name: name,
            url: link_map[name].presence || (author_names.one? ? info["author_url"].presence : nil)
          }
        end
      end

    authors.presence || [ { name: "Unknown author", url: nil } ]
  end

  def author_from_entry(author, link_map)
    if author.is_a?(Hash)
      name = author["name"].presence || author[:name].presence
      return nil if name.blank?

      {
        name: name,
        url: author["url"].presence || author[:url].presence || link_map[name].presence
      }
    else
      name = author.to_s.strip
      return nil if name.blank?

      { name: name, url: link_map[name].presence }
    end
  end

  def author_node(author)
    if author[:url].present?
      link_to(author[:name], author[:url], author_link_options(author[:url]))
    else
      content_tag(:span, author[:name], class: "blog-post-author-name")
    end
  end

  def author_link_options(url)
    options = { class: "blog-post-author-link" }
    return options unless url.to_s.match?(%r{\Ahttps?://}i)

    options.merge(target: "_blank", rel: "noopener noreferrer")
  end
end
