module ContentTagTaxonomy
  CONTENT_TYPE_LABELS = [
    "CTF writeup",
    "Blog post",
    "Security Research",
    "Algorithms",
    "CVE",
    "Bug bounty",
    "Certificate",
    "Talk",
    "Slides",
    "Achievement",
    "CTF Competition",
    "CTF Team",
    "Audit Competition"
  ].freeze
  CONTENT_TYPE_LOOKUP = CONTENT_TYPE_LABELS.to_h { |label| [ label.downcase, label ] }.freeze

  TECHNICAL_LABELS = {
    "web" => "Web",
    "web exploitation" => "Web",
    "pwn" => "Pwn",
    "pwnable" => "Pwn",
    "binary exploitation" => "Pwn",
    "crypto" => "Crypto",
    "cryptography" => "Crypto",
    "privilege escalation" => "Privilege Escalation",
    ".net" => ".NET",
    "dotnet" => ".NET"
  }.freeze

  LABEL_ALIASES = TECHNICAL_LABELS.merge(
    "algorithm" => "Algorithms",
    "certification" => "Certificate"
  ).freeze

  GROUP_LABELS = {
    recognition: "Recognition",
    difficulty: "Difficulty",
    severity: "Severity",
    content_type: "Content type",
    ctf_competition: "CTF competitions",
    repository: "Repositories",
    cve: "CVEs",
    cwe: "CWEs",
    category: "Categories",
    topic: "Topics"
  }.freeze

  GROUP_ORDER = GROUP_LABELS.keys.freeze

  module_function

  def canonical_label(value)
    raw = value.to_s.squish
    return "" if raw.blank?
    return WriteupDifficulty.normalize(raw)[:label] if raw.start_with?("difficulty:")
    return severity_label(raw.delete_prefix("severity:")) if raw.start_with?("severity:")

    return WriteupDifficulty.normalize(raw)[:label] if WriteupDifficulty.filter_label?(raw)
    return ContentVulnerabilityTag.normalized(raw) if ContentVulnerabilityTag.cve?(raw) || ContentVulnerabilityTag.cwe?(raw)
    return severity_label(raw) if ContentSeverityTag.recognized?(raw) && !WriteupDifficulty.filter_label?(raw)
    return canonical_content_type(raw) if canonical_content_type(raw).present?

    LABEL_ALIASES.fetch(normalized_key(raw), raw)
  end

  # Legacy untyped difficulty URLs (including Medium) retain their old meaning.
  # Severity is explicitly typed by the About collection that supplies it.
  def canonical_value(value, type: nil)
    raw = value.to_s.squish
    return "" if raw.blank?

    type ||= :difficulty if raw.start_with?("difficulty:")
    type ||= :severity if raw.start_with?("severity:")
    label = canonical_label(raw)
    return "difficulty:#{WriteupDifficulty.css_key(label)}" if type == :difficulty || (type.nil? && WriteupDifficulty.filter_label?(label))
    return "severity:#{ContentSeverityTag.css_key(label)}" if type == :severity || ContentSeverityTag.recognized?(label)

    label
  end

  def canonical_values(values)
    Array(values)
      .map { |value| canonical_value(value) }
      .reject(&:blank?)
      .uniq { |value| value.downcase }
  end

  def group_for(value, content_labels: CONTENT_TYPE_LABELS, ctf_labels: [], repository_labels: [])
    return :difficulty if value.to_s.start_with?("difficulty:")
    return :severity if value.to_s.start_with?("severity:")

    label = canonical_label(value)
    return :recognition if recognition?(label)
    return :difficulty if WriteupDifficulty.filter_label?(label)
    return :severity if ContentSeverityTag.recognized?(label) && !WriteupDifficulty.filter_label?(label)
    return :content_type if content_type?(label, content_labels)
    return :ctf_competition if ctf_competition?(label, ctf_labels)
    return :repository if repository?(label, repository_labels)
    return :cve if ContentVulnerabilityTag.cve?(label)
    return :cwe if ContentVulnerabilityTag.cwe?(label)
    return :category if ContentCategoryTag.recognized?(label)

    :topic
  end

  def sort_key(value, content_labels: CONTENT_TYPE_LABELS, ctf_labels: [], repository_labels: [])
    label = canonical_label(value)
    group = group_for(value, content_labels: content_labels, ctf_labels: ctf_labels, repository_labels: repository_labels)
    group_index = GROUP_ORDER.index(group) || GROUP_ORDER.length
    specific_key =
      case group
      when :recognition
        AuthoredChallenge.filter_sort_key(label)
      when :difficulty
        WriteupDifficulty.filter_sort_key(label)
      when :severity
        ContentSeverityTag.sort_key(label)
      when :cve, :cwe
        ContentVulnerabilityTag.sort_key(label)
      else
        [ label.downcase ]
      end

    [ group_index, *specific_key ]
  end

  def filter_groups(values, content_labels: CONTENT_TYPE_LABELS, ctf_labels: [], repository_labels: [], topic_label: GROUP_LABELS[:topic])
    grouped = Hash.new { |hash, key| hash[key] = [] }

    canonical_values(values).each do |tag|
      group = group_for(tag, content_labels: content_labels, ctf_labels: ctf_labels, repository_labels: repository_labels)
      grouped[group] << tag
    end

    GROUP_ORDER.filter_map do |group|
      tags = grouped[group]
      next if tags.blank?

      {
        label: group == :topic ? topic_label : GROUP_LABELS.fetch(group),
        sort: group.to_s,
        tags: tags.sort_by { |tag| sort_key(tag, content_labels: content_labels, ctf_labels: ctf_labels, repository_labels: repository_labels) }
      }
    end
  end

  def recognition?(value)
    label = canonical_label(value)
    label == WriteupWinner::FILTER_LABEL || label == AuthoredChallenge::FILTER_LABEL
  end

  def normalized_key(value)
    value.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def ctf_competition?(value, ctf_labels)
    label = canonical_label(value)
    known = canonical_values(ctf_labels)
    return true if known.any? { |ctf_label| ctf_label.casecmp?(label) }

    base_label = label.sub(/\s+\d{4}\z/, "")
    known.any? { |ctf_label| ctf_label.casecmp?(base_label) }
  end

  def repository?(value, repository_labels)
    label = canonical_label(value)
    canonical_values(repository_labels).any? { |repository_label| repository_label.casecmp?(label) }
  end

  def content_type?(value, content_labels = CONTENT_TYPE_LABELS)
    label = canonical_label(value)
    return CONTENT_TYPE_LOOKUP.key?(label.downcase) if content_labels.equal?(CONTENT_TYPE_LABELS)

    Array(content_labels).any? { |content_label| canonical_label(content_label).casecmp?(label) }
  end

  def canonical_content_type(value)
    CONTENT_TYPE_LOOKUP[normalized_key(value)]
  end

  def severity_label(value)
    case ContentSeverityTag.css_key(value)
    when "critical" then "Critical"
    when "high" then "High"
    when "medium" then normalized_key(value) == "moderate" ? "Moderate" : "Medium"
    when "low" then "Low"
    when "info" then "Info"
    when "tba" then "TBA"
    end
  end
end
