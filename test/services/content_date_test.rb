require "test_helper"

class ContentDateTest < ActiveSupport::TestCase
  test "supported precision retains exact dates and offsets" do
    {
      "2024-02-29" => "2024-02-29T00:00:00Z",
      "2024-02" => "2024-02-29T00:00:00Z",
      "2025-02" => "2025-02-28T00:00:00Z",
      "2019-09" => "2019-09-30T00:00:00Z",
      "2026" => "2026-12-31T00:00:00Z",
      "2024–2026" => "2026-12-31T00:00:00Z",
      "2024 - 2026" => "2026-12-31T00:00:00Z",
      "2026-05-27T14:23:45+02:00" => "2026-05-27T12:23:45Z",
      "2026-05-27 14:23:45Z" => "2026-05-27T14:23:45Z"
    }.each do |input, expected|
      assert_equal Time.iso8601(expected), ContentDate.parse(input), input
    end
  end

  test "invalid input does not roll over dates or extract incidental years" do
    [ nil, "", "2026-00", "2026-13", "2026-9", "2025-02-29", "2026-02-31", "2026-13-01", "2026-2024", "conference 2026", "2026-09-05T12:00:00", "2026-09-05T25:00:00Z" ].each do |input|
      assert_nil ContentDate.parse(input), input.inspect
      assert_equal ContentDate::EPOCH, ContentDate.parse(input, fallback: ContentDate::EPOCH), input.inspect
    end
  end

  test "local date boundaries use the application time zone" do
    Time.use_zone("Europe/Berlin") do
      assert_equal "2026-09-06", ContentDate.parse("2026-09-05T23:00:00Z").to_date.iso8601
      assert_equal "2026-09-05", ContentDate.parse("2026-09-05").to_date.iso8601
      assert_equal "2026-09-30", ContentDate.parse("2026-09").to_date.iso8601
    end
  end

  test "display labels preserve date precision and format exact dates consistently" do
    {
      "2023-10-02" => "2 Oct 2023",
      "2024-02-29" => "29 Feb 2024",
      "2023-10" => "Oct 2023",
      "2023" => "2023",
      "2023 - 2025" => "2023–2025",
      "2023—2025" => "2023–2025",
      "2023-10-02T14:23:45+02:00" => "2 Oct 2023",
      Date.new(2023, 10, 2) => "2 Oct 2023",
      Time.iso8601("2023-10-02T14:23:45Z") => "2 Oct 2023"
    }.each do |input, expected|
      assert_equal expected, ContentDate.display_label(input), input.inspect
    end

    [ nil, "", "2025-02-29", "Around Sep 2019" ].each do |input|
      assert_nil ContentDate.display_label(input), input.inspect
    end
    Time.use_zone("Europe/Berlin") do
      assert_equal "6 Sep 2026", ContentDate.display_label("2026-09-05T23:00:00Z")
    end
  end

  test "period bounds cover the full precision of calendar endpoints" do
    {
      "2024" => %w[2024-01-01T00:00:00Z 2024-12-31T23:59:59Z],
      "2024-02" => %w[2024-02-01T00:00:00Z 2024-02-29T23:59:59Z],
      "2025-02" => %w[2025-02-01T00:00:00Z 2025-02-28T23:59:59Z],
      "2024-02-29" => %w[2024-02-29T00:00:00Z 2024-02-29T23:59:59Z],
      "2023-12-31T23:30:00-02:00" => %w[2024-01-01T01:30:00Z 2024-01-01T01:30:00Z]
    }.each do |input, expected|
      assert_equal expected, ContentDate.bounds(input).map(&:iso8601), input
    end
    assert_nil ContentDate.bounds("2025-02-29")
    assert_nil ContentDate.bounds(nil)
    Time.use_zone("Europe/Berlin") do
      assert_equal %w[2024-03-01T00:00:00+01:00 2024-03-31T23:59:59+02:00], ContentDate.bounds("2024-03").map(&:iso8601)
    end
  end

  test "period labels preserve the authored precision without repeating shared components" do
    {
      [ "2019-09", "2021" ] => "Sep 2019–2021",
      [ "2023-03", "2023-04" ] => "Mar–Apr 2023",
      [ "2023-10-02", "2025" ] => "2 Oct 2023–2025",
      [ "2023", "2025" ] => "2023–2025",
      [ "2024-02-28", "2024-02-29" ] => "28–29 Feb 2024",
      [ "2024-02-29", "2024-03-02" ] => "29 Feb–2 Mar 2024",
      [ "2024-02", "2024-02" ] => "Feb 2024",
      [ "2024-02-29T12:00:00Z", "2024-03-02T12:00:00Z" ] => "29 Feb 2024–2 Mar 2024"
    }.each do |endpoints, label|
      assert_equal label, ContentDate.period_label(*endpoints)
    end
  end
end
