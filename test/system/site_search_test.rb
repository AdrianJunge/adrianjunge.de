require "application_system_test_case"

class SiteSearchSystemTest < ApplicationSystemTestCase
  test "search loads only when opened and keyboard results reach real article headings" do
    with_search_article do |post|
      visit "/blog"
      trigger = find("[data-site-search-open][aria-keyshortcuts]", match: :first)
      assert_equal 0, index_request_count
      trigger.click
      assert_equal "true", trigger["aria-expanded"]
      assert_selector "dialog[open] [data-site-search-query]:focus"
      assert_selector "[data-site-search-close][aria-label='Close search'] svg", visible: :all
      assert_equal "", find("[data-site-search-close]").text
      query = find("dialog[open] [data-site-search-query]")
      query.fill_in(with: "bodyneedle otherneedle")
      assert_selector "dialog[open] .site-search-results a[href='#{post[:link]}#search-destination']"
      assert_equal 1, index_request_count
      query.send_keys(:escape)
      assert_no_selector "dialog[open]"
      assert_equal "false", trigger["aria-expanded"]
      assert_equal trigger, page.find(":focus")

      trigger.click
      assert_selector "dialog[open] [data-site-search-query]:focus"
      find("dialog[open] [data-site-search-query]").send_keys(:arrow_down)
      assert_selector "dialog[open] .site-search-results a:focus"
      page.driver.browser.action.send_keys(:arrow_up).perform
      assert_selector "dialog[open] [data-site-search-query]:focus"
      find("dialog[open] [data-site-search-query]").send_keys(:arrow_down, :enter)
      assert_current_path post[:link], ignore_query: true
      assert_equal "search-destination", URI.parse(page.current_url).fragment
      assert_selector "a[id='search-destination']", visible: :all
    end
  end

  test "the shortcut leaves editable inputs alone and returns focus after closing" do
    visit "/blog"
    filter = find("[data-filter-search]")
    filter.click
    intercepted = page.evaluate_script(<<~JS)
      (() => {
        const event = new KeyboardEvent('keydown', { key: 'k', ctrlKey: true, bubbles: true, cancelable: true });
        document.activeElement.dispatchEvent(event);
        return event.defaultPrevented;
      })()
    JS
    assert_not intercepted
    assert_no_selector "dialog[open]"
    assert_equal filter, page.find(":focus")

    trigger = find("[data-site-search-open][aria-keyshortcuts]", match: :first)
    trigger.send_keys([ :control, "k" ])
    assert_selector "dialog[open] [data-site-search-query]:focus"
    find("[data-site-search-close]").click
    assert_no_selector "dialog[open]"
    assert_equal trigger, page.find(":focus")
  end

  test "search is progressively enabled and the hidden overlay never offers a removed page" do
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
    visit "/blog"
    assert_selector "#search-taskbar-button[disabled][aria-controls='site-search-dialog']"
    assert_no_selector "dialog[open]"
    assert_no_selector "a[href='/search']", visible: :all
  ensure
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
  end

  test "failed loading can retry inside the overlay on a small screen" do
    with_search_article do |post|
      page.current_window.resize_to(390, 844)
      page.driver.browser.execute_cdp("Network.enable")
      page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "*/search/index.json*" ])
      visit "/blog"
      open_search
      fill_in "site-search-palette-query", with: "bodyneedle"
      assert_selector "dialog[open] [role=status]", text: "Search could not load."
      assert_selector "[data-site-search-retry]", text: "Retry"
      assert page.evaluate_script("document.querySelector('dialog').scrollWidth <= document.querySelector('dialog').clientWidth")
      page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
      find("[data-site-search-retry]").click
      assert_selector "dialog[open] .site-search-results a[href='#{post[:link]}#search-destination']"
      assert_no_selector "[data-site-search-retry]"
      find("[data-site-search-query]").send_keys(:enter)
      assert_selector "dialog[open] .site-search-results a[href='#{post[:link]}#search-destination']"
      assert_current_path "/blog"
    end
  ensure
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
  end

  test "global search reaches About cards and preserves distinct result kinds" do
    with_search_article do
      visit "/blog"
      open_search
      fill_in "site-search-palette-query", with: "CVE-2099-0001"
      assert_selector ".site-search-results a[href='/about#fixture-cve']", text: "Fixture Project"
      assert_selector ".site-search-result-kind", text: "CVE"
      find(".site-search-results a[href='/about#fixture-cve']").click
      assert_current_path "/about"
      assert_equal "fixture-cve", URI.parse(page.current_url).fragment
      assert_selector "#cves[open] #fixture-cve"
    end
  end

  test "all matches are reachable and clearing the query leaves no instructional filler" do
    page.current_window.resize_to(390, 844)
    expected = SiteSearch.new.search("a").length
    assert_operator expected, :>, 20
    visit "/blog"
    open_search
    assert_selector "dialog .search-wrapper .search-clear-btn", count: 1, visible: :all
    assert_no_selector "[data-site-search-clear]"
    assert_equal "", find("[data-site-search-status]", visible: :all).text(:all)
    assert_no_selector ".site-search-results li"
    fill_in "site-search-palette-query", with: "a"
    assert_selector ".site-search-results li", count: expected
    assert_selector "[data-site-search-status]", text: "#{expected} results"
    assert_selector "[data-site-search-clear]:not([disabled])", count: 1
    before_scroll = search_rectangles
    results = find("[data-site-search-results]")
    scroll_style = page.evaluate_script(<<~JS)
      (() => {
        const results = document.querySelector('[data-site-search-results]');
        const style = getComputedStyle(results);
        return { scrollable: results.scrollHeight > results.clientHeight, overflow: style.overflowY, color: style.scrollbarColor };
      })()
    JS
    assert scroll_style["scrollable"], "Expected enough results to scroll"
    assert_includes %w[auto scroll], scroll_style["overflow"]
    assert_not_equal "auto", scroll_style["color"], "Expected the results scrollbar to use the site theme"
    find("[data-site-search-query]").send_keys(*Array.new(expected, :arrow_down))
    assert_selector ".site-search-results li:last-child a:focus"
    assert_operator results.evaluate_script("this.scrollTop"), :>, 0
    focused_visible = page.evaluate_script(<<~JS)
      (() => {
        const pane = document.querySelector('[data-site-search-results]').getBoundingClientRect();
        const link = document.activeElement.getBoundingClientRect();
        return link.top >= pane.top - 1 && link.bottom <= pane.bottom + 1;
      })()
    JS
    assert focused_visible, "Keyboard focus should scroll its result into view"
    assert_search_rectangles before_scroll, "after keyboard scrolling"

    find("[data-site-search-clear]").click
    assert_selector "[data-site-search-query]:focus"
    assert_equal "", find("[data-site-search-query]").value
    assert_no_selector ".site-search-results li"
    assert_equal "", find("[data-site-search-status]", visible: :all).text(:all)
    assert_no_selector "[data-site-search-clear]"
    assert_selector "[data-site-search-clear][hidden][disabled]", visible: :all
    assert_search_rectangles before_scroll, "after clearing results"
    assert_no_selector "dialog a[href='/search']", visible: :all
  end

  test "typing and deleting individual characters keeps the dialog and input still" do
    search = SiteSearch.new
    [ 390, 1440 ].each do |width|
      page.current_window.resize_to(width, 900)
      visit "/blog"
      open_search
      page.evaluate_script("document.fonts.ready.then(() => true)")
      input = find("[data-site-search-query]")
      baseline = search_rectangles
      save_search_screenshot("blank", width)

      query = ""
      "cptsx".each_char do |character|
        query += character
        input.send_keys(character)
        assert_search_results search.search(query).length
        assert_search_rectangles baseline, "typing #{query.inspect} at #{width}px"
        save_search_screenshot("results", width) if query == "c"
      end
      assert_no_selector ".site-search-results li"

      until query.empty?
        query = query.chop
        input.send_keys(:backspace)
        assert_search_results(query.empty? ? nil : search.search(query).length)
        assert_search_rectangles baseline, "deleting to #{query.inspect} at #{width}px"
      end
      assert_selector "[data-site-search-query]:focus"
      assert_no_selector "[data-site-search-clear]"
      find("[data-site-search-close]").click
    end
  end

  test "outside clicks dismiss search but input and interior padding clicks keep it open" do
    [ 390, 1440 ].each do |width|
      page.current_window.resize_to(width, 900)
      visit "/blog"
      trigger = find("#search-taskbar-button:not([disabled])")
      trigger.click
      assert_selector "dialog[open] [data-site-search-query]:focus"
      find("[data-site-search-query]").click
      assert_selector "dialog[open]"

      rectangle = search_rectangles.fetch("dialog")
      click_at rectangle["x"] + 6, rectangle["y"] + rectangle["height"] / 2
      assert_selector "dialog[open]", wait: 0
      click_at rectangle["x"] + rectangle["width"] / 2, rectangle["y"] + rectangle["height"] - 6
      assert_selector "dialog[open]", wait: 0

      click_at rectangle["x"] - 6, rectangle["y"] + rectangle["height"] / 2
      assert_no_selector "dialog[open]"
      assert_selector "#search-taskbar-button:focus"
      assert_equal "false", trigger["aria-expanded"]
    end
  end

  test "the global overlay and taskbar fit compact and desktop screens" do
    [ 320, 390, 1440 ].each do |width|
      page.current_window.resize_to(width, 900)
      visit "/blog"
      open_search
      assert_selector "#site-search-dialog[open][aria-labelledby='site-search-dialog-title']"
      assert_selector "#site-search-dialog-title .site-search-title-icon[aria-hidden='true']"
      assert_selector "#site-search-dialog-title .sr-only", text: "Search", visible: :all
      label_dimensions = find("#site-search-dialog-title .sr-only", visible: :all).evaluate_script("({ width: this.getBoundingClientRect().width, height: this.getBoundingClientRect().height })")
      assert_operator label_dimensions["width"], :<=, 1
      assert_operator label_dimensions["height"], :<=, 1
      assert_no_selector "#site-search-description", visible: :all
      assert_no_selector "dialog[aria-describedby]", visible: :all
      assert_no_selector "[data-site-search-form] button[type='submit'], [data-site-search-form] input[type='submit']", visible: :all
      assert page.evaluate_script("document.querySelector('dialog').scrollWidth <= document.querySelector('dialog').clientWidth")
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width + 1
      save_search_screenshot("blank", width)
      find("[data-site-search-close]").click
      assert_selector "#search-taskbar-button:focus"
    end
  end

  test "result snippets and card padding navigate through one full-card link" do
    with_search_article do |post|
      [ 390, 1440 ].each do |width|
        page.current_window.resize_to(width, 900)
        [ :snippet, :padding ].each do |target|
          visit "/blog"
          open_search
          fill_in "site-search-palette-query", with: "bodyneedle"
          card = find(".site-search-results > li > a.site-search-result-link[href='#{post[:link]}#search-destination']")
          assert_selector ".site-search-results > li > a", count: 1
          assert_selector ".site-search-result-link .site-search-result-title", text: "Search destination"
          assert_no_selector ".site-search-result-link a, .site-search-result-link button", visible: :all

          if target == :snippet
            card.find("p", text: "Only the article body contains bodyneedle.").click
          else
            rectangle = card.evaluate_script("({ x: this.getBoundingClientRect().x, y: this.getBoundingClientRect().y, height: this.getBoundingClientRect().height })")
            click_at rectangle["x"] + 6, rectangle["y"] + rectangle["height"] / 2
          end
          assert_current_path post[:link]
          assert_equal "search-destination", URI.parse(page.current_url).fragment
          assert_selector ".markdown-content [id='search-destination']", visible: :all
        end
      end
    end
  end

  test "real pointer hover highlights the whole result card and close button" do
    with_search_article do
      page.current_window.resize_to(1440, 900)
      visit "/blog"
      open_search
      fill_in "site-search-palette-query", with: "bodyneedle"
      card = find(".site-search-result-link")
      input = find("[data-site-search-query]")
      input.hover
      card_background = card.style("background-color").fetch("background-color")
      card.find("p").hover
      assert_selector ".site-search-result-link:hover"
      assert_not_equal card_background, card.style("background-color").fetch("background-color"),
                       "Hovering the snippet should highlight its full result link"
      save_search_screenshot("result-hover", 1440)

      input.hover
      close_button = find("[data-site-search-close]")
      close_background = close_button.style("background-color").fetch("background-color")
      close_button.hover
      assert_selector "[data-site-search-close]:hover"
      assert_not_equal close_background, close_button.style("background-color").fetch("background-color"),
                       "The close button should visibly respond to real pointer hover"
      save_search_screenshot("close-hover", 1440)
      close_button.click
      assert_no_selector "dialog[open]"
      assert_selector "#search-taskbar-button:focus"
    end
  end

  private

  def open_search
    find("#search-taskbar-button:not([disabled])[aria-keyshortcuts]").click
    assert_selector "#site-search-dialog[open] [data-site-search-query]:focus"
  end

  def with_search_article
    repository = fixture_content_repository
    post = repository.blog_posts.first
    post[:body] = "# Search destination\n\nOnly the article body contains bodyneedle.\n\n# Another section\n\nThe otherneedle appears in a different section."
    with_stubbed_content_repository(repository) { yield post }
  end

  def index_request_count
    page.evaluate_script("performance.getEntriesByType('resource').filter(entry => new URL(entry.name).pathname === '/search/index.json').length")
  end

  def search_rectangles
    page.evaluate_script(<<~JS)
      (() => Object.fromEntries([
        ['dialog', '[data-site-search-dialog]'], ['input', '[data-site-search-query]']
      ].map(([name, selector]) => {
        const { x, y, width, height } = document.querySelector(selector).getBoundingClientRect();
        return [name, { x, y, width, height }];
      })))()
    JS
  end

  def assert_search_rectangles(expected, context)
    search_rectangles.each do |element, rectangle|
      rectangle.each do |dimension, value|
        assert_in_delta expected.fetch(element).fetch(dimension), value, 1, "#{element} #{dimension} moved #{context}"
      end
    end
  end

  def assert_search_results(count)
    if count.nil?
      assert_selector "[data-site-search-status]", text: /\A\z/, visible: :all
    elsif count.zero?
      assert_selector "[data-site-search-status]", text: "No results match all those words."
    else
      assert_selector "[data-site-search-status]", text: "#{count} #{count == 1 ? 'result' : 'results'}", exact_text: true
    end
    assert_selector "[data-site-search-dialog][aria-busy='false']", visible: :all
    assert_selector ".site-search-results li", count: count || 0, visible: :all
  end

  def click_at(x, y)
    page.driver.browser.action.move_to_location(x.round, y.round).click.perform
  end

  def save_search_screenshot(state, width)
    directory = Rails.root.join("tmp/search-refinement")
    FileUtils.mkdir_p(directory)
    save_screenshot(directory.join("search-#{state}-#{width}.png"))
  end
end
