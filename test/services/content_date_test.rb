require "test_helper"

class ContentDateTest < ActiveSupport::TestCase
  test "supported precision retains exact dates and offsets" do
    {
      "2024-02-29" => "2024-02-29T00:00:00Z",
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
    [ nil, "", "2025-02-29", "2026-02-31", "2026-13-01", "2026-2024", "conference 2026", "2026-09-05T12:00:00", "2026-09-05T25:00:00Z" ].each do |input|
      assert_nil ContentDate.parse(input), input.inspect
      assert_equal ContentDate::EPOCH, ContentDate.parse(input, fallback: ContentDate::EPOCH), input.inspect
    end
  end

  test "local date boundaries use the application time zone" do
    Time.use_zone("Europe/Berlin") do
      assert_equal "2026-09-06", ContentDate.parse("2026-09-05T23:00:00Z").to_date.iso8601
      assert_equal "2026-09-05", ContentDate.parse("2026-09-05").to_date.iso8601
    end
  end
end
