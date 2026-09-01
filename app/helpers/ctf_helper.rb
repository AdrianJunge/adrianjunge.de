module CtfHelper
  CATEGORY_ICON_ASSET_ROOT = Rails.root.join("app", "assets", "images")
  CATEGORY_ICON_DIRECTORY = CATEGORY_ICON_ASSET_ROOT.join("ctf", "categories")
  DEFAULT_CATEGORY_ICON = "default.svg"

  def get_category_svg(category)
    icon_path = category_icon_path(category)
    inline_svg = inline_category_svg(icon_path)

    return inline_svg if inline_svg.present?

    image_tag(category_icon_asset_name(icon_path), alt: "#{category} category", class: "blog-logo")
  end

  def get_category_icon(categories)
    icon_categories = distinct_categories(categories)
    return get_category_svg(icon_categories.first) if icon_categories.length == 1

    slices = icon_categories.each_with_index.map { |category, index| category_icon_slice(category, index, icon_categories.length) }
    dividers = icon_categories.each_index.map { |index| category_icon_divider(index, icon_categories.length) }

    content_tag(
      :span,
      safe_join(slices + dividers),
      class: "category-split-icon blog-logo",
      role: "img",
      aria: { label: "#{icon_categories.to_sentence} categories" },
      data: { category_count: icon_categories.length }
    )
  end

  def render_writeup_card(writeup, writeup_path, info, logo: nil, interactive_tags: true, show_hints: true, external_recognition_links: true, show_section_icon: false)
    categories = normalized_categories(info["categories"]).presence || [ "Unknown category" ]
    title = info["title"].presence || writeup.capitalize
    description = info["description"] || "No description available"
    published = info["published"] || "Unknown date"
    authors = writeup_authors(info)
    published_year = writeup_year(info)
    winner = writeup_winner(info)
    authored_challenge = authored_challenge(info)
    difficulty = writeup_difficulty(info)
    hints = writeup_hints(info)
    difficulty_label = difficulty[:label]
    winner_label = winner&.fetch(:label, nil)
    winner_filter_label = winner ? WriteupWinner::FILTER_LABEL : nil
    authored_filter_label = authored_challenge ? AuthoredChallenge::FILTER_LABEL : nil
    solve_count_label = writeup_solve_count_label(info)
    points_label = writeup_points_label(info)
    challenge_stats_label = writeup_challenge_stats_label(info)
    filter_tags = ([ winner_filter_label, authored_filter_label, difficulty_label ] + categories).compact
    filter_text = ([ title, description, published, published_year, solve_count_label, points_label, challenge_stats_label, difficulty_label, winner_label, winner_filter_label, authored_filter_label ] + categories + authors.map { |author| author[:name] }).compact.join(" ")

    tags = []
    if winner
      tags << {
        label: winner[:label],
        tag_value: WriteupWinner::FILTER_LABEL,
        winner: true,
        url: !interactive_tags && external_recognition_links ? winner[:proof_url] : nil,
        class_name: "writeup-winner-badge-card"
      }
    end
    if authored_challenge
      tags << {
        label: authored_challenge[:label],
        tag_value: AuthoredChallenge::FILTER_LABEL,
        authored: true,
        url: !interactive_tags && external_recognition_links ? authored_challenge[:event_url] : nil,
        class_name: "authored-challenge-badge-card"
      }
    end
    tags << {
      label: difficulty_label,
      difficulty: true,
      difficulty_key: difficulty[:key],
      title: "Challenge difficulty: #{difficulty_label}"
    }
    tags.concat(categories.map { |category| category_tag_config(category) })
    if show_hints && hints.any?
      tags << {
        label: "💡 #{pluralize(hints.length, "hint")}",
        interactive: false,
        class_name: "writeup-hints-chip",
        title: pluralize(hints.length, "writeup hint"),
        timeline_redirect: false
      }
    end
    media_html = logo.present? ? nil : get_category_icon(categories).html_safe

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
      description: description,
      description_class: "blog-post-description",
      description_tag: :p,
      date: published,
      date_class: "blog-post-date",
      date_text_class: "blog-post-date-text",
      reading_time: info["reading_time_label"],
      reading_time_class: "blog-post-reading-time",
      meta_items: [
        { label: challenge_stats_label, class_name: "blog-post-challenge-stats" }
      ],
      meta_item_class: "blog-post-reading-time",
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
      section_link: show_section_icon ? {
        url: ctf_path,
        icon: "task-bar/flag.svg",
        kind: "ctf",
        label: "Browse CTF writeups"
      } : nil,
      aria_label: "Open #{title} writeup"
    )
  end

  def render_writeup_winner_badge(info, context: :card)
    winner = writeup_winner(info)
    return nil unless winner

    content_winner_badge(label: winner[:label], url: winner[:proof_url], context: context)
  end

  def render_writeup_difficulty_badge(info, context: :card)
    difficulty = writeup_difficulty(info)

    content_difficulty_badge(
      label: difficulty[:label],
      key: difficulty[:key],
      context: context
    )
  end

  def render_writeup_authored_badge(info, context: :card)
    authored = authored_challenge(info)
    return nil unless authored && authored[:event_url].present?

    content_authored_badge(
      label: authored[:label],
      url: authored[:event_url],
      context: context,
      aria_label: "Open #{authored[:event].presence || "CTF competition"}"
    )
  end

  def render_writeup_category_badges(info, context: :card)
    normalized_categories(info["categories"]).filter_map do |category|
      next if category.to_s.blank?

      content_category_badge(
        label: category,
        context: context,
        title: "Challenge category: #{category}"
      )
    end
  end

  def writeup_solve_count_label(info)
    count = writeup_solve_count(info)
    return nil unless count

    "#{count} #{count == 1 ? "solve" : "solves"}"
  end

  def writeup_challenge_stats_label(info)
    [ writeup_solve_count_label(info), writeup_points_label(info) ].compact.join(" / ").presence
  end

  def writeup_points_label(info)
    points = writeup_points(info)
    return nil unless points

    "#{points} #{points == 1 ? "point" : "points"}"
  end

  def writeup_event_url(info, fallback: nil)
    writeup_metadata_event_url(info).presence ||
      authored_challenge(info)&.fetch(:event_url, nil).presence ||
      fallback.presence
  end

  def render_writeup_hints(info)
    hints = writeup_hints(info)
    return nil if hints.empty?

    content_tag(:section, class: "writeup-hints writeup-hints-spoilers", aria: { label: "Hints" }) do
      safe_join([
        content_tag(:div, class: "writeup-hints-summary") do
          content_tag(:span, class: "writeup-hints-summary-content") do
            safe_join([
              content_tag(:span, "Hints", class: "writeup-hints-title"),
              content_tag(:span, pluralize(hints.length, "hint"), class: "writeup-hints-count")
            ])
          end
        end,
        content_tag(:ol, class: "writeup-hints-list") do
          safe_join(hints.each_with_index.map do |hint, index|
            content_tag(:li, class: "writeup-hint-spoiler is-hidden", data: { hint_spoiler: true }) do
              safe_join([
                content_tag(:div, render_markdown(hint), class: "writeup-hint-content writeup-hint-spoiler-content", aria: { hidden: "true" }),
                content_tag(
                  :button,
                  "Expose",
                  type: "button",
                  class: "writeup-hint-unhide",
                  data: { hint_spoiler_reveal: true },
                  aria: { expanded: "false", label: "Expose hint #{index + 1}" }
                )
              ])
            end
          end)
        end
      ])
    end
  end

  private

  def category_icon_path(category)
    category_name = ContentCategoryTag.normalized(category)
    icon_names = [ category_name, ContentCategoryTag.css_key(category) ].reject(&:blank?).uniq

    category_icon_directory.children
                           .select { |path| path.file? && icon_names.include?(category_icon_file_key(path)) }
                           .sort_by do |path|
                             file_key = category_icon_file_key(path)
                             [ icon_names.index(file_key) || icon_names.length, path.basename.to_s ]
                           end
                           .first ||
      category_icon_directory.join(DEFAULT_CATEGORY_ICON)
  end

  def category_icon_file_key(path)
    path.basename(".*").to_s.downcase
  end

  def distinct_categories(categories)
    normalized_categories(categories)
      .presence || [ "Unknown category" ]
  end

  def category_icon_slice(category, index, count)
    image = image_tag(
      category_icon_asset_name(category_icon_path(category)),
      alt: "",
      class: "category-split-icon-image"
    )

    content_tag(
      :span,
      image,
      class: "category-split-icon-slice",
      style: "--category-index: #{index}; --category-count: #{count}; --category-clip: #{category_icon_clip_path(index, count)};",
      data: { category: ContentCategoryTag.css_key(category) },
      aria: { hidden: true }
    )
  end

  def category_icon_divider(index, count)
    start_angle = category_icon_slice_angles(index, count).first
    content_tag(
      :span,
      "",
      class: "category-split-icon-divider",
      style: "--category-divider-angle: #{category_icon_css_number(start_angle - 90)}deg;",
      data: { boundary: index },
      aria: { hidden: true }
    )
  end

  def category_icon_clip_path(index, count)
    start_angle, end_angle = category_icon_slice_angles(index, count)
    arc_steps = [ ((end_angle - start_angle).abs / 8.0).ceil, 2 ].max
    points = [ "50% 50%" ]

    (0..arc_steps).each do |step|
      angle = start_angle + ((end_angle - start_angle) * step / arc_steps)
      radians = angle * Math::PI / 180.0
      x = 50.0 + (50.0 * Math.cos(radians))
      y = 50.0 + (50.0 * Math.sin(radians))
      points << "#{category_icon_css_number(x)}% #{category_icon_css_number(y)}%"
    end

    "polygon(#{points.join(", ")})"
  end

  def category_icon_slice_angles(index, count)
    slice_angle = 360.0 / count
    start_angle = -90.0 - (slice_angle / 2.0) + (index * slice_angle)

    [ start_angle, start_angle + slice_angle ]
  end

  def category_icon_css_number(value)
    format("%.3f", value).sub(/\.?0+\z/, "")
  end

  def inline_category_svg(icon_path)
    return nil unless icon_path.extname.downcase == ".svg"

    svg = File.read(icon_path, mode: "r:UTF-8")
    return nil unless svg.valid_encoding? && svg.include?("<svg")

    svg.sub("<svg", '<svg style="width: 6vh; height: 6vh;" ')
  end

  def category_icon_asset_name(icon_path)
    icon_path.relative_path_from(category_icon_asset_root).to_s
  end

  def category_icon_directory
    CATEGORY_ICON_DIRECTORY
  end

  def category_icon_asset_root
    CATEGORY_ICON_ASSET_ROOT
  end

  def writeup_winner(info)
    WriteupWinner.from_metadata(info)
  end

  def authored_challenge(info)
    AuthoredChallenge.from_metadata(info).tap do |authored|
      next unless authored && authored[:event_url].blank?

      authored[:event_url] = writeup_metadata_event_url(info).presence || info["ctf_event_url"].presence
    end
  end

  def writeup_metadata_event_url(info)
    AuthoredChallenge.metadata_value(info, "event_url", "event-url", "event_link", "event-link")
  end

  def writeup_difficulty(info)
    WriteupDifficulty.from_metadata(info)
  end

  def writeup_hints(info)
    raw_hints = AuthoredChallenge.metadata_value(info, "hints", "hint")
    hint_entries = raw_hints.is_a?(Array) ? raw_hints : [ raw_hints ]

    hint_entries.filter_map do |hint|
      hint = AuthoredChallenge.raw_value(hint, "text", "hint", "value") if hint.is_a?(Hash)
      hint.to_s.strip.presence
    end
  end

  def writeup_solve_count(info)
    raw = AuthoredChallenge.metadata_value(info, "solves", "solve_count", "solves_count", "solve-count", "solves-count")
    normalized = raw.to_s.strip
    return nil unless normalized.match?(/\A\d+\z/)

    count = normalized.to_i
    count >= 0 ? count : nil
  end

  def writeup_points(info)
    raw = AuthoredChallenge.metadata_value(info, "points", "point_count", "points_count", "challenge_points", "score")
    normalized = raw.to_s.strip
    return nil unless normalized.match?(/\A\d+\z/)

    points = normalized.to_i
    points.positive? ? points : nil
  end

  def category_tag_config(category)
    label = ContentTagTaxonomy.canonical_label(category)

    {
      label: label,
      category: true,
      category_key: label,
      title: "Challenge category: #{label}"
    }
  end

  def normalized_categories(categories)
    ContentTagTaxonomy.canonical_values(Array(categories))
  end

  def writeup_year(info)
    return Time.parse(info["published"].to_s).year if info["published"].present?

    info["year"].presence
  rescue StandardError
    info["year"].presence
  end

  def writeup_ctf_year(info)
    year = info["ctf_year"].presence ||
           info["event_year"].presence ||
           info["year"].presence

    year.to_s[/\d{4}/] || writeup_year(info)
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
