require "application_system_test_case"

class AccessibilityTest < ApplicationSystemTestCase
  test "representative pages have no confirmed accessibility violations" do
    page.current_window.resize_to(390, 900)
    [ "/", "/timeline", "/about", "/blog/java-strings" ].each do |path|
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

  test "open desktop terminal has no confirmed accessibility violations" do
    page.current_window.resize_to(1440, 900)
    visit "/blog"
    page.execute_script("localStorage.removeItem('terminal-open')")
    visit "/blog"
    assert_selector "#terminal-taskbar-button[data-initialized='true']"
    find("#terminal-taskbar-button").click
    assert_selector "#terminal-container:not([hidden]):not([inert]) .xterm-rows", text: "adrian@my-space", wait: 30
    assert_selector ".xterm-helper-textarea", visible: :all
    assert_accessible_state("blog-terminal-open-desktop")
  ensure
    page.execute_script("localStorage.removeItem('terminal-open')")
  end

  private

  def assert_accessible_state(state)
    axe = Rails.root.join("node_modules/axe-core/axe.min.js")
    assert axe.file?, "Run npm ci before the browser suite to install axe-core"
    page.execute_script(axe.read)
    report = page.driver.browser.execute_async_script(<<~JS)
      const done = arguments[arguments.length - 1];
      axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa'] } })
        .then(result => done({ violations: result.violations, incomplete: result.incomplete }))
        .catch(error => done({ error: error.message }));
    JS
    directory = Rails.root.join("tmp/a11y")
    FileUtils.mkdir_p(directory)
    File.write(directory.join("#{state}.json"), JSON.pretty_generate(report))
    assert_nil report["error"], "#{state}: axe did not complete: #{report['error']}"
    assert report.fetch("violations").empty?, "#{state}: #{report.fetch('violations').map { |v| [ v['id'], v['nodes'].map { |n| n['target'] } ] }.inspect}"
  end
end
