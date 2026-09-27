require "application_system_test_case"

class AccessibilityTest < ApplicationSystemTestCase
  test "representative pages have no confirmed accessibility violations" do
    page.current_window.resize_to(390, 900)
    [ "/", "/timeline", "/about", "/blog/java-strings", "/blog/java-strngs" ].each do |path|
      visit path
      assert_accessible_state("#{path.parameterize.presence || 'home'}-default-mobile")
    end
  end

  test "expanded filters and selected tags have no confirmed accessibility violations" do
    page.current_window.resize_to(390, 900)
    visit "/timeline"
    find(".content-filter-more > summary").click
    assert_selector ".content-filter-more[open]"
    find(".content-filter-more .filter-chip:not(.is-uncombinable)", match: :first).click
    assert_selector ".content-filter-panel .filter-chip[aria-pressed='true']", count: 1
    assert_no_selector "[data-filter-selected]", visible: :all
    assert_accessible_state("timeline-more-filters-open-selected-mobile")
  end

  test "expanded About supporting details have no confirmed accessibility violations" do
    page.current_window.resize_to(390, 900)
    visit "/about"
    find("#cves > summary").click
    assert_selector "#cves[open]"
    find("#cves .profile-card-details > summary", match: :first).click
    assert_selector "#cves .profile-card-details[open] .aboutme-card-body"
    assert_accessible_state("about-supporting-details-open-mobile")
  end

  test "open site search with results has no confirmed accessibility violations" do
    page.current_window.resize_to(390, 900)
    visit "/blog"
    find("[data-site-search-open][aria-keyshortcuts]", match: :first).click
    fill_in "site-search-palette-query", with: "Fibonacci"
    assert_selector "dialog[open] .site-search-results a", minimum: 1
    assert_accessible_state("site-search-dialog-results-mobile")
  end

  private

  def assert_accessible_state(state)
    axe = Rails.root.join("node_modules/axe-core/axe.min.js")
    assert axe.file?, "Run npm ci before the browser suite to install axe-core"
    page.execute_script(axe.read)
    report = page.driver.browser.execute_async_script(<<~JS)
      const done = arguments[arguments.length - 1];
      axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa'] } })
        .then(result => done({
          schema: 1,
          capturedAt: new Date().toISOString(),
          path: location.pathname,
          viewport: { width: innerWidth, height: innerHeight },
          axeVersion: result.testEngine.version,
          violations: result.violations,
          incomplete: result.incomplete
        }))
        .catch(error => done({ error: error.message }));
    JS
    directory = Rails.root.join("tmp/a11y")
    FileUtils.mkdir_p(directory)
    File.write(directory.join("#{state}.json"), JSON.pretty_generate(report))
    assert_nil report["error"], "#{state}: axe did not complete: #{report['error']}"
    # axe cannot resolve aria-controls on a closed native dialog in the rendered
    # tree. Check the actual DOM reference, and audit the open dialog separately.
    assert_selector "#site-search-dialog", visible: :all
    assert_equal "site-search-dialog", find("#search-taskbar-button")["aria-controls"]
    assert report.fetch("violations").empty?, "#{state}: #{report.fetch('violations').map { |v| [ v['id'], v['nodes'].map { |n| n['target'] } ] }.inspect}"
  end
end
