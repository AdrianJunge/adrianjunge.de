module ProfileCardsHelper
  def render_profile_card(card)
    render "shared/profile_card", card: card
  end

  def profile_card_optional_link(label, url, class_name: nil, aria_label: nil, title: nil)
    return nil if label.blank?

    text = label
    url = url.to_s
    options = {}
    options[:class] = class_name if class_name.present?
    options[:aria] = { label: aria_label } if aria_label.present?
    options[:title] = title if title.present?

    return content_tag(:span, text, options) if url.blank?

    content_tag(:a, text, options.merge(profile_card_link_options(url)).merge(href: url))
  end

  def profile_card_link_attributes(url, label)
    {
      class: "aboutme-card-link-overlay",
      aria: { label: label }
    }.merge(profile_card_link_options(url))
  end

  def profile_card_tag(label:, url: nil, class_name: nil, datetime: nil, filter_tag: nil)
    return nil if label.blank?

    tag_value = ContentTagTaxonomy.canonical_value(filter_tag.presence || label)
    raw_label = filter_tag.presence || label
    label = ContentTagTaxonomy.canonical_label(label)
    timeline_link = url.blank? && datetime.blank?
    url = timeline_filter_path(tag: tag_value) if timeline_link
    linked = url.present?
    tag_classes = [
      "aboutme-card-tag",
      ("aboutme-tag-#{label.parameterize}" if label.present?),
      (linked ? "aboutme-tag-action" : "aboutme-tag-static"),
      ("aboutme-tag-timeline" if timeline_link),
      *aboutme_tag_style_classes(raw_label, class_name),
      ("ui-hover-lift" if linked)
    ].compact.uniq.join(" ")

    if datetime.present?
      return profile_card_optional_link(label, url, class_name: tag_classes) if linked

      return content_tag(:time, label, datetime: datetime, class: tag_classes)
    end

    linked ? profile_card_optional_link(label, url, class_name: tag_classes) : content_tag(:span, label, class: tag_classes)
  end

  def profile_card_ordered_tags(tags)
    Array(tags).compact.partition { |tag| tag[:url].blank? }.flatten
  end

  def profile_about_card(entry, kind:)
    timeline_items = profile_about_timeline_items(entry["timeline"], kind: kind)
    body_blocks = []
    summary_text = aboutme_sentence(entry["summary"])
    body_blocks << { title: "Summary", text: summary_text } if summary_text.present?

    reference_links = profile_about_reference_links(entry)
    body_blocks << { title: "References", items: reference_links } if reference_links.any?

    collapsible = body_blocks.any? || timeline_items.any?
    primary_url = profile_about_primary_url(entry)

    {
      id: entry["id"],
      class_name: profile_about_card_classes(kind, collapsible),
      main_class: "aboutme-finding-main",
      title_class: "aboutme-finding-project",
      tags_class: "aboutme-finding-badges",
      description_class: "aboutme-finding-summary",
      icon: entry["icon"].presence || profile_about_default_icon(kind),
      title: entry["title"],
      description: entry["subtitle"].presence,
      tags: profile_about_tags(entry, kind: kind),
      body_blocks: body_blocks,
      timeline: timeline_items,
      timeline_title: profile_about_timeline_title(kind),
      children: [],
      collapsible: collapsible,
      card_url: primary_url,
      reading_time: aboutme_reading_time_for_url(primary_url),
      aria_label: "Open #{entry["title"].presence || entry["subtitle"].presence || "item"}"
    }
  end

  private

  def profile_card_link_options(url)
    url.to_s.start_with?("/") ? {} : { target: "_blank", rel: "noopener noreferrer" }
  end

  def profile_about_card_classes(kind, collapsible)
    [
      "aboutme-finding-card",
      "aboutme-about-card",
      "aboutme-about-card-#{kind}",
      ("aboutme-finding-card-#{kind}" if %w[cve bug-bounty].include?(kind.to_s)),
      ("aboutme-achievement-card" unless %w[cve bug-bounty].include?(kind.to_s)),
      ("aboutme-finding-card-static" unless collapsible)
    ].compact.join(" ")
  end

  def profile_about_default_icon(kind)
    case kind.to_s
    when "cve"
      "other/cve.svg"
    when "bug-bounty"
      "other/bug-bounty.svg"
    when "certificate"
      "other/certificate.svg"
    when "talk"
      "other/talk-slides.png"
    when "challenge"
      "ctf/kitctf.png"
    else
      "other/achievement.svg"
    end
  end

  def profile_about_tags(entry, kind:)
    aboutme_extra_tags(entry["tags"]).map do |tag|
      if %w[cve bug-bounty].include?(kind.to_s) && ContentSeverityTag.recognized?(tag[:label])
        tag.merge(filter_tag: ContentTagTaxonomy.canonical_value(tag[:label], type: :severity))
      else
        tag
      end
    end
  end

  def profile_about_reference_links(entry)
    Array(entry["links"]).filter_map do |link|
      next unless link.is_a?(Hash)

      label = link["label"].presence || link[:label].presence
      url = link["url"].presence || link[:url].presence
      next if label.blank? || url.blank?

      profile_card_optional_link(
        label,
        url,
        class_name: "aboutme-reference-link",
        aria_label: "Open #{label}",
        title: "Open #{label}"
      )
    end
  end

  def profile_about_timeline_items(timeline, kind:)
    Array(timeline).filter_map do |event|
      next unless event.is_a?(Hash)

      label = event["title"].presence || event["event"].presence
      next if label.blank?

      {
        "id" => event["id"],
        "date" => event["date"],
        "event" => label,
        "summary" => event["summary"],
        "url" => event["url"].presence,
        "link_style" => ("tag" if kind.to_s == "achievement")
      }.compact
    end
  end

  def profile_about_timeline_title(kind)
    %w[cve bug-bounty].include?(kind.to_s) ? "Disclosure timeline" : "Timeline"
  end

  def profile_about_primary_url(entry)
    entry["url"].presence ||
      profile_about_first_local_url(entry["tags"]) ||
      profile_about_first_local_url(entry["links"])
  end

  def profile_about_first_local_url(items)
    Array(items).filter_map do |item|
      next unless item.respond_to?(:to_h)

      url = item.to_h["url"].presence || item.to_h[:url].presence
      url if url.to_s.start_with?("/")
    end.first
  end
end
