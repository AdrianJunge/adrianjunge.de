module ProfileCardsHelper
  def render_profile_card(card)
    render "shared/profile_card", card: card
  end

  def profile_card_for_featured_item(item)
    base_card =
      case item[:kind]
      when "cve", "bug-bounty"
        profile_finding_card(item[:entry], kind: item[:kind])
      else
        profile_milestone_card(item[:entry])
      end

    base_card.merge(
      class_name: [ base_card[:class_name], "landing-featured-card" ].compact.join(" "),
      kicker: item[:label]
    )
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

  def profile_card_tag(label:, url: nil, class_name: nil, datetime: nil)
    return nil if label.blank?

    label = ContentTagTaxonomy.canonical_label(label)
    timeline_link = url.blank? && datetime.blank?
    url = timeline_filter_path(tag: label) if timeline_link
    linked = url.present?
    tag_classes = [
      "aboutme-card-tag",
      (linked ? "aboutme-tag-action" : "aboutme-tag-static"),
      ("aboutme-tag-timeline" if timeline_link),
      *aboutme_tag_style_classes(label, class_name),
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

  def profile_finding_card(entry, kind:)
    title_label = entry["title"].presence || entry["short_summary"].presence || entry["summary"].presence
    summary_text = aboutme_finding_summary(entry)
    collapsible = aboutme_finding_collapsible?(entry)
    card_url = entry["card_url"].presence || (collapsible ? nil : entry["title_url"].presence)
    body_blocks = []
    body_blocks << { title: "Summary", text: summary_text } if aboutme_visible_detail?(summary_text)
    reference_links = profile_finding_reference_links(entry, kind: kind)
    body_blocks << { title: "References", items: reference_links } if reference_links.any?

    {
      id: entry["id"],
      class_name: [ "aboutme-finding-card", "aboutme-finding-card-#{kind}", ("aboutme-finding-card-static" unless collapsible) ].compact.join(" "),
      main_class: "aboutme-finding-main",
      title_class: "aboutme-finding-project",
      tags_class: "aboutme-finding-badges",
      description_class: "aboutme-finding-summary",
      title: entry["project"],
      title_url: nil,
      title_link: false,
      title_link_class: nil,
      description: title_label,
      description_url: nil,
      description_link_class: nil,
      description_aria_label: nil,
      description_title: nil,
      tags: profile_finding_tags(entry),
      body_blocks: body_blocks,
      timeline: aboutme_timeline_items(entry["timeline"]),
      collapsible: collapsible,
      card_url: card_url,
      reading_time: aboutme_reading_time_for_url(card_url),
      aria_label: "Open #{entry["project"].presence || title_label}"
    }
  end

  def profile_milestone_card(entry)
    events = aboutme_visible_events(entry["events"])
    card_url = entry["card_url"].presence || entry["title_url"].presence
    summary_text = aboutme_sentence(entry["summary"])
    reference_links = profile_milestone_reference_links(entry, events)
    timeline_items = profile_milestone_timeline_items(events)
    body_blocks = []
    body_blocks << { title: "Summary", text: summary_text } if summary_text.present?
    body_blocks << { title: "References", items: reference_links } if reference_links.any?

    {
      id: entry["id"],
      class_name: "aboutme-finding-card aboutme-finding-card-milestone aboutme-achievement-card",
      main_class: "aboutme-finding-main",
      title_class: "aboutme-finding-project",
      tags_class: "aboutme-finding-badges aboutme-achievement-meta",
      description_class: "aboutme-finding-summary",
      title: entry["title"],
      title_link: false,
      description: nil,
      tags: profile_milestone_tags(entry, events),
      body_blocks: body_blocks,
      timeline: timeline_items,
      timeline_title: "Timeline",
      children: [],
      collapsible: body_blocks.any? || timeline_items.any?,
      card_url: card_url,
      reading_time: aboutme_reading_time_for_url(card_url),
      aria_label: "Open #{entry["title"]}"
    }
  end

  private

  def profile_card_link_options(url)
    url.to_s.start_with?("/") ? {} : { target: "_blank", rel: "noopener noreferrer" }
  end

  def profile_finding_tags(entry)
    [].tap do |tags|
      tags << { label: entry["severity"], class_name: "aboutme-severity severity-badge #{aboutme_severity_class(entry["severity"])}" } if entry["severity"].present?
      tags << { label: entry["cve_id"], url: aboutme_cve_url(entry["cve_id"]), class_name: "aboutme-cve-id" } if entry["cve_id"].present?
      tags << { label: entry["cwe_id"], url: aboutme_cwe_url(entry["cwe_id"]), class_name: "aboutme-cwe-id" } if entry["cwe_id"].present?
    end
  end

  def profile_finding_reference_links(entry, kind:)
    [].tap do |links|
      if kind == "cve" && entry["project_url"].present?
        links << profile_card_optional_link(
          "Repository",
          entry["project_url"],
          class_name: "aboutme-reference-link",
          aria_label: "Open repository for #{entry["project"].presence || entry["title"].presence || "finding"}",
          title: "Open repository"
        )
      end

      next unless kind == "cve" && entry["title_url"].present?

      links << profile_card_optional_link(
        "Advisory source",
        entry["title_url"],
        class_name: "aboutme-reference-link aboutme-finding-advisory-link",
        aria_label: "Open advisory for #{entry["title"].presence || entry["short_summary"].presence || entry["summary"]}",
        title: "Open advisory source"
      )
    end
  end

  def profile_milestone_tags(entry, events)
    [].tap do |tags|
      if entry["category"].present?
        category_label = ContentTagTaxonomy.canonical_label(entry["category"])
        tags << { label: category_label, url: entry["category_url"], class_name: "aboutme-tag-#{category_label.parameterize}" }
      end
      tags.concat(aboutme_extra_tags(entry["tags"]))
      tags.concat(profile_milestone_action_tags(entry, events))
      tags << { label: entry["date"], datetime: entry["date"], class_name: "aboutme-tag-date" } if entry["date"].present? && events.empty?
    end
  end

  def profile_milestone_reference_links(entry, events)
    seen_urls = []

    profile_milestone_link_entries(entry).filter_map do |link|
      url = link[:url]
      next if seen_urls.include?(url) || profile_milestone_link_has_tag?(entry, events, link)

      seen_urls << url
      profile_card_optional_link(
        link[:label],
        url,
        class_name: "aboutme-reference-link",
        aria_label: "Open #{link[:label]}",
        title: "Open #{link[:label]}"
      )
    end
  end

  def profile_milestone_link_entries(entry)
    link_entries = Array(entry["links"]).filter_map do |link|
      next unless link.is_a?(Hash)

      label = link["label"].presence || link[:label].presence
      url = link["url"].presence || link[:url].presence
      next if label.blank? || url.blank?

      { label: label, url: url }
    end

    primary_url = entry["card_url"].presence || entry["title_url"].presence
    if primary_url.present? && link_entries.none? { |link| link[:url] == primary_url }
      link_entries.unshift({ label: "Overview", url: primary_url })
    end

    link_entries
  end

  def profile_milestone_action_tags(entry, events)
    seen_urls = [ entry["category_url"].presence ].compact

    profile_milestone_link_entries(entry).filter_map do |link|
      next unless profile_milestone_link_has_tag?(entry, events, link)

      url = link[:url]
      next if seen_urls.include?(url)

      seen_urls << url
      {
        label: profile_milestone_action_tag_label(entry, events, link),
        url: url,
        class_name: "aboutme-milestone-action-tag #{profile_milestone_action_tag_class(entry, events, link)}"
      }
    end
  end

  def profile_milestone_link_has_tag?(entry, events, link)
    url = link[:url]
    return true if url.present? && url == entry["category_url"].presence

    profile_milestone_action_tag_label(entry, events, link).present?
  end

  def profile_milestone_action_tag_label(entry, events, link)
    url = link[:url]
    return nil if url.blank? || url == entry["category_url"].presence

    return link[:label] if profile_milestone_achievement_entry?(entry, events)

    primary_url = entry["card_url"].presence || entry["title_url"].presence
    if primary_url.present? && url == primary_url
      return url.start_with?("/") ? "Writeup" : "Overview"
    end

    nil
  end

  def profile_milestone_action_tag_class(entry, events, link)
    return "aboutme-tag-writeup" if link[:url].to_s.start_with?("/")
    return "aboutme-tag-event" if profile_milestone_achievement_entry?(entry, events)

    "aboutme-tag-overview"
  end

  def profile_milestone_achievement_entry?(entry, events)
    events.any? && entry["card_url"].blank?
  end

  def profile_milestone_timeline_items(events)
    events.map do |event|
      {
        "date" => event["date"],
        "event" => event["title"],
        "summary" => event["summary"],
        "url" => event["url"].presence || event["card_url"].presence,
        "link_style" => "tag"
      }.compact
    end
  end

  def profile_event_card(entry, event)
    event_id = event["id"].presence || [ entry["id"].presence || entry["title"], event["date"], event["title"] ].compact.join("-").parameterize
    card_url = event["card_url"].presence || event["url"].presence || entry["card_url"].presence || entry["title_url"].presence

    {
      id: event_id,
      class_name: "aboutme-achievement-event",
      title: event["title"],
      description: event["summary"],
      tags: profile_event_tags(event),
      body_blocks: [],
      collapsible: false,
      card_url: card_url,
      reading_time: aboutme_reading_time_for_url(card_url),
      aria_label: "Open #{event["title"].presence || entry["title"]}"
    }
  end

  def profile_event_tags(event)
    return [] if event["date"].blank?

    [ { label: event["date"], datetime: event["date"], class_name: "aboutme-tag-date" } ]
  end
end
