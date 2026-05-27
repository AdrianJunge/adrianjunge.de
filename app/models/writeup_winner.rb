module WriteupWinner
  FILTER_LABEL = "Writeup winner".freeze
  DEFAULT_LABEL = "Contest win".freeze

  module_function

  def from_metadata(metadata)
    raw = metadata["writeup_winner"].presence || metadata["writeup-winner"].presence || metadata["winner"].presence
    return nil if raw.blank?

    winner =
      if raw.is_a?(Hash)
        {
          label: raw["label"].presence || raw[:label].presence || raw["title"].presence || raw[:title].presence || DEFAULT_LABEL,
          proof_url: raw["proof_url"].presence || raw[:proof_url].presence || raw["proof"].presence || raw[:proof].presence || raw["url"].presence || raw[:url].presence
        }
      else
        {
          label: DEFAULT_LABEL,
          proof_url: raw.to_s
        }
      end

    return nil if winner[:proof_url].blank?

    winner
  end

  def filter_label_for(metadata)
    from_metadata(metadata) ? FILTER_LABEL : nil
  end

  def filter_sort_key(value)
    [ value == FILTER_LABEL ? 0 : 1, value.downcase ]
  end
end
