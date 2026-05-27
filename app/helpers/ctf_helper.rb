module CtfHelper
  CATEGORY_ICON_ASSET_ROOT = Rails.root.join("app", "assets", "ctf")
  CATEGORY_ICON_DIRECTORY = Rails.root.join("app", "assets", "ctf", "categories")
  DEFAULT_CATEGORY_ICON = "default.svg"

  def get_category_svg(category)
    icon_path = category_icon_path(category)
    inline_svg = inline_category_svg(icon_path)

    return inline_svg if inline_svg.present?

    image_tag(category_icon_asset_name(icon_path), alt: "#{category} category", class: "blog-logo")
  end

  def render_writeup_card(writeup, writeup_path, info, logo: nil, interactive_tags: true)
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

    tags = categories.map { |category| { label: category } }
    tags.unshift({ label: winner[:label], url: winner[:proof_url], winner: true, context: :card }) if winner
    media_html = logo.present? ? nil : get_category_svg(first_category).html_safe

    render_content_card(
      url: writeup_path,
      class_name: "blog-post-card writeup-post-card",
      hitbox_class: "blog-post-card-hitbox",
      content_class: "blog-post-card-content",
      media_html: media_html,
      media: {
        image: logo,
        alt: "#{title} Logo",
        image_class: "blog-logo",
        wrapper_class: "blog-post-card-logo writeup-post-card-logo"
      },
      body_class: "blog-post-card-details",
      title: title,
      title_class: "blog-post-title",
      description: content_truncate(description),
      description_class: "blog-post-description",
      description_tag: :p,
      date: published,
      date_class: "blog-post-date",
      date_text_class: "blog-post-date-text",
      reading_time: info["reading_time_label"],
      reading_time_class: "blog-post-reading-time",
      tags_outer_class: "blog-post-meta",
      tags_class: "blog-post-meta-row",
      tags: tags,
      filter_scope: "writeups",
      interactive_tags: interactive_tags,
      authors: authors,
      authors_label: "Challenge by",
      authors_class: "blog-post-authors",
      data: {
        filter_card: "writeups",
        filter_text: filter_text,
        filter_tags: filter_tags.join("|"),
        filter_years: published_year
      },
      aria_label: "Open #{title} writeup"
    )
  end

  def render_writeup_winner_badge(info, context: :card)
    winner = writeup_winner(info)
    return nil unless winner

    content_winner_badge(label: winner[:label], url: winner[:proof_url], context: context)
  end

  private

  def category_icon_path(category)
    category_name = category.to_s.downcase
    CATEGORY_ICON_DIRECTORY.children
                           .select { |path| path.file? && path.basename(".*").to_s == category_name }
                           .sort_by { |path| path.basename.to_s }
                           .first ||
      CATEGORY_ICON_DIRECTORY.join(DEFAULT_CATEGORY_ICON)
  end

  def inline_category_svg(icon_path)
    return nil unless icon_path.extname.downcase == ".svg"

    svg = File.read(icon_path, mode: "r:UTF-8")
    return nil unless svg.valid_encoding? && svg.include?("<svg")

    svg.sub("<svg", '<svg style="width: 6vh; height: 6vh;" ')
  end

  def category_icon_asset_name(icon_path)
    icon_path.relative_path_from(CATEGORY_ICON_ASSET_ROOT).to_s
  end

  def writeup_winner(info)
    WriteupWinner.from_metadata(info)
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
end
