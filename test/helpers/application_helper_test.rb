require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "upcoming dates are derived relative to the current date" do
    travel_to Time.zone.local(2026, 9, 1, 12) do
      assert upcoming_date?("2026-09-02")
      assert upcoming_date?(Time.zone.local(2026, 11, 9))
      assert_not upcoming_date?("2026-09-01")
      assert_not upcoming_date?("2026-08-31")
      assert_not upcoming_date?("not-a-date")
      assert_not upcoming_date?(nil)
    end
  end

  test "upcoming badge has shared accessible text and contextual classes" do
    render inline: "<%= content_upcoming_badge(class_name: 'timeline-upcoming-badge') %>"

    assert_select "span.content-upcoming-badge.timeline-upcoming-badge", text: "Upcoming"
  end
end
