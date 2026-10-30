require "application_system_test_case"

class YearFilterTest < ApplicationSystemTestCase
  test "year popup retains native pointer keyboard and history behavior" do
    page.current_window.resize_to(1440, 1000)
    visit "/timeline"
    assert_selector ".content-filter-panel[data-initialized='true']"
    select = find("[data-filter-year]")
    years = select.all("option", visible: :all).map(&:value).reject(&:empty?)
    assert_operator years.length, :>=, 2
    assert_equal "year", select[:name]
    assert_selector "label[for='#{select[:id]}']", text: /year/i
    assert_equal true, page.evaluate_script("CSS.supports('appearance', 'base-select') && CSS.supports('selector(::picker(select))')")

    select.click
    assert_selector "[data-filter-year]:open"
    save_picker_screenshot("desktop")

    page.driver.browser.action.move_to(select.find("option[value='#{years.first}']").native).click.perform
    assert_no_selector "[data-filter-year]:open"
    assert_equal years.first, select.value
    assert_includes page.current_url, "year=#{years.first}"
    first_url = page.current_url
    assert_equal select[:id], page.evaluate_script("document.activeElement.id")

    page.driver.browser.action.send_keys(:space).perform
    assert_selector "[data-filter-year]:open"
    page.driver.browser.action.send_keys(:home, :arrow_down, :arrow_down, :enter).perform
    assert_no_selector "[data-filter-year]:open"
    assert_equal years.second, select.value
    assert_includes page.current_url, "year=#{years.second}"
    assert_equal select[:id], page.evaluate_script("document.activeElement.id")
    page.go_back
    assert_equal first_url, page.current_url
    assert_equal years.first, select.value

    page.driver.browser.action.send_keys(:space).perform
    assert_selector "[data-filter-year]:open"
    page.driver.browser.action.send_keys(:arrow_down, :escape).perform
    assert_no_selector "[data-filter-year]:open"
    assert_equal years.first, select.value
    assert_equal first_url, page.current_url
    assert_equal select[:id], page.evaluate_script("document.activeElement.id")
  end

  test "mobile year popup stays in the viewport and allows pointer selection" do
    page.current_window.resize_to(390, 800)
    visit "/timeline"
    assert_selector ".content-filter-panel[data-initialized='true']"
    select = find("[data-filter-year]")
    year = select.all("option", visible: :all).find { |option| option.value.present? }.value
    select.click
    assert_selector "[data-filter-year]:open"
    popup = page.evaluate_script(<<~JS)
      (() => {
        const select = document.querySelector('[data-filter-year]');
        const bounds = [...select.options].map(option => {
          const rect = option.getBoundingClientRect();
          return { left: rect.left, right: rect.right, top: rect.top, bottom: rect.bottom };
        });
        const style = getComputedStyle(select, '::picker(select)');
        const padding = parseFloat(style.paddingTop) + parseFloat(style.paddingBottom);
        const border = parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth);
        const height = parseFloat(style.height) + (style.boxSizing === 'border-box' ? 0 : padding + border);
        const top = bounds[0].top - parseFloat(style.paddingTop) - parseFloat(style.borderTopWidth);
        return { bounds, top, bottom: top + height };
      })()
    JS
    bounds = popup.fetch("bounds")
    viewport = page.evaluate_script("({ width: innerWidth, height: innerHeight })")
    assert_operator bounds.map { |rect| rect["left"] }.min, :>=, 0
    assert_operator bounds.map { |rect| rect["right"] }.max, :<=, viewport["width"]
    assert_operator popup["top"], :>=, 0
    assert_operator popup["bottom"], :<=, viewport["height"]
    save_picker_screenshot("mobile")
    page.driver.browser.action.move_to(select.find("option[value='#{year}']").native).click.perform
    assert_no_selector "[data-filter-year]:open"
    assert_equal year, select.value
    assert_includes page.current_url, "year=#{year}"

    # Offscreen options belong to the picker's scrollable content, not its
    # viewport bounds. The oldest option must still scroll into view and work.
    select.click
    assert_selector "[data-filter-year]:open"
    oldest = select.all("option", visible: :all).last
    page.execute_script("arguments[0].scrollIntoView({ block: 'nearest' })", oldest)
    oldest_bounds = page.evaluate_script("arguments[0].getBoundingClientRect().toJSON()", oldest)
    assert_operator oldest_bounds["top"], :>=, 0
    assert_operator oldest_bounds["bottom"], :<=, viewport["height"]
    page.driver.browser.action.move_to(oldest.native).click.perform
    assert_no_selector "[data-filter-year]:open"
    assert_equal oldest.value, select.value
    assert_includes page.current_url, "year=#{oldest.value}"
  end

  test "classic select fallback preserves year filtering and no-script content remains readable" do
    visit "/timeline"
    assert_selector ".content-filter-panel[data-initialized='true']"
    page.execute_script(<<~JS)
      const style = document.createElement('style');
      style.textContent = '[data-filter-year], [data-filter-year]::picker(select) { appearance: auto !important; }';
      document.head.appendChild(style);
    JS
    select = find("[data-filter-year]")
    year = select.all("option", visible: :all).find { |option| option.value.present? }.value
    assert_equal "auto", page.evaluate_script("getComputedStyle(document.querySelector('[data-filter-year]')).appearance")
    select.select(year)
    assert_equal year, select.value
    assert_includes page.current_url, "year=#{year}"

    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
    visit "/timeline"
    assert_no_selector ".content-filter-panel"
    assert_selector ".timeline-item", minimum: 1
    assert_text "All entries are shown. Use your browser’s Find command to search this page."
  ensure
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
  end

  private

  def save_picker_screenshot(size)
    directory = Rails.root.join("tmp/screenshots")
    FileUtils.mkdir_p(directory)
    page.save_screenshot(directory.join("year-picker-#{size}.png"))
  end
end
