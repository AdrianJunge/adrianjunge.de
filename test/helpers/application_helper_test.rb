require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "typed filter links preserve severity and legacy difficulty meaning" do
    assert_equal "/timeline?tag=difficulty%3Amedium", timeline_filter_path(tag: "Medium")
    assert_equal "/timeline?tag=severity%3Amedium", timeline_filter_path(tag: "severity:medium")
    path = timeline_filter_path(tags: [ "severity:medium", "difficulty:medium" ], year: "2026", q: "sample")
    params = Rack::Utils.parse_nested_query(URI.parse(path).query)
    assert_equal "severity:medium|difficulty:medium", params["tags"]
    assert_equal "2026", params["year"]
    assert_equal "sample", params["q"]
  end

  test "upcoming status updates across a warm snapshot date boundary" do
    document = production_content_repository.blog_posts.first
    travel_to Time.zone.local(2026, 9, 5, 23, 59) do
      assert upcoming_date?("2026-09-06")
      assert_same document[:body], ContentRepository.new.blog_post(document[:slug])[:body]
    end
    travel_to Time.zone.local(2026, 9, 6, 0, 1) do
      assert_not upcoming_date?("2026-09-06")
      assert_same document[:body], ContentRepository.new.blog_post(document[:slug])[:body]
    end
  end

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
