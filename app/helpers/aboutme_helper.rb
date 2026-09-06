require "cgi"

module AboutmeHelper
  PROFILE_SECTIONS = [
    { id: "cves", kind: "cve", title: "CVEs", singular: "entry", plural: "entries", empty_text: "No public CVEs are listed yet." },
    { id: "bug-bounties", kind: "bug-bounty", title: "Bug bounties", singular: "finding", plural: "findings", empty_text: "No public bounties yet - the disclosure timers are still pretending to be load-bearing." },
    { id: "my-challenges", kind: "challenge", title: "Created CTF Challenges", singular: "challenge", plural: "challenges", empty_text: "No authored challenges are listed yet." },
    { id: "certificates", kind: "certificate", title: "Certificates", singular: "certificate", plural: "certificates", empty_text: "No certificates are listed yet." },
    { id: "talks", kind: "talk", title: "Talks", singular: "talk", plural: "talks", empty_text: "No talks are listed yet." },
    { id: "achievements", kind: "achievement", title: "Relevant achievements", singular: "event", plural: "events", empty_text: "No achievements are listed yet." }
  ].map(&:freeze).freeze

  def about_profile_sections
    collections = {
      "cves" => [ @cves, @cve_entry_count ], "bug-bounties" => [ @bug_bounties, @bug_bounties.length ],
      "my-challenges" => [ @challenges, @challenges.length ], "certificates" => [ @certificates, @certificates.length ],
      "talks" => [ @talks, @talk_event_count ], "achievements" => [ @achievements, @achievement_event_count ]
    }
    PROFILE_SECTIONS.map do |section|
      entries, count = collections.fetch(section[:id])
      section.merge(entries: entries, count: count, grid_class: %w[cve bug-bounty].include?(section[:kind]) ? "aboutme-finding-grid" : "aboutme-achievement-grid")
    end
  end

  def about_profile_stats
    about_profile_sections.map do |section|
      { label: section[:id] == "achievements" ? "Achievements" : section[:title], value: section[:count], anchor: section[:id] }
    end
  end

  private

  def aboutme_visible_detail?(value)
    value.present? && value.to_s.strip.casecmp("tba") != 0
  end

  def aboutme_sentence(value)
    return nil unless aboutme_visible_detail?(value)

    text = value.to_s.squish
    text.match?(/[.!?]\z/) ? text : "#{text}."
  end

  def aboutme_tag_style_classes(label, class_name)
    classes = class_name.to_s.split
    typed_severity = label.to_s.start_with?("severity:")
    label = ContentTagTaxonomy.canonical_label(label)
    class_text = classes.join(" ")

    if ContentVulnerabilityTag.cve?(label) || classes.include?("aboutme-cve-id")
      classes.push("aboutme-cve-id", "cve-badge")
    elsif ContentVulnerabilityTag.cwe?(label) || classes.include?("aboutme-cwe-id")
      classes.push("aboutme-cwe-id", "cwe-badge")
    elsif !typed_severity && (difficulty_key = (WriteupDifficulty.css_key(label) if WriteupDifficulty.filter_label?(label)) || class_text[/\baboutme-difficulty-tag-([a-z0-9-]+)\b/, 1])
      classes.push("aboutme-difficulty-tag", "aboutme-difficulty-tag-#{difficulty_key}", "difficulty-badge", "difficulty-badge-#{difficulty_key}")
    elsif (severity_key = ContentSeverityTag.css_key(label) || class_text[/\baboutme-severity-([a-z0-9-]+)\b/, 1])
      classes.push("aboutme-severity", "severity-badge", "severity-badge-#{severity_key}", "aboutme-severity-#{severity_key}")
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
      repository = respond_to?(:content_repository, true) ? content_repository : ContentRepository.new

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
