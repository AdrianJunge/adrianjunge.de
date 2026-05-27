module AboutmeHelper
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

  def aboutme_value(value, fallback = "Not listed")
    value.present? ? value : fallback
  end

  def aboutme_external_link(link)
    return nil unless link.is_a?(Hash)

    label = link["label"].presence || link["url"]
    url = link["url"].to_s
    return nil if label.blank? || url.blank?

    if url.start_with?("/")
      link_to(label, url)
    else
      link_to(label, url, target: "_blank", rel: "noopener noreferrer")
    end
  end

  def aboutme_optional_link(label, url, class_name: nil)
    return nil if label.blank?

    text = label
    url = url.to_s
    options = {}
    options[:class] = class_name if class_name.present?

    return content_tag(:span, text, options) if url.blank?

    if url.start_with?("/")
      link_to(text, url, options)
    else
      link_to(text, url, options.merge(target: "_blank", rel: "noopener noreferrer"))
    end
  end

  def aboutme_finding_collapsible?(entry)
    %w[summary tested_version impact].any? { |field| aboutme_visible_detail?(entry[field]) } ||
      aboutme_visible_links(entry["github_advisories"]).any? ||
      aboutme_timeline_items(entry["timeline"]).any?
  end

  def aboutme_visible_detail?(value)
    value.present? && value.to_s.strip.casecmp("tba") != 0
  end

  def aboutme_visible_links(links)
    Array(links).select do |link|
      link.is_a?(Hash) && link["url"].present? && (link["label"].present? || link["url"].present?)
    end
  end

  def aboutme_timeline_items(timeline)
    Array(timeline).select do |item|
      item.is_a?(Hash) && item["event"].present?
    end
  end

  def aboutme_visible_details(details)
    Array(details).select(&:present?)
  end

  def aboutme_visible_events(events)
    Array(events).select do |event|
      event.is_a?(Hash) && %w[title date summary details links url].any? { |field| event[field].present? }
    end
  end
end
