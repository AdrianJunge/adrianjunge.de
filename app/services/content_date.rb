require "date"
require "time"

module ContentDate
  EPOCH = Time.utc(1970, 1, 1).freeze
  YEAR = /\A\d{4}\z/
  RANGE = /\A(\d{4})\s*(?:-|–|—)\s*(\d{4})\z/
  DATE = /\A\d{4}-\d{2}-\d{2}\z/
  TIMESTAMP = /\A\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})\z/

  module_function

  # Imprecise dates sort at the end of their final year. Timestamps must
  # include an offset; invalid dates never silently roll into another month.
  def parse(value, fallback: nil)
    return value.in_time_zone if value.is_a?(Time) || value.is_a?(DateTime) || value.is_a?(ActiveSupport::TimeWithZone)
    return Time.zone.local(value.year, value.month, value.day) if value.is_a?(Date)

    raw = value.to_s.strip
    if raw.match?(YEAR)
      Time.zone.local(raw.to_i, 12, 31)
    elsif (range = RANGE.match(raw))
      return fallback if range[1].to_i > range[2].to_i

      Time.zone.local(range[2].to_i, 12, 31)
    elsif raw.match?(DATE)
      date = Date.iso8601(raw)
      Time.zone.local(date.year, date.month, date.day)
    elsif raw.match?(TIMESTAMP)
      Date.iso8601(raw[0, 10])
      Time.iso8601(raw.sub(" ", "T")).in_time_zone
    else
      fallback
    end
  rescue ArgumentError, RangeError
    fallback
  end
end
