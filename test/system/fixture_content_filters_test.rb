require "application_system_test_case"

# Expected results are authored alongside the synthetic catalog, never derived
# by repeating the production normalizer, taxonomy, or matching algorithm.
class FixtureContentFiltersTest < ApplicationSystemTestCase
  CASES = JSON.parse(File.read(Rails.root.join("test/fixtures/content_filter_cases.json"))).fetch("pages")

  CASES.each do |spec|
    test "synthetic #{spec.fetch('scope')} filters produce the specified visible results" do
      with_stubbed_content_repository(fixture_content_repository) do
        spec.fetch("cases").each do |example|
          params = example.fetch("params").flat_map do |key, value|
            Array(value).map { |entry| [ key, entry ] }
          end
          query = URI.encode_www_form(params)
          visit "#{spec.fetch('path')}#{query.empty? ? '' : "?#{query}"}"
          assert_selector ".content-filter-panel[data-initialized='true']"
          expected = example.fetch("titles")
          scope = spec.fetch("scope")
          total = spec.fetch("total")
          assert_selector "[data-filter-count='#{scope}']", exact_text: "#{expected.length} / #{total} #{total == 1 ? 'item' : 'items'}"
          actual = all(spec.fetch("title_selector")).map(&:text)
          assert_equal expected.sort, actual.sort, "Wrong results on #{spec.fetch('path')} for #{params.inspect}"
          assert_selector "[data-filter-empty='#{scope}']" if expected.empty?
          assert_no_text "Hidden Writeup"
        end
      end
    end
  end

  test "synthetic filters update after typing clear reset and history navigation" do
    with_stubbed_content_repository(fixture_content_repository) do
      visit "/blog"
      assert_selector ".content-filter-panel[data-initialized='true']"
      search = find("[data-filter-search='blogs']")
      search.fill_in(with: "algrthms")
      assert_selector "[data-filter-count='blogs']", text: "1 / 3 items"
      assert_equal [ "Beta Algorithms" ], all(".blog-post-title").map(&:text)
      find("[data-filter-clear='blogs']").click
      assert_field search[:id], with: ""
      assert_selector ".blog-post-card", count: 3
      find("[data-filter-year='blogs']").select("2024")
      assert_equal [ "Gamma Notes" ], all(".blog-post-title").map(&:text)
      find("[data-filter-reset='blogs']").click
      assert_selector ".blog-post-card", count: 3
      page.go_back
      assert_selector "[data-filter-count='blogs']", text: "1 / 3 items"
      assert_equal [ "Gamma Notes" ], all(".blog-post-title").map(&:text)
    end
  end
end
