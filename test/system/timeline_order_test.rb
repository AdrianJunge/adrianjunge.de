require "application_system_test_case"
require_relative "../support/site_page_helpers"

class TimelineOrderSystemTest < ApplicationSystemTestCase
  include SitePageHelpers

  test "timeline order persists through filtering clearing and browser history" do
    total = timeline_items.length
    visit "/timeline?order=oldest#timeline-event-overthewire-beginnings"
    assert_selector ".content-filter-panel[data-initialized='true']"
    assert_selector "[data-filter-count='timeline']", count: 1, visible: :all
    assert_selector "[data-filter-reset='timeline']", count: 1, visible: :all
    assert_no_selector ".content-filter-panel [data-filter-count], .content-filter-panel [data-filter-reset]", visible: :all
    assert_timeline_summary total, total
    assert_selector :select, "Order", selected: "Oldest first"
    assert_timeline_order :oldest

    select "2024", from: "Year"
    assert_selector "#timeline-event-picoctf-beginnings"
    assert_selector "#timeline-event-leetcode-beginnings"
    find("[data-filter-search='timeline']").fill_in(with: "picoCTF")
    assert_selector ".timeline-item", count: 1
    assert_timeline_summary 1, total
    filtered_url = page.current_url

    select "Newest first", from: "Order"
    assert_selector ".timeline-item", count: 1
    assert_equal "2024", find("#timeline-year-filter").value
    assert_equal "picoCTF", find("[data-filter-search='timeline']").value
    assert_nil Rack::Utils.parse_query(URI.parse(page.current_url).query)["order"]

    page.go_back
    assert_current_path filtered_url
    assert_selector :select, "Order", selected: "Oldest first"
    assert_timeline_summary 1, total
    assert_timeline_order :oldest
    page.go_forward
    assert_selector :select, "Order", selected: "Newest first"
    assert_timeline_summary 1, total
    assert_timeline_order :newest

    select "Oldest first", from: "Order"
    find("[data-filter-reset='timeline']").click
    assert_selector :select, "Order", selected: "Oldest first"
    assert_selector :select, "Year", selected: "All years"
    assert_equal "", find("[data-filter-search='timeline']").value
    assert_current_path "/timeline?order=oldest"
    assert_equal "timeline-event-overthewire-beginnings", URI.parse(page.current_url).fragment
    assert_timeline_order :oldest
    assert_timeline_summary total, total

    page.execute_script("window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true }))")
    assert_selector :select, "Order", selected: "Oldest first"
    assert_timeline_order :oldest

    find("[data-filter-search='timeline']").fill_in(with: "unmatched-timeline-summary-query")
    assert_timeline_summary 0, total
    assert_no_selector "ul.timeline[data-filter-results='timeline']"
    assert_selector ".timeline-panel [data-filter-empty='timeline']"
    find(".timeline-results-summary [data-filter-reset='timeline']").click
    assert_timeline_summary total, total
    assert_selector "ul.timeline[data-filter-results='timeline']"
    assert_no_selector ".timeline-panel [data-filter-empty='timeline']"
    assert_selector :select, "Order", selected: "Oldest first"

    page.go_back
    assert_timeline_summary 0, total
    assert_selector ".timeline-panel [data-filter-empty='timeline']"
    assert_selector :select, "Order", selected: "Oldest first"
    page.go_forward
    assert_timeline_summary total, total
    assert_timeline_order :oldest
  end

  private

  def assert_timeline_summary(visible, total)
    assert_selector ".timeline-panel .timeline-results-summary [data-filter-count='timeline'][role='status'][aria-live='polite'][aria-atomic='true']",
                    exact_text: filter_count_text(visible, total, separator: "of")
  end

  def assert_timeline_order(order)
    dates = page.evaluate_script("[...document.querySelectorAll('.timeline-item')].map(card => Number(card.dataset.filterSort))")
    assert_equal(order == :oldest ? dates.sort : dates.sort.reverse, dates)
    years = page.evaluate_script("[...document.querySelectorAll('.timeline-year-group')].map(group => Number(group.dataset.filterSort))")
    assert_equal(order == :oldest ? years.sort : years.sort.reverse, years)
  end
end
