require "application_system_test_case"

class TimelinePostsTest < ApplicationSystemTestCase
  test "Home Posts opens the post union and preserves its view through filters and history" do
    with_stubbed_content_repository(fixture_content_repository) do
      visit "/"
      assert_selector ".landing-metric[href='/timeline?view=posts'] .landing-metric-value", text: "6"
      find(".landing-metric[href='/timeline?view=posts']").click
      assert_selector ".content-filter-panel[data-initialized='true']"
      assert_selector :select, "Show", selected: "Posts"
      assert_selector "[data-filter-count='timeline']", exact_text: "6 of 12 items"
      assert_selector ".timeline-item[data-filter-kind='blog']", count: 3
      assert_selector ".timeline-item[data-filter-kind='writeup']", count: 3
      assert_no_selector ".timeline-item[data-filter-kind='cve']"
      assert_selector ".content-filter-common [data-filter-tag='CVE'][aria-disabled='true']"

      select "Oldest first", from: "Order"
      select "2024", from: "Year"
      assert_selector "[data-filter-count='timeline']", exact_text: "3 of 12 items"
      find("[data-filter-search='timeline']").fill_in(with: "Forensics")
      assert_selector ".timeline-title", exact_text: "Middle Writeup", count: 1
      assert_selector ".timeline-item", count: 1
      posts_url = page.current_url
      select "All entries", from: "Show"
      assert_selector ".timeline-item", count: 1
      assert_nil Rack::Utils.parse_query(URI.parse(page.current_url).query)["view"]

      page.go_back
      assert_current_path posts_url
      assert_selector :select, "Show", selected: "Posts"
      assert_selector :select, "Order", selected: "Oldest first"
      assert_selector :select, "Year", selected: "2024"
      assert_equal "Forensics", find("[data-filter-search='timeline']").value
      assert_selector ".timeline-item", count: 1

      find("[data-filter-clear='timeline']").click
      assert_selector :select, "Show", selected: "Posts"
      assert_selector "[data-filter-count='timeline']", exact_text: "3 of 12 items"
      find("[data-filter-reset='timeline']").click
      assert_selector :select, "Show", selected: "All entries"
      assert_selector :select, "Year", selected: "All years"
      assert_selector :select, "Order", selected: "Oldest first"
      assert_selector "[data-filter-count='timeline']", exact_text: "12 of 12 items"
      assert_current_path "/timeline?order=oldest"

      page.go_back
      assert_selector :select, "Show", selected: "Posts"
      assert_selector :select, "Year", selected: "2024"
      assert_selector "[data-filter-count='timeline']", exact_text: "3 of 12 items"
      page.execute_script("window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true }))")
      assert_selector :select, "Show", selected: "Posts"
      assert_selector "[data-filter-count='timeline']", exact_text: "3 of 12 items"
    end
  end
end
