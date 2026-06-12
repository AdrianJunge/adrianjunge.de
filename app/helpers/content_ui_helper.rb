module ContentUiHelper
  DEFAULT_CARD_DESCRIPTION_LIMIT = 200

  def render_content_card(card)
    render "shared/content_card", card: card
  end

  def content_tag_badge(label, classes:, title: nil, url: nil, filter_scope: nil, filter_tag: label, aria_label: nil, static_class: nil, label_class: nil, arrow: nil, link_target: "_blank", timeline_redirect: true)
    label = ContentTagTaxonomy.canonical_label(label)
    filter_tag = ContentTagTaxonomy.canonical_label(filter_tag.presence || label)
    timeline_link = url.blank? && filter_scope.blank? && timeline_redirect && filter_tag.present?
    url = timeline_filter_path(tag: filter_tag) if timeline_link
    action = url.present? || filter_scope.present?
    classes = [ "content-tag", *Array(classes) ]
    classes << (url.present? ? "content-tag-link" : nil)
    classes << (filter_scope.present? ? "content-tag-filter" : nil)
    classes << (timeline_link ? "content-tag-timeline-link" : nil)
    classes << (action ? "content-tag-action" : "content-tag-static")
    classes << static_class if !action && static_class.present?
    content = content_tag_badge_content(label, label_class: label_class, arrow: arrow.nil? ? (url.present? && !timeline_link) : arrow)

    if url.present?
      link_options = content_link_options(url)
      link_options[:target] = link_target if link_target.present?
      link_options[:rel] ||= "noopener"

      return content_tag(
        :a,
        content,
        link_options.merge(
          href: url,
          class: classes.compact.join(" "),
          aria: { label: aria_label.presence || (timeline_link ? "Filter timeline by #{filter_tag}" : nil) },
          title: title
        )
      )
    end

    if filter_scope.present?
      return content_tag(
        :button,
        content,
        type: "button",
        class: classes.compact.join(" "),
        data: { filter_scope: filter_scope, filter_tag: filter_tag },
        aria: { pressed: "false", label: aria_label.presence || "Filter by #{filter_tag}" },
        title: title
      )
    end

    content_tag(:span, content, class: classes.compact.join(" "), title: title)
  end

  def content_filter_chip(label, scope:, tag_value: label, interactive: true, class_name: nil, winner: false, authored: false, difficulty_key: nil, category_key: nil, severity_key: nil, cve: false, cwe: false, static_class: "blog-post-static-chip", title: nil, timeline_redirect: true)
    raw_label = label.to_s
    style = content_tag_style(
      raw_label,
      winner: winner,
      authored: authored,
      difficulty_key: difficulty_key,
      category_key: category_key,
      severity_key: severity_key,
      cve: cve,
      cwe: cwe
    )
    label = style[:label]
    tag_value = ContentTagTaxonomy.canonical_label(tag_value.presence || raw_label)
    classes = [ "filter-chip", class_name, *style[:classes] ]

    interactive = false if scope.blank?

    content_tag_badge(
      label,
      classes: classes,
      filter_scope: interactive ? scope : nil,
      filter_tag: tag_value,
      static_class: static_class,
      title: title,
      label_class: style[:label_class],
      link_target: nil,
      timeline_redirect: timeline_redirect
    )
  end

  def content_winner_badge(label:, url:, context: :card, aria_label: "Open contest win proof")
    return nil if label.blank? || url.blank?

    content_tag_badge(
      label,
      classes: [ "writeup-winner-badge", "writeup-winner-badge-#{context}" ],
      url: url,
      aria_label: aria_label,
      label_class: "writeup-winner-label"
    )
  end

  def content_authored_badge(label:, url:, context: :card, aria_label: "Open CTF competition")
    return nil if label.blank? || url.blank?

    content_tag_badge(
      label,
      classes: [ "authored-challenge-badge", "authored-challenge-badge-#{context}" ],
      url: url,
      aria_label: aria_label,
      label_class: "authored-challenge-label"
    )
  end

  def content_difficulty_badge(label:, key:, context: :card, title: nil)
    label = label.to_s.presence || WriteupDifficulty::UNKNOWN_LABEL
    key = WriteupDifficulty.css_key(key)
    classes = [ "difficulty-badge", "difficulty-badge-#{key}", "difficulty-badge-#{context}" ]

    content_tag_badge(
      label,
      classes: classes,
      title: title.presence || "Challenge difficulty: #{label}"
    )
  end

  def content_category_badge(label:, context: :card, title: nil)
    label = ContentTagTaxonomy.canonical_label(label)
    key = ContentCategoryTag.css_key(label)
    classes = [ "category-badge", "category-badge-#{key}", "category-badge-#{context}" ]

    content_tag_badge(
      label,
      classes: classes,
      title: title.presence || "Challenge category: #{label}"
    )
  end

  def content_author_node(author)
    author = author.symbolize_keys if author.respond_to?(:symbolize_keys)
    name = author[:name].to_s
    url = author[:url].to_s

    return content_tag(:span, name, class: "blog-post-author-name") if url.blank?

    link_to(name, url, content_link_options(url).merge(class: "blog-post-author-link"))
  end

  def content_card_tag(tag_config, default_scope:, default_interactive:)
    config = tag_config.respond_to?(:to_h) ? tag_config.to_h.symbolize_keys : { label: tag_config }
    return config[:html] if config[:html].present?

    if config[:winner] && config[:url].present?
      return content_winner_badge(
        label: config[:label],
        url: config[:url],
        context: config[:context].presence || :card,
        aria_label: config[:aria_label].presence || "Open contest win proof"
      )
    end

    if config[:authored] && config[:url].present?
      return content_authored_badge(
        label: config[:label],
        url: config[:url],
        context: config[:context].presence || :card,
        aria_label: config[:aria_label].presence || "Open CTF competition"
      )
    end

    if config[:difficulty]
      scope = config.fetch(:scope, default_scope)
      interactive = config.key?(:interactive) ? config[:interactive] : default_interactive

      if interactive && scope.present?
        return content_filter_chip(
          config[:label],
          scope: scope,
          tag_value: config[:tag_value].presence || config[:label],
          interactive: true,
          class_name: config[:class_name],
          difficulty_key: config[:difficulty_key].presence || config[:label],
          title: config[:title]
        )
      end

      return content_difficulty_badge(
        label: config[:label],
        key: config[:difficulty_key],
        context: config[:context].presence || :card,
        title: config[:title]
      )
    end

    auto_cve = !config[:category] && !config[:severity] && ContentVulnerabilityTag.cve?(config[:label])
    auto_cwe = !config[:category] && !config[:severity] && ContentVulnerabilityTag.cwe?(config[:label])
    auto_category = !config[:category] && !config[:severity] && !auto_cve && !auto_cwe && ContentCategoryTag.recognized?(config[:label])
    auto_severity = !config[:category] && !config[:severity] && !auto_cve && !auto_cwe && !WriteupDifficulty.filter_label?(config[:label]) && ContentSeverityTag.recognized?(config[:label])

    content_filter_chip(
      config[:label],
      scope: config.fetch(:scope, default_scope),
      tag_value: config[:tag_value].presence || config[:label],
      interactive: config.key?(:interactive) ? config[:interactive] : default_interactive,
      class_name: config[:class_name],
      winner: config[:winner],
      authored: config[:authored],
      difficulty_key: config[:difficulty_filter] ? config[:difficulty_key] || config[:label] : nil,
      category_key: (config[:category] || auto_category) ? config[:category_key] || config[:label] : nil,
      severity_key: (config[:severity] || auto_severity) ? config[:severity_key] || config[:label] : nil,
      cve: config[:cve] || auto_cve,
      cwe: config[:cwe] || auto_cwe,
      static_class: config[:static_class].presence || "blog-post-static-chip",
      title: config[:title],
      timeline_redirect: config.key?(:timeline_redirect) ? config[:timeline_redirect] : true
    )
  end

  def content_card_link_attributes(url, label, class_name:)
    {
      class: class_name,
      aria: { label: label }
    }.merge(content_link_options(url))
  end

  def content_truncate(text, length: DEFAULT_CARD_DESCRIPTION_LIMIT)
    text = text.to_s
    text.length > length ? "#{text[0, length]}..." : text
  end

  def content_link_options(url)
    return { rel: "noopener" } if url.to_s.start_with?("/")
    return { target: "_blank", rel: "noopener noreferrer" } if url.to_s.match?(%r{\Ahttps?://}i)

    {}
  end

  def content_tag_style(label, winner: false, authored: false, difficulty_key: nil, category_key: nil, severity_key: nil, cve: false, cwe: false)
    label = ContentTagTaxonomy.canonical_label(label)
    classes = []
    label_class = nil
    difficulty_key = WriteupDifficulty.css_key(difficulty_key) if difficulty_key.present?
    category_key = ContentCategoryTag.css_key(category_key) if category_key.present?
    severity_key = ContentSeverityTag.css_key(severity_key) if severity_key.present?
    cve = cve || ContentVulnerabilityTag.cve?(label)
    cwe = cwe || ContentVulnerabilityTag.cwe?(label)

    if winner
      classes.push("writeup-winner-badge", "writeup-winner-badge-filter")
      label_class = "writeup-winner-label"
    elsif authored
      classes.push("authored-challenge-badge", "authored-challenge-badge-filter")
      label_class = "authored-challenge-label"
    elsif difficulty_key.present?
      classes.push("difficulty-badge", "difficulty-badge-#{difficulty_key}", "difficulty-badge-filter")
    elsif category_key.present?
      classes.push("category-badge", "category-badge-#{category_key}", "category-badge-filter")
    elsif severity_key.present?
      classes.push("severity-badge", "severity-badge-#{severity_key}", "aboutme-severity-#{severity_key}", "severity-badge-filter")
    elsif cve
      classes.push("cve-badge", "cve-badge-filter")
    elsif cwe
      classes.push("cwe-badge", "cwe-badge-filter")
    end

    { label: label, classes: classes, label_class: label_class }
  end

  def content_tag_badge_content(label, label_class:, arrow:)
    label_node = content_tag(:span, label, class: [ "content-tag-label", label_class ].compact.join(" "))
    nodes = [ label_node ]
    nodes << content_tag(:span, ">", class: "content-tag-arrow", aria: { hidden: "true" }) if arrow

    safe_join(nodes)
  end
end
