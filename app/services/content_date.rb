require "date"
require "time"

module ContentDate
  EPOCH = Time.utc(1970, 1, 1).freeze
  YEAR = /\A\d{4}\z/
  RANGE = /\A(\d{4})\s*(?:-|–|—)\s*(\d{4})\z/
  MONTH = /\A\d{4}-\d{2}\z/
  DATE = /\A\d{4}-\d{2}-\d{2}\z/
  TIMESTAMP = /\A\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})\z/

  module_function

  # Imprecise dates sort at the end of their final month or year. Timestamps must
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
    elsif raw.match?(MONTH)
      year, month = raw.split("-").map(&:to_i)
      date = Date.new(year, month, -1)
      Time.zone.local(date.year, date.month, date.day)
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

  # Bounds express the uncertainty in a calendar year, month or day. They let
  # activity periods start at their first possible date and include their
  # entire final month/year without changing the ordering of point events.
  def bounds(value)
    parsed = parse(value)
    return unless parsed

    raw = value.to_s.strip
    if raw.match?(YEAR)
      [ parsed.beginning_of_year, parsed.end_of_year ]
    elsif raw.match?(MONTH)
      [ parsed.beginning_of_month, parsed.end_of_month ]
    elsif raw.match?(DATE) || value.is_a?(Date) && !value.is_a?(DateTime)
      [ parsed.beginning_of_day, parsed.end_of_day ]
    elsif (range = RANGE.match(raw))
      [ Time.zone.local(range[1].to_i, 1, 1), parsed.end_of_year ]
    else
      [ parsed, parsed ]
    end
  end

  # Format the authored precision, rather than exposing the synthetic final day
  # used to sort a month/year. Timestamps use the application's calendar date.
  def display_label(value)
    parsed = parse(value)
    return unless parsed

    raw = value.to_s.strip
    if raw.match?(YEAR)
      raw
    elsif (range = RANGE.match(raw))
      "#{range[1]}–#{range[2]}"
    elsif raw.match?(MONTH)
      parsed.strftime("%b %Y")
    else
      parsed.strftime("%-d %b %Y")
    end
  end

  def period_label(start_value, end_value)
    first = parse(start_value)
    last = parse(end_value)
    return unless first && last

    if start_value.match?(MONTH) && end_value.match?(MONTH) && first.year == last.year && first.month != last.month
      "#{first.strftime('%b')}–#{last.strftime('%b %Y')}"
    elsif start_value.match?(DATE) && end_value.match?(DATE) && first.year == last.year && first.to_date != last.to_date
      start_format = first.month == last.month ? "%-d" : "%-d %b"
      "#{first.strftime(start_format)}–#{last.strftime('%-d %b %Y')}"
    else
      [ display_label(start_value), display_label(end_value) ].uniq.join("–")
    end
  end
end
