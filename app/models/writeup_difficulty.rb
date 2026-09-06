module WriteupDifficulty
  UNKNOWN_LABEL = "unknown difficulty".freeze
  UNKNOWN_KEY = "unknown".freeze

  LEVELS = {
    "intro" => { key: "intro", label: "Intro" },
    "easy" => { key: "easy", label: "Easy" },
    "medium" => { key: "medium", label: "Medium" },
    "hard" => { key: "hard", label: "Hard" },
    "insane" => { key: "insane", label: "Insane / 0-day" }
  }.freeze
  FILTER_ORDER = (LEVELS.keys + [ UNKNOWN_KEY ]).freeze

  ALIASES = {
    "introduction" => "intro",
    "beginner" => "intro",
    "normal" => "medium",
    "0-day" => "insane",
    "0day" => "insane",
    "zero-day" => "insane",
    "insane/0-day" => "insane",
    "insane-/-0-day" => "insane",
    "expert" => "insane",
    "master" => "insane",
    "unknown" => UNKNOWN_KEY,
    "unknown-difficulty" => UNKNOWN_KEY,
    "n/a" => UNKNOWN_KEY,
    "na" => UNKNOWN_KEY
  }.freeze

  module_function

  def from_metadata(metadata)
    normalize(raw_from_metadata(metadata))
  end

  def filter_label_for(metadata = nil, fallback: false, **metadata_keywords)
    metadata = metadata_keywords if metadata.nil? && metadata_keywords.any?
    return nil unless fallback || metadata_present?(metadata)

    from_metadata(metadata)[:label]
  end

  def metadata_present?(metadata)
    raw = raw_from_metadata(metadata)
    raw.present? || raw == true
  end

  def raw_from_metadata(metadata)
    AuthoredChallenge.metadata_value(metadata, "difficulty", "challenge_difficulty", "challenge-difficulty")
  end

  def normalize(raw)
    raw = raw_value(raw, "label", "name", "value", "difficulty") if raw.is_a?(Hash)
    key = normalized_key(raw)

    return unknown if key.blank? || key == UNKNOWN_KEY

    level_key = LEVELS.key?(key) ? key : ALIASES[key]
    return unknown unless level_key && LEVELS.key?(level_key)

    LEVELS[level_key].dup
  end

  def known?(difficulty)
    difficulty.present? && difficulty[:key] != UNKNOWN_KEY
  end

  def css_key(value)
    difficulty = value.is_a?(Hash) ? value : normalize(value)
    difficulty[:key].presence || UNKNOWN_KEY
  end

  def filter_label?(value)
    canonical_key(value).present?
  end

  def filter_sort_key(value)
    key = canonical_key(value)
    [ FILTER_ORDER.index(key) || FILTER_ORDER.length, value.to_s.downcase ]
  end

  def unknown
    { key: UNKNOWN_KEY, label: UNKNOWN_LABEL }
  end

  def normalized_key(raw)
    raw.to_s.strip.downcase.delete_prefix("difficulty:").gsub(/[[:space:]_]+/, "-")
  end

  def canonical_key(raw)
    key = normalized_key(raw)
    return key if LEVELS.key?(key) || key == UNKNOWN_KEY

    ALIASES[key]
  end

  def raw_value(hash, *keys)
    AuthoredChallenge.raw_value(hash, *keys)
  end
end
