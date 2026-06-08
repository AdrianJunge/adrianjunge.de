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

    link_to(text, url, options.merge(profile_card_link_options(url)))
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
    linked = url.present?
    tag_classes = [
      "aboutme-card-tag",
      (linked ? "aboutme-tag-action" : "aboutme-tag-static"),
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
    description_url = collapsible ? entry["title_url"] : nil
    advisory_link = kind == "cve" && description_url.present?
    body_blocks = []
    body_blocks << { title: "Summary", text: summary_text } if aboutme_visible_detail?(summary_text)

    {
      id: entry["id"],
      class_name: [ "aboutme-finding-card", "aboutme-finding-card-#{kind}", ("aboutme-finding-card-static" unless collapsible) ].compact.join(" "),
      main_class: "aboutme-finding-main",
      title_class: "aboutme-finding-project",
      tags_class: "aboutme-finding-badges",
      description_class: "aboutme-finding-summary",
      title: entry["project"],
      title_url: entry["project_url"],
      title_link: collapsible,
      title_link_class: "aboutme-finding-project-link",
      description: title_label,
      description_url: description_url,
      description_link_class: [ "aboutme-finding-summary-link", ("aboutme-finding-advisory-link" if advisory_link) ].compact.join(" "),
      description_aria_label: ("Open advisory for #{title_label}" if advisory_link),
      description_title: ("Open advisory source" if advisory_link),
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

    {
      id: entry["id"],
      class_name: "aboutme-achievement-card",
      tags_class: "aboutme-achievement-meta",
      title: entry["title"],
      title_link: false,
      description: entry["summary"],
      tags: profile_milestone_tags(entry, events),
      body_blocks: [],
      children: events.map { |event| profile_event_card(entry, event) },
      collapsible: false,
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

  def profile_milestone_tags(entry, events)
    [].tap do |tags|
      if entry["category"].present?
        category_label = ContentTagTaxonomy.canonical_label(entry["category"])
        tags << { label: category_label, url: entry["category_url"], class_name: "aboutme-tag-#{category_label.parameterize}" }
      end
      tags.concat(aboutme_extra_tags(entry["tags"]))
      tags << { label: entry["date"], datetime: entry["date"], class_name: "aboutme-tag-date" } if entry["date"].present? && events.empty?
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
