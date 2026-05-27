module CtfHelper
  def get_category_svg(category)
    svg_filename = Rails.root.join("app", "assets", "ctf", "categories", "#{category.downcase}.svg")
    svg_path = File.exist?(svg_filename) ? svg_filename : Rails.root.join("app", "assets", "ctf", "categories", "default.svg")
    svg = File.read(svg_path)
    svg.gsub("<svg", '<svg style="width: 6vh; height: 6vh;" ')
  end

  def render_writeup_card(writeup, writeup_path, info, logo: nil)
    max_description_length = 200
    categories = Array(info["categories"]).presence || [ "Unknown category" ]
    first_category = categories&.first || "unknown"
    title = info["title"].presence || writeup.capitalize
    description = info["description"] || "No description available"
    published = info["published"] || "Unknown date"
    authors = writeup_authors(info)
    published_year = writeup_year(info)
    winner = writeup_winner(info)
    winner_label = winner&.fetch(:label, nil)
    winner_filter_label = winner ? WriteupWinner::FILTER_LABEL : nil
    filter_tags = ([ winner_filter_label ] + categories).compact
    filter_text = ([ title, description, published, published_year, winner_label, winner_filter_label ] + categories + authors.map { |author| author[:name] }).compact.join(" ")

    content_tag(
      :article,
      class: "blog-post-card writeup-post-card ui-hover-lift",
      data: {
        filter_card: "writeups",
        filter_text: filter_text,
        filter_tags: filter_tags.join("|"),
        filter_years: published_year
      }
    ) do
      hitbox_html = link_to("", writeup_path, class: "blog-post-card-hitbox", aria: { label: "Open #{title} writeup" })

      content_tag(:div, class: "blog-post-card-content") do
        logo_html = content_tag(:div, class: "blog-post-card-logo writeup-post-card-logo") do
          if logo.present?
            image_tag(logo, alt: "#{title} Logo", class: "blog-logo")
          else
            get_category_svg(first_category).html_safe
          end
        end

        details_html = content_tag(:div, class: "blog-post-card-details") do
          title_html = content_tag(:h3, title, class: "blog-post-title")

          meta_html = content_tag(:div, class: "blog-post-meta") do
            content_tag(:div, class: "blog-post-meta-row") do
              category_chips = categories.map do |category|
                content_tag(
                  :button,
                  category,
                  type: "button",
                  class: "filter-chip ui-hover-lift",
                  data: { filter_scope: "writeups", filter_tag: category },
                  aria: { pressed: "false", label: "Filter writeups by #{category}" }
                )
              end

              safe_join([ render_writeup_winner_badge(info, context: :card) ] + category_chips)
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

          safe_join([ title_html, meta_html, authors_html, description_html, date_html ].compact)
        end

        logo_html + details_html
      end + hitbox_html
    end
  end

  def render_writeup_winner_badge(info, context: :card)
    winner = writeup_winner(info)
    return nil unless winner

    link_to(
      winner[:proof_url],
      writeup_winner_link_options(winner[:proof_url], context)
    ) do
      safe_join([
        writeup_winner_icon,
        content_tag(:span, winner[:label], class: "writeup-winner-label")
      ])
    end
  end

  private

  def writeup_winner(info)
    WriteupWinner.from_metadata(info)
  end

  def writeup_winner_icon
    content_tag(
      :svg,
      tag.path(
        d: "M12 2.75l2.12 5.78 6.13.23-4.82 3.8 1.68 5.9L12 15.05 6.89 18.46l1.68-5.9-4.82-3.8 6.13-.23L12 2.75z",
        fill: "currentColor"
      ),
      class: "writeup-winner-icon",
      viewBox: "0 0 24 24",
      aria: { hidden: true }
    )
  end

  def writeup_winner_link_options(url, context)
    options = {
      class: "writeup-winner-badge writeup-winner-badge-#{context}",
      target: "_blank",
      rel: "noopener noreferrer",
      aria: { label: "Open contest win proof" }
    }

    return options unless url.to_s.start_with?("/")

    options.merge(rel: "noopener")
  end

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
