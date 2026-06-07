module AuthoredChallenge
  FILTER_LABEL = "Authored challenge".freeze
  DEFAULT_LABEL = FILTER_LABEL

  module_function

  def from_metadata(metadata)
    raw = metadata_value(metadata, "authored_challenge", "authored-challenge", "challenge_author")
    return nil if raw.blank?
    return nil if raw == false || raw.to_s.strip.casecmp("false").zero?

    if raw.is_a?(Hash)
      {
        label: raw_value(raw, "label", "title").presence || DEFAULT_LABEL,
        event: raw_value(raw, "event", "category"),
        event_url: raw_value(raw, "event_url", "category_url", "url"),
        summary: raw_value(raw, "summary", "description"),
        date: raw_value(raw, "date", "published"),
        id: raw_value(raw, "id")
      }
    elsif raw == true
      {
        label: DEFAULT_LABEL,
        event: nil,
        event_url: nil,
        summary: nil,
        date: nil,
        id: nil
      }
    else
      {
        label: DEFAULT_LABEL,
        event: raw.to_s.presence,
        event_url: nil,
        summary: nil,
        date: nil,
        id: nil
      }
    end
  end

  def filter_label_for(metadata)
    from_metadata(metadata) ? FILTER_LABEL : nil
  end

  def filter_sort_key(value)
    case value
    when WriteupWinner::FILTER_LABEL
      [ 0, value.downcase ]
    when FILTER_LABEL
      [ 1, value.downcase ]
    else
      [ 2, value.downcase ]
    end
  end

  def metadata_value(metadata, *keys)
    return nil unless metadata.respond_to?(:[])

    sources = []
    optional = raw_value(metadata, "optional")
    sources << optional if optional.respond_to?(:[])
    sources << metadata

    sources.each do |source|
      value = raw_value(source, *keys)
      return value if value.present? || value == true || value == false
    end

    nil
  end

  def raw_value(hash, *keys)
    keys.each do |key|
      return hash[key] if hash.key?(key)

      symbol_key = key.to_sym
      return hash[symbol_key] if hash.key?(symbol_key)
    end

    nil
  end
end
