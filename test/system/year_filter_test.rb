require "application_system_test_case"

class YearFilterTest < ApplicationSystemTestCase
  test "year popup matches the rounded dark controls and retains native input behavior" do
    page.current_window.resize_to(1440, 1000)
    visit "/timeline"
    assert_selector ".content-filter-panel[data-initialized='true']"
    select = find(".content-filter-select")
    years = select.all("option", visible: :all).map(&:value).reject(&:empty?)
    assert_operator years.length, :>=, 2
    assert_equal "year", select[:name]
    assert_selector "label[for='#{select[:id]}']", text: /year/i
    assert_equal true, page.evaluate_script("CSS.supports('appearance', 'base-select') && CSS.supports('selector(::picker(select))')")

    select.click
    assert_selector ".content-filter-select:open"
    styles = page.evaluate_script(<<~JS)
      (() => {
        const select = document.querySelector('.content-filter-select');
        const picker = getComputedStyle(select, '::picker(select)');
        const control = getComputedStyle(select);
        return {
          appearance: control.appearance, radius: picker.borderTopLeftRadius,
          controlRadius: control.borderTopLeftRadius, background: picker.backgroundColor,
          borderWidth: picker.borderTopWidth, overflow: picker.overflowY
        };
      })()
    JS
    assert_equal "base-select", styles["appearance"]
    assert_equal styles["controlRadius"], styles["radius"]
    assert_operator styles["radius"].to_f, :>=, 10
    assert_equal "rgb(10, 31, 54)", styles["background"]
    assert_equal "1px", styles["borderWidth"]
    assert_equal "auto", styles["overflow"]
    save_picker_screenshot("desktop")

    page.driver.browser.action.move_to(select.find("option[value='#{years.first}']").native).click.perform
    assert_no_selector ".content-filter-select:open"
    assert_equal years.first, select.value
    assert_includes page.current_url, "year=#{years.first}"
    first_url = page.current_url
    assert_equal select[:id], page.evaluate_script("document.activeElement.id")

    page.driver.browser.action.send_keys(:space).perform
    assert_selector ".content-filter-select:open"
    page.driver.browser.action.send_keys(:home, :arrow_down, :arrow_down, :enter).perform
    assert_no_selector ".content-filter-select:open"
    assert_equal years.second, select.value
    assert_includes page.current_url, "year=#{years.second}"
    assert_equal select[:id], page.evaluate_script("document.activeElement.id")
    page.go_back
    assert_equal first_url, page.current_url
    assert_equal years.first, select.value

    page.driver.browser.action.send_keys(:space).perform
    assert_selector ".content-filter-select:open"
    page.driver.browser.action.send_keys(:arrow_down, :escape).perform
    assert_no_selector ".content-filter-select:open"
    assert_equal years.first, select.value
    assert_equal first_url, page.current_url
    assert_equal select[:id], page.evaluate_script("document.activeElement.id")
  end

  test "mobile year popup stays in the viewport and allows pointer selection" do
    page.current_window.resize_to(390, 800)
    visit "/timeline"
    assert_selector ".content-filter-panel[data-initialized='true']"
    select = find(".content-filter-select")
    year = select.all("option", visible: :all).find { |option| option.value.present? }.value
    select.click
    assert_selector ".content-filter-select:open"
    bounds = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.content-filter-select option')].map(option => {
        const rect = option.getBoundingClientRect();
        return { left: rect.left, right: rect.right, top: rect.top, bottom: rect.bottom };
      });
    JS
    viewport = page.evaluate_script("({ width: innerWidth, height: innerHeight })")
    assert_operator bounds.map { |rect| rect["left"] }.min, :>=, 0
    assert_operator bounds.map { |rect| rect["right"] }.max, :<=, viewport["width"]
    assert_operator bounds.first["top"], :>=, 0
    assert_operator bounds.last["bottom"], :<=, viewport["height"]
    save_picker_screenshot("mobile")
    page.driver.browser.action.move_to(select.find("option[value='#{year}']").native).click.perform
    assert_no_selector ".content-filter-select:open"
    assert_equal year, select.value
    assert_includes page.current_url, "year=#{year}"
  end

  test "classic select fallback preserves year filtering and no-script content remains readable" do
    visit "/timeline"
    assert_selector ".content-filter-panel[data-initialized='true']"
    page.execute_script(<<~JS)
      const style = document.createElement('style');
      style.textContent = '.content-filter-select, .content-filter-select::picker(select) { appearance: auto !important; }';
      document.head.appendChild(style);
    JS
    select = find(".content-filter-select")
    year = select.all("option", visible: :all).find { |option| option.value.present? }.value
    assert_equal "auto", page.evaluate_script("getComputedStyle(document.querySelector('.content-filter-select')).appearance")
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
