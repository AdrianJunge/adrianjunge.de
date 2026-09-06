require "application_system_test_case"

class RefactoringTest < ApplicationSystemTestCase
  test "printed articles retain visible titles and unclipped code without interactive chrome" do
    visit "/blog/java-strings"
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    styles = page.evaluate_script(<<~JS)
      (() => {
        const pre = document.querySelector('.code-block pre');
        const line = pre.querySelector('.code-line');
        return {
          titleColor: getComputedStyle(document.querySelector('h1')).color,
          overflow: getComputedStyle(pre).overflow,
          whiteSpace: getComputedStyle(pre).whiteSpace,
          lineDisplay: getComputedStyle(line).display,
          lineNumbers: getComputedStyle(line, '::before').display,
          lineWhiteSpace: getComputedStyle(line.querySelector('.code-line-content')).whiteSpace,
          width: pre.getBoundingClientRect().width,
          articleWidth: document.querySelector('.writeup-container').getBoundingClientRect().width
        };
      })()
    JS
    assert_equal "rgb(0, 0, 0)", styles["titleColor"]
    assert_equal "visible", styles["overflow"]
    assert_equal "pre-wrap", styles["whiteSpace"]
    assert_equal "pre-wrap", styles["lineWhiteSpace"]
    assert_equal "block", styles["lineDisplay"]
    assert_equal "none", styles["lineNumbers"]
    assert_operator styles["width"], :>=, styles["articleWidth"] * 0.95
    assert_no_selector ".top-taskbar"
    assert_no_selector ".copy-btn"
    assert_no_selector ".article-progress"
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
  end

  test "timeline search does not index article body text" do
    visit "/timeline"
    assert_selector ".timeline-item", minimum: 1
    find("[data-filter-search='timeline']").fill_in(with: "jcmd")
    assert_selector "[data-filter-empty='timeline']"
    assert_no_selector ".timeline-item:not([hidden])"
  end

  test "default mobile filters reveal results promptly and original tags toggle without duplicate reset chips" do
    page.current_window.resize_to(390, 900)
    visit "/timeline"
    assert_selector ".content-filter-panel:not([hidden])"
    assert_no_selector ".content-filter-more[open]"
    top = page.evaluate_script("document.querySelector('.timeline-item').getBoundingClientRect().top + window.scrollY")
    assert_operator top, :<, 1100, "the first result should remain close to the compact controls"
    find(".content-filter-more > summary").click
    chip = find(".content-filter-more .filter-chip", match: :first)
    chip.click
    assert_equal "true", chip["aria-pressed"]
    assert_no_selector "[data-filter-selected]", visible: :all
    find(".content-filter-more > summary").click
    selected_url = page.current_url
    find(".content-filter-more > summary").click
    chip.click
    assert_equal "false", chip["aria-pressed"]
    page.go_back
    assert_equal selected_url, page.current_url
    assert_equal "true", chip["aria-pressed"]
  end

  test "unknown and legacy query filters remain understandable and removable" do
    visit "/timeline?tag=does-not-exist&year=1900"
    assert_selector "[data-filter-empty='timeline']"
    assert_no_selector "[data-filter-selected]", visible: :all
    assert_equal "", find(".content-filter-select").value
    find("[data-filter-reset='timeline']").click
    assert_selector ".timeline-item", minimum: 1
    visit "/timeline?tag=Medium"
    assert_selector ".content-filter-panel [data-filter-tag='difficulty:medium'][aria-pressed='true']", text: "Medium", visible: :all
    assert_includes page.current_url, "difficulty%3Amedium"
    assert_selector ".timeline-item[data-filter-tags*='difficulty:medium']", minimum: 1
    visit "/timeline?tag=severity%3Amedium"
    assert_selector ".content-filter-panel [data-filter-tag='severity:medium'][aria-pressed='true']", text: "Medium", visible: :all
    assert_selector ".timeline-item[data-filter-tags*='severity:medium']", minimum: 1
  end

  test "mixed Medium difficulty and severity fixtures combine independently with year and search" do
    visit "/timeline"
    assert_selector ".content-filter-panel[data-initialized='true']"
    find(".content-filter-more > summary").click
    difficulty = ".content-filter-panel [data-filter-tag='difficulty:medium']"
    severity = ".content-filter-panel [data-filter-tag='severity:medium']"
    assert_selector difficulty, text: /^Medium$/
    assert_selector severity, text: /^Medium$/
    years = all(".content-filter-select option").map(&:value).reject(&:empty?).first(2)
    assert_equal 2, years.length

    # Replace only this browser page's card metadata with a small controlled fixture.
    # The real initialized controls and record-refresh/filtering code stay in use.
    page.execute_script(<<~JS, years)
      const [currentYear, otherYear] = arguments[0];
      const cards = [...document.querySelectorAll('[data-filter-card="timeline"]')];
      cards.forEach(card => {
        card.dataset.filterText = '';
        card.dataset.filterTags = '';
        card.dataset.filterYears = '';
      });
      const fixtures = [
        ['difficulty-only', 'quasar', 'difficulty:medium', currentYear],
        ['severity-only', 'quasar', 'severity:medium', currentYear],
        ['both-current', 'quasar', 'difficulty:medium|severity:medium', currentYear],
        ['both-other-year', 'quasar', 'difficulty:medium|severity:medium', otherYear],
        ['both-other-query', 'nebula', 'difficulty:medium|severity:medium', currentYear]
      ];
      fixtures.forEach(([id, query, tags, year], index) => {
        Object.assign(cards[index].dataset, {
          contractFixture: id, filterText: query, filterTags: tags, filterYears: year
        });
      });
    JS
    visible_ids = -> { all(".timeline-item[data-contract-fixture]").map { |card| card["data-contract-fixture"] }.sort }
    find("[data-filter-search='timeline']").fill_in(with: "quasar")
    find(".content-filter-select").select(years.first)
    assert_selector ".timeline-item:not([hidden])", count: 3
    find(difficulty).click
    assert_selector ".timeline-item:not([hidden])", count: 2
    assert_equal %w[both-current difficulty-only], visible_ids.call
    find(severity).click
    assert_selector ".timeline-item:not([hidden])", count: 1
    assert_equal %w[both-current], visible_ids.call
    assert_selector ".content-filter-panel [data-filter-tag][aria-pressed='true']", count: 2, text: /Medium/
    assert_no_selector "[data-filter-selected]", visible: :all
    params = Rack::Utils.parse_query(URI.parse(page.current_url).query)
    assert_equal %w[difficulty:medium severity:medium], Array(params["tag"]).sort
    assert_equal years.first, params["year"]
    assert_equal "quasar", params["q"]
    find(difficulty).click
    assert_selector ".timeline-item:not([hidden])", count: 2
    assert_equal %w[both-current severity-only], visible_ids.call
    find(".content-filter-select").select(years.last)
    assert_selector ".timeline-item:not([hidden])", count: 1
    assert_equal %w[both-other-year], visible_ids.call
    find("[data-filter-search='timeline']").fill_in(with: "nebula")
    assert_selector "[data-filter-empty='timeline']"
    find(".content-filter-select").select(years.first)
    assert_selector ".timeline-item:not([hidden])", count: 1
    assert_equal %w[both-other-query], visible_ids.call
  end

  test "optional terminal assets load on activation and focus returns on Escape" do
    page.current_window.resize_to(1440, 900)
    visit "/blog"
    page.execute_script("localStorage.removeItem('terminal-open')")
    visit "/blog"
    assert_selector ".content-filter-panel:not([hidden])"
    assert_no_selector "link[rel='stylesheet'][href*='terminal-']", visible: :all
    requests = page.evaluate_script("performance.getEntriesByType('resource').map(entry => entry.name)")
    assert_empty requests.grep(/xterm|typed\.module|terminal-[a-f0-9]+\.js/)
    assert_equal true, page.evaluate_script("document.getElementById('terminal-container').inert")
    find("#terminal-taskbar-button").click
    assert_selector ".xterm-helper-textarea", wait: 20, visible: :all
    assert_selector "#terminal-taskbar-button[aria-expanded='true']"
    assert_equal true, page.evaluate_script("document.getElementById('terminal-container').contains(document.activeElement)")
    page.driver.browser.action.send_keys(:escape).perform
    assert_selector "#terminal-container[hidden][inert]", visible: :all
    assert_equal "terminal-taskbar-button", page.evaluate_script("document.activeElement.id")
    find("#terminal-taskbar-button").click
    assert_selector ".xterm", count: 1
    assert_selector "link[rel='stylesheet'][href*='terminal-']", count: 1, visible: :all
    find("#maximize-terminal").click
    assert_selector "#terminal-container.terminal-maximized"
    find("#maximize-terminal").click
    assert_no_selector "#terminal-container.terminal-maximized"
    find("#minimize-terminal").click
    assert_selector "#terminal-container[hidden][inert]", visible: :all
    find("#terminal-taskbar-button").click
    assert_selector ".xterm", count: 1
    find("#close-terminal").click
  end

  test "restoring terminal preference does not take focus or show it on mobile" do
    page.current_window.resize_to(1440, 900)
    visit "/blog"
    page.execute_script("localStorage.setItem('terminal-open', 'true')")
    visit "/blog"
    assert_selector ".xterm", wait: 20
    assert_equal false, page.evaluate_script("document.getElementById('terminal-container').contains(document.activeElement)")
    page.current_window.resize_to(390, 900)
    assert_selector "#terminal-container[hidden][inert]", visible: :all
    page.execute_script("localStorage.removeItem('terminal-open')")
  end

  test "optional dependency failure leaves filters and ordinary navigation usable" do
    page.current_window.resize_to(1440, 900)
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "*xterm*" ])
    visit "/blog"
    page.execute_script("localStorage.removeItem('terminal-open')")
    find("#terminal-taskbar-button").click
    assert_selector "#terminal-status", text: /could not load/, wait: 20
    find("[data-filter-search='blogs']").fill_in(with: "no-matching-published-post")
    assert_selector "[data-filter-empty='blogs']"
    find(".taskbar-link[href='/about']").click
    assert_selector "main.aboutme-page"
  ensure
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
  end

  test "flagged equations render once and survive narrow-width relayout" do
    visit "/blog/climbing-stairs"
    assert_selector "[data-has-math='true'] .markdown-content mjx-container", minimum: 1, wait: 30
    count = all(".markdown-content mjx-container").length
    page.current_window.resize_to(390, 900)
    assert_selector ".markdown-content mjx-container", count: count
    assert_no_selector ".code-block mjx-container", visible: :all
    resources = page.evaluate_script("performance.getEntriesByType('resource').map(entry => entry.name).filter(name => name.includes('mathjax'))")
    assert resources.any? { |name| name.include?("mathjax-newcm-font@4.1.3") }
    assert resources.all? { |name| name.include?("@4.1.3/") || name.include?("/assets") }, resources.inspect
    assert_operator page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), :<=, 1
  end

  test "clipboard feedback preserves rendered code exactly and handles denial" do
    visit "/blog/java-strings"
    expected = page.evaluate_script("document.querySelector('.code-block code').textContent")
    page.execute_script("Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: text => { window.copiedCode = text; return Promise.resolve(); } } })")
    find(".copy-btn", match: :first).click
    assert_selector ".copy-btn", text: "Copied", match: :first
    assert_equal expected, page.evaluate_script("window.copiedCode")
    assert_no_selector ".copy-btn[data-code]", visible: :all
    page.execute_script("navigator.clipboard.writeText = () => Promise.reject(new Error('denied'))")
    find(".copy-btn", match: :first).click
    assert_selector ".copy-status", text: /Select the code/, visible: :all, match: :first
  end

  test "unflagged articles avoid MathJax and motion preference keeps meaningful text" do
    visit "/blog/java-strings"
    assert_no_selector "script[src*='mathjax']", visible: :all
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    visit "/"
    assert_selector "#typing", text: "Politely asking software uncomfortable questions."
    requests = page.evaluate_script("performance.getEntriesByType('resource').map(entry => entry.name)")
    assert_empty requests.grep(/typed\.module/)
    assert_equal "none", page.evaluate_script("getComputedStyle(document.querySelector('.landing-profile-image')).animationName")
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "skip navigation targets a single main region and shared chrome" do
    visit "/blog"
    assert_selector "main#main-content", count: 1
    assert_selector "#top-taskbar", count: 1
    assert_selector "#terminal-container", count: 1, visible: :all
    page.execute_script("document.querySelector('.skip-link').focus()")
    find(".skip-link").send_keys(:enter)
    assert_equal "main-content", page.evaluate_script("document.activeElement.id")
  end
end
