require "application_system_test_case"

class SearchControlsTest < ApplicationSystemTestCase
  [ 390, 1440 ].each do |width|
    test "archive search clear controls preserve other filters at #{width}px" do
      page.current_window.resize_to(width, 1000)

      [ "/blog", "/ctf", "/ctf/cscg", "/timeline" ].each do |path|
        visit "#{path}?source=clear-controls&source=archive#main-content"
        assert_selector ".content-filter-panel[data-initialized='true']"
        wrapper = find(".content-filter-panel .search-wrapper")
        search = wrapper.find("[data-filter-search]")
        assert_selector ".content-filter-panel .search-wrapper .search-clear-btn", count: 1, visible: :all
        clear = wrapper.find(".search-clear-btn", visible: :all)
        assert_equal "button", clear[:type]
        assert_equal "Clear search", clear[:"aria-label"]
        assert_clear_hidden(wrapper)

        search.click
        save_archive_screenshot("blank", width) if path == "/blog"
        search.send_keys(:tab)
        assert_selector "[data-filter-year]:focus"

        year = find("[data-filter-year]")
        option = year.all("option").find { |item| item[:value].present? }
        year.select(option.text)
        selected_year = year.value
        chip = find(".content-filter-common [data-filter-tag]:not(.is-uncombinable)", match: :first)
        chip.click
        assert_equal "true", chip["aria-pressed"]
        filtered_url = page.current_url
        visible_count = all("[data-filter-card]").length
        assert_operator visible_count, :>, 0

        [ :click, :enter ].each do |activation|
          search.fill_in(with: "no-matching-published-post")
          assert_no_selector "[data-filter-card]"
          within wrapper do
            assert_selector "button.search-clear-btn[aria-label='Clear search']:not([disabled])", count: 1
          end
          save_archive_screenshot("filled", width) if path == "/blog" && activation == :click

          if activation == :click
            clear.click
          else
            search.send_keys(:tab)
            assert_selector ".content-filter-panel .search-clear-btn:focus"
            page.driver.browser.action.send_keys(:enter).perform
          end

          assert_equal "", search.value
          assert_selector "[data-filter-search]:focus"
          assert_clear_hidden(wrapper)
          assert_equal selected_year, year.value
          assert_equal "true", chip["aria-pressed"]
          assert_selector "[data-filter-card]", count: visible_count
          assert_current_path filtered_url
          search.send_keys(:tab)
          assert_selector "[data-filter-year]:focus"
        end
      end
    end
  end

  private

  def assert_clear_hidden(wrapper)
    within wrapper do
      assert_no_selector ".search-clear-btn"
    end
  end

  def save_archive_screenshot(state, width)
    directory = Rails.root.join("tmp/search-refinement")
    FileUtils.mkdir_p(directory)
    save_screenshot(directory.join("archive-search-#{state}-#{width}.png"))
  end
end
