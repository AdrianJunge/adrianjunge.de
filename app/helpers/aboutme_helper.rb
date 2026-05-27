module AboutmeHelper
  CVE_ID_PATTERN = /\ACVE-\d{4}-\d{4,}\z/i
  CWE_ID_PATTERN = /\ACWE-(\d+)\z/i

  def aboutme_severity_class(severity)
    case severity.to_s.downcase
    when "critical"
      "aboutme-severity-critical"
    when "high"
      "aboutme-severity-high"
    when "medium", "moderate"
      "aboutme-severity-medium"
    when "low"
      "aboutme-severity-low"
    when "tba"
      "aboutme-severity-tba"
    else
      "aboutme-severity-info"
    end
  end

  def aboutme_optional_link(label, url, class_name: nil)
    return nil if label.blank?

    text = label
    url = url.to_s
    options = {}
    options[:class] = class_name if class_name.present?

    return content_tag(:span, text, options) if url.blank?

    link_to(text, url, options.merge(aboutme_link_options(url)))
  end

  def aboutme_finding_collapsible?(entry)
    aboutme_visible_detail?(entry["summary"]) || aboutme_timeline_items(entry["timeline"]).any?
  end

  def aboutme_finding_summary(entry)
    aboutme_sentence(entry["summary"])
  end

  def aboutme_visible_detail?(value)
    value.present? && value.to_s.strip.casecmp("tba") != 0
  end

  def aboutme_cve_url(cve_id)
    id = cve_id.to_s.strip.upcase
    return nil unless id.match?(CVE_ID_PATTERN)

    "https://www.cve.org/CVERecord?id=#{id}"
  end

  def aboutme_cwe_url(cwe_id)
    match = cwe_id.to_s.strip.upcase.match(CWE_ID_PATTERN)
    return nil unless match

    "https://cwe.mitre.org/data/definitions/#{match[1]}.html"
  end

  def aboutme_timeline_items(timeline)
    Array(timeline).select do |item|
      item.is_a?(Hash) && item["event"].present?
    end
  end

  def aboutme_visible_events(events)
    Array(events).select do |event|
      event.is_a?(Hash) && %w[title date summary card_url url].any? { |field| event[field].present? }
    end
  end

  def aboutme_card_link_attributes(url, label)
    {
      class: "aboutme-card-link-overlay",
      aria: { label: label }
    }.merge(aboutme_link_options(url))
  end

  def aboutme_tag(label:, url: nil, class_name: nil, datetime: nil)
    return nil if label.blank?

    tag_classes = [ "aboutme-card-tag", class_name ].compact.join(" ")
    if datetime.present?
      return aboutme_optional_link(label, url, class_name: tag_classes) if url.present?

      return content_tag(:time, label, datetime: datetime, class: tag_classes)
    end

    url.present? ? aboutme_optional_link(label, url, class_name: tag_classes) : content_tag(:span, label, class: tag_classes)
  end

  def aboutme_finding_card(entry, kind:)
    title_label = entry["title"].presence || entry["short_summary"].presence || entry["summary"].presence
    summary_text = aboutme_finding_summary(entry)
    collapsible = aboutme_finding_collapsible?(entry)
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
      description_url: collapsible ? entry["title_url"] : nil,
      description_link_class: "aboutme-finding-summary-link",
      tags: aboutme_finding_tags(entry),
      body_blocks: body_blocks,
      timeline: aboutme_timeline_items(entry["timeline"]),
      collapsible: collapsible,
      card_url: entry["card_url"].presence || (collapsible ? nil : entry["title_url"].presence),
      aria_label: "Open #{entry["project"].presence || title_label}"
    }
  end

  def aboutme_milestone_card(entry)
    events = aboutme_visible_events(entry["events"])

    {
      id: entry["id"],
      class_name: "aboutme-achievement-card",
      tags_class: "aboutme-achievement-meta",
      title: entry["title"],
      title_link: false,
      description: entry["summary"],
      tags: aboutme_milestone_tags(entry, events),
      body_blocks: [],
      children: events.map { |event| aboutme_event_card(entry, event) },
      collapsible: false,
      card_url: entry["card_url"].presence || entry["title_url"].presence,
      aria_label: "Open #{entry["title"]}"
    }
  end

  private

  def aboutme_sentence(value)
    return nil unless aboutme_visible_detail?(value)

    text = value.to_s.squish
    text.match?(/[.!?]\z/) ? text : "#{text}."
  end

  def aboutme_link_options(url)
    url.to_s.start_with?("/") ? {} : { target: "_blank", rel: "noopener noreferrer" }
  end

  def aboutme_finding_tags(entry)
    [].tap do |tags|
      tags << { label: entry["severity"], class_name: "aboutme-severity #{aboutme_severity_class(entry["severity"])}" } if entry["severity"].present?
      tags << { label: entry["cve_id"], url: aboutme_cve_url(entry["cve_id"]), class_name: "aboutme-cve-id" } if entry["cve_id"].present?
      tags << { label: entry["cwe_id"], url: aboutme_cwe_url(entry["cwe_id"]), class_name: "aboutme-cwe-id" } if entry["cwe_id"].present?
    end
  end

  def aboutme_milestone_tags(entry, events)
    [].tap do |tags|
      if entry["category"].present?
        tags << { label: entry["category"], url: entry["category_url"], class_name: "aboutme-tag-#{entry["category"].parameterize}" }
      end
      tags << { label: entry["date"], datetime: entry["date"], class_name: "aboutme-tag-date" } if entry["date"].present? && events.empty?
    end
  end

  def aboutme_event_card(entry, event)
    event_id = event["id"].presence || [ entry["id"].presence || entry["title"], event["date"], event["title"] ].compact.join("-").parameterize

    {
      id: event_id,
      class_name: "aboutme-achievement-event",
      title: event["title"],
      description: event["summary"],
      tags: aboutme_event_tags(event),
      body_blocks: [],
      collapsible: false,
      card_url: event["card_url"].presence || event["url"].presence || entry["card_url"].presence || entry["title_url"].presence,
      aria_label: "Open #{event["title"].presence || entry["title"]}"
    }
  end

  def aboutme_event_tags(event)
    return [] if event["date"].blank?

    [ { label: event["date"], datetime: event["date"], class_name: "aboutme-tag-date" } ]
  end
end
