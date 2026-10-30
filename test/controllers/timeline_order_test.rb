require "test_helper"

class TimelineOrderControllerTest < ActionDispatch::IntegrationTest
  test "timeline defaults to newest first and rejects unknown order values" do
    with_stubbed_content_repository(fixture_content_repository) do
      [ nil, "unknown" ].each do |order|
        get timeline_path, params: { order: order }.compact
        assert_response :success
        assert_select "#timeline-order-filter option[value='newest'][selected]", text: "Newest first"
        dates = css_select(".timeline-item").map { |node| node["data-filter-sort"].to_i }
        assert_equal dates.sort.reverse, dates
      end
    end
  end

  test "oldest first is rendered in document order without requiring JavaScript" do
    with_stubbed_content_repository(fixture_content_repository) do
      get timeline_path, params: { order: "oldest", q: "practice" }
      assert_response :success
      assert_select "label[for='timeline-order-filter']", text: "Order"
      assert_select "#timeline-order-filter option[value='oldest'][selected]", text: "Oldest first"
      assert_select "#timeline-search-input[value='practice']"
      dates = css_select(".timeline-item").map { |node| node["data-filter-sort"].to_i }
      years = css_select(".timeline-year-header h2").map { |node| node.text.to_i }
      assert_equal dates.sort, dates
      assert_equal years.sort, years
    end
  end

  test "period years are selectable while the card remains grouped under its starting year" do
    repository = fixture_content_repository
    events = repository.timeline_events
    events.first.merge!("date" => "2019-09", "end_date" => "2022")
    repository.define_singleton_method(:timeline_events) { events }

    with_stubbed_content_repository(repository) do
      get timeline_path, params: { order: "oldest" }
      assert_response :success
      assert_select "#timeline-event-fixture-timeline-only[data-filter-years='2019|2020|2021|2022']"
      [ 2019, 2020, 2021, 2022 ].each { |year| assert_select "#timeline-year-filter option[value='#{year}']" }
      card = css_select("#timeline-event-fixture-timeline-only").sole
      assert_equal "2019", card.ancestors(".timeline-year-group").first.at_css("h2").text.strip
    end
  end

  test "About opens the earliest milestone with oldest first selected" do
    get about_path
    assert_response :success
    assert_select "a[href='/timeline?order=oldest#timeline-event-overthewire-beginnings']", text: "how I got started"
  end

  test "posts view renders blog and writeup union with an accurate initial total" do
    repository = fixture_content_repository
    with_stubbed_content_repository(repository) do
      get timeline_path, params: { view: "posts" }
      assert_response :success
      assert_select "#timeline-view-filter option[value='posts'][selected]", text: "Posts"
      assert_select ".timeline-item:not([hidden])", 6
      assert_select ".timeline-item:not([hidden])[data-filter-kind='blog']", 3
      assert_select ".timeline-item:not([hidden])[data-filter-kind='writeup']", 3
      assert_select "[data-filter-count='timeline']", text: "6 of 12 items"
      assert_select ".timeline-item:not([hidden])[data-filter-kind='cve']", 0
      assert_select ".timeline-year-group:not([hidden]) .timeline-year-count", text: "2 items", count: 1

      get timeline_path, params: { view: "unknown" }
      assert_select "#timeline-view-filter option[value='all'][selected]", text: "All entries"
      assert_select ".timeline-item:not([hidden])", 12
    end
  end

  test "About platform bounty reference remains an external link rather than an empty timeline filter" do
    get about_path
    assert_response :success
    assert_select "#immunefi a[href='https://immunefi.com/bug-bounty/']", text: /Immunefi Bug Bounty/
    assert_select "#immunefi a[href=?]", "/timeline?tag=Bug+bounty", count: 0
    assert_select "#immunefi a[href=?]", "/timeline?tag=Audit+Competition", text: /Audit Competition/
  end
end
