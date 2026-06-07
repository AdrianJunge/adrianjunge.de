module ContentUiHelper
  DEFAULT_CARD_DESCRIPTION_LIMIT = 200

  def render_content_card(card)
    render "shared/content_card", card: card
  end

  def content_filter_chip(label, scope:, tag_value: label, interactive: true, class_name: nil, winner: false, authored: false, static_class: "blog-post-static-chip", title: nil)
    label = label.to_s
    classes = [ "filter-chip", class_name ]

    if winner
      classes << "writeup-winner-badge"
      classes << "writeup-winner-badge-filter"
    elsif authored
      classes << "authored-challenge-badge"
      classes << "authored-challenge-badge-filter"
    end

    interactive = false if scope.blank?
    content =
      if winner
        safe_join([ content_winner_icon, content_tag(:span, label, class: "writeup-winner-label") ])
      elsif authored
        safe_join([ content_authored_icon, content_tag(:span, label, class: "authored-challenge-label") ])
      else
        label
      end

    unless interactive
      classes << static_class
      return content_tag(:span, content, class: classes.compact.join(" "), title: title)
    end

    classes << "ui-hover-lift" unless winner || authored
    content_tag(
      :button,
      content,
      type: "button",
      class: classes.compact.join(" "),
      data: { filter_scope: scope, filter_tag: tag_value },
      aria: { pressed: "false", label: "Filter by #{tag_value}" },
      title: title
    )
  end

  def content_winner_badge(label:, url:, context: :card, aria_label: "Open contest win proof")
    return nil if label.blank? || url.blank?

    link_options = content_link_options(url).merge(target: "_blank")
    link_options[:rel] ||= "noopener"

    link_to(url, link_options.merge(class: "writeup-winner-badge writeup-winner-badge-#{context}", aria: { label: aria_label })) do
      safe_join([
        content_winner_icon,
        content_tag(:span, label, class: "writeup-winner-label")
      ])
    end
  end

  def content_authored_badge(label:, url:, context: :card, aria_label: "Open CTF competition")
    return nil if label.blank? || url.blank?

    link_options = content_link_options(url).merge(target: "_blank")
    link_options[:rel] ||= "noopener"

    link_to(url, link_options.merge(class: "authored-challenge-badge authored-challenge-badge-#{context}", aria: { label: aria_label })) do
      safe_join([
        content_authored_icon,
        content_tag(:span, label, class: "authored-challenge-label")
      ])
    end
  end

  def content_winner_icon
    content_tag(:span, "🏆", class: "writeup-winner-icon", aria: { hidden: true })
  end

  def content_authored_icon
    content_tag(:span, "✒️", class: "authored-challenge-icon", aria: { hidden: true })
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

    content_filter_chip(
      config[:label],
      scope: config.fetch(:scope, default_scope),
      tag_value: config[:tag_value].presence || config[:label],
      interactive: config.key?(:interactive) ? config[:interactive] : default_interactive,
      class_name: config[:class_name],
      winner: config[:winner],
      authored: config[:authored],
      static_class: config[:static_class].presence || "blog-post-static-chip",
      title: config[:title]
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
end
