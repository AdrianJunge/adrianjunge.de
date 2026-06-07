module ContentSeverityTag
  SEVERITY_KEYS = {
    "critical" => "critical",
    "high" => "high",
    "moderate" => "medium",
    "medium" => "medium",
    "low" => "low",
    "info" => "info",
    "informational" => "info",
    "tba" => "tba"
  }.freeze

  module_function

  def css_key(value)
    SEVERITY_KEYS[normalized(value)]
  end

  def recognized?(value)
    css_key(value).present?
  end

  def css_class(value, prefix: "aboutme-severity")
    key = css_key(value)
    "#{prefix}-#{key}" if key
  end

  def normalized(value)
    value.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
