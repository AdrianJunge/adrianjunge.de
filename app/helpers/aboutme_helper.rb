require "cgi"

module AboutmeHelper
  CVE_ID_PATTERN = /\ACVE-\d{4}-\d{4,}\z/i
  CWE_ID_PATTERN = /\ACWE-(\d+)\z/i

  def aboutme_severity_class(severity)
    ContentSeverityTag.css_class(severity) || "aboutme-severity-info"
  end

  def aboutme_optional_link(label, url, class_name: nil, aria_label: nil, title: nil)
    profile_card_optional_link(label, url, class_name: class_name, aria_label: aria_label, title: title)
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
    profile_card_link_attributes(url, label)
  end

  def aboutme_tag(label:, url: nil, class_name: nil, datetime: nil)
    profile_card_tag(label: label, url: url, class_name: class_name, datetime: datetime)
  end

  def aboutme_ordered_tags(tags)
    profile_card_ordered_tags(tags)
  end

  def aboutme_finding_card(entry, kind:)
    profile_finding_card(entry, kind: kind)
  end

  def aboutme_milestone_card(entry)
    profile_milestone_card(entry)
  end

  private

  def aboutme_sentence(value)
    return nil unless aboutme_visible_detail?(value)

    text = value.to_s.squish
    text.match?(/[.!?]\z/) ? text : "#{text}."
  end

  def aboutme_tag_style_classes(label, class_name)
    classes = class_name.to_s.split
    label = ContentTagTaxonomy.canonical_label(label)
    class_text = classes.join(" ")

    if ContentVulnerabilityTag.cve?(label) || classes.include?("aboutme-cve-id")
      classes << "cve-badge"
    elsif ContentVulnerabilityTag.cwe?(label) || classes.include?("aboutme-cwe-id")
      classes << "cwe-badge"
    elsif (difficulty_key = WriteupDifficulty.css_key(label) || class_text[/\baboutme-difficulty-tag-([a-z0-9-]+)\b/, 1])
      classes.push("difficulty-badge", "difficulty-badge-#{difficulty_key}")
    elsif (severity_key = ContentSeverityTag.css_key(label) || class_text[/\baboutme-severity-([a-z0-9-]+)\b/, 1])
      classes.push("severity-badge", "severity-badge-#{severity_key}", "aboutme-severity-#{severity_key}")
    elsif ContentCategoryTag.recognized?(label)
      category_key = ContentCategoryTag.css_key(label)
      classes.push("category-badge", "category-badge-#{category_key}")
    end

    classes
  end

  def aboutme_extra_tags(raw_tags)
    Array(raw_tags).filter_map do |tag|
      if tag.respond_to?(:to_h)
        tag_data = tag.to_h
        label = tag_data["label"].presence || tag_data[:label].presence || tag_data["name"].presence || tag_data[:name].presence
        next if label.blank?

        {
          label: label,
          url: tag_data["url"].presence || tag_data[:url].presence,
          class_name: tag_data["class_name"].presence || tag_data[:class_name].presence,
          datetime: tag_data["datetime"].presence || tag_data[:datetime].presence
        }
      else
        label = tag.to_s.presence
        { label: label } if label
      end
    end
  end

  def aboutme_reading_time_for_url(url)
    normalized_path = aboutme_normalized_local_path(url)
    return nil if normalized_path.blank?

    aboutme_post_reading_times[normalized_path]
  end

  def aboutme_post_reading_times
    @aboutme_post_reading_times ||= begin
      repository = ContentRepository.new

      (repository.blog_posts + repository.ctf_posts).each_with_object({}) do |post, reading_times|
        path = aboutme_normalized_local_path(post[:link])
        next if path.blank? || post[:reading_time_label].blank?

        reading_times[path] = post[:reading_time_label]
      end
    end
  end

  def aboutme_normalized_local_path(url)
    raw_url = url.to_s
    return nil unless raw_url.start_with?("/")

    path = raw_url.split(/[?#]/, 2).first
    CGI.unescape(path)
  rescue ArgumentError
    path
  end
end
