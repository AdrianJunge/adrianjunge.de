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

  def aboutme_visible_details(details)
    Array(details).select(&:present?)
  end

  def aboutme_visible_events(events)
    Array(events).select do |event|
      event.is_a?(Hash) && %w[title date summary details links url].any? { |field| event[field].present? }
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

  private

  def aboutme_sentence(value)
    return nil unless aboutme_visible_detail?(value)

    text = value.to_s.squish
    text.match?(/[.!?]\z/) ? text : "#{text}."
  end

  def aboutme_link_options(url)
    url.to_s.start_with?("/") ? {} : { target: "_blank", rel: "noopener noreferrer" }
  end
end
