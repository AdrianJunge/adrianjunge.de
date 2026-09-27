require "application_system_test_case"

class KeyboardNavigationTest < ApplicationSystemTestCase
  test "modified About and article jumps leave native browser navigation intact" do
    [ [ "/about", ".aboutme-stat[href='#cves']" ], [ "/blog/java-strings", ".toc-anchor" ] ].each do |path, selector|
      visit path
      assert_selector selector, visible: :all
      %w[ctrlKey metaKey shiftKey altKey].each do |modifier|
        intercepted = page.evaluate_script(<<~JS)
          (() => {
            const link = document.querySelector(#{selector.to_json});
            const event = new MouseEvent('click', { bubbles: true, cancelable: true, #{modifier}: true });
            let intercepted;
            link.addEventListener('click', click => {
              intercepted = click.defaultPrevented;
              click.preventDefault(); // Inspect the handler without opening a real tab/window.
            }, { once: true });
            link.dispatchEvent(event);
            return intercepted;
          })()
        JS
        assert_equal false, intercepted, "#{path}: #{modifier} must retain the browser's link behavior"
        assert_nil URI.parse(page.current_url).fragment
      end
    end
  end

  test "homepage metrics and full-card links keep their keyboard focus ring inside clipped containers" do
    [
      [ "/", ".landing-metric[href]" ],
      [ "/", ".content-card-hitbox" ],
      [ "/blog", ".content-card-hitbox" ],
      [ "/ctf", ".content-card-hitbox" ],
      [ "/timeline", ".content-card-hitbox" ]
    ].each do |path, selector|
      visit path
      tab_to(selector)
      focus = page.evaluate_script(<<~JS)
        (() => {
          const active = document.activeElement;
          const style = getComputedStyle(active);
          return {
            visible: active.matches(':focus-visible'),
            outlineStyle: style.outlineStyle,
            outlineWidth: parseFloat(style.outlineWidth),
            outlineOffset: parseFloat(style.outlineOffset)
          };
        })()
      JS
      assert focus["visible"], "#{path} #{selector} should show keyboard focus"
      assert_not_equal "none", focus["outlineStyle"], "#{path} #{selector} must not suppress its focus ring"
      assert_operator focus["outlineWidth"], :>, 0
      assert_operator focus["outlineOffset"] + focus["outlineWidth"], :<=, 0,
                      "#{path} #{selector} focus ring must fit inside its clipped card"
    end
  end

  test "About statistic jumps focus their native section summary and continue inside it" do
    visit "/about"
    [ "cves", "talks" ].each do |id|
      page.execute_script("document.activeElement.blur()")
      find(".aboutme-stat[href='##{id}']").send_keys(:enter)
      assert_selector "##{id}[open] > summary:focus"
      assert_equal id, URI.parse(page.current_url).fragment
      press_key(:tab)
      assert_selector "##{id} a:focus"
      assert_equal true, page.evaluate_script("!document.activeElement.closest('[hidden], [inert], details:not([open])')")
    end
  end

  test "keyboard filter reset returns to search and preserves URL and history behavior" do
    [ "/timeline", "/blog", "/ctf", "/ctf/cscg" ].each do |path|
      visit "#{path}?q=no-matching-published-post&tag=unknown&source=keyboard#main-content"
      assert_selector ".content-filter-panel[data-initialized='true']"
      assert_no_selector "[data-filter-search]:focus"
      filtered_url = page.current_url
      tab_to("[data-filter-reset]")
      press_key(:space)

      assert_selector "[data-filter-search]:focus"
      assert_equal "", find("[data-filter-search]").value
      assert_equal "", find("[data-filter-year]").value
      assert_no_selector "[data-filter-tag][aria-pressed='true']"
      assert_no_selector "[data-filter-reset].is-visible"
      assert_equal "source=keyboard", URI.parse(page.current_url).query
      assert_equal "main-content", URI.parse(page.current_url).fragment
      press_key(:tab)
      assert_selector "[data-filter-year]:focus"

      page.go_back
      assert_current_path filtered_url
      assert_equal "no-matching-published-post", find("[data-filter-search]").value
      assert_selector "[data-filter-reset].is-visible"
      assert_no_selector "[data-filter-search]:focus"
      page.go_forward
      assert_equal "", find("[data-filter-search]").value
      assert_no_selector "[data-filter-reset].is-visible"
      assert_no_selector "[data-filter-search]:focus"
    end
  end

  test "clearing only the search restores search focus and keeps selected tags" do
    visit "/timeline?q=joomla&tag=CVE"
    assert_selector ".content-filter-panel[data-initialized='true']"
    tab_to("[data-filter-clear]")
    press_key(:enter)

    assert_selector "[data-filter-search]:focus"
    assert_equal "", find("[data-filter-search]").value
    assert_selector "[data-filter-tag][aria-pressed='true']", minimum: 1
    assert_equal [ [ "tag", "CVE" ] ], URI.decode_www_form(URI.parse(page.current_url).query)
    press_key(:tab)
    assert_selector "[data-filter-year]:focus"
  end

  test "revealing hints focuses readable content and enables its links in the tab order" do
    repository = fixture_content_repository
    post = repository.ctf_posts.first
    post[:metadata]["optional"] = {
      "hints" => [ "Read the [background](/about) before continuing.", "A second useful hint." ]
    }

    with_stubbed_content_repository(repository) do
      visit post[:link]
      assert_selector ".writeup-hint-spoiler-content[inert][aria-hidden='true']", count: 2
      tab_to(".writeup-hint-spoiler:first-child [data-hint-spoiler-reveal]")
      press_key(:enter)

      first_content = ".writeup-hint-spoiler:first-child .writeup-hint-spoiler-content"
      assert_selector "#{first_content}[aria-hidden='false']:focus"
      assert_no_selector "#{first_content}[inert]"
      assert_equal "2px", page.evaluate_script("getComputedStyle(document.activeElement).outlineWidth")
      press_key(:tab)
      assert_selector "#{first_content} a:focus", text: "background"
      press_key(:tab)
      assert_selector ".writeup-hint-spoiler:nth-child(2) [data-hint-spoiler-reveal]:focus"
      press_key(:space)
      assert_selector ".writeup-hint-spoiler:nth-child(2) .writeup-hint-spoiler-content:focus"
      press_key(:tab)
      assert_equal true, page.evaluate_script(<<~JS)
        (() => {
          const content = document.querySelector('.writeup-hint-spoiler:nth-child(2) .writeup-hint-spoiler-content');
          const active = document.activeElement;
          return active.matches('a[href], button, summary') &&
            !active.closest('[hidden], [inert], [aria-hidden="true"]') &&
            Boolean(content.compareDocumentPosition(active) & Node.DOCUMENT_POSITION_FOLLOWING);
        })()
      JS
    end
  end

  test "hints remain readable and their links are keyboard reachable without JavaScript" do
    repository = fixture_content_repository
    post = repository.ctf_posts.first
    post[:metadata]["optional"] = {
      "hints" => [ "Read the [background](/about) before continuing.", "A second useful hint." ]
    }

    with_stubbed_content_repository(repository) do
      page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
      visit post[:link]
      assert_selector ".writeup-hint-spoiler-content", count: 2
      assert_no_selector ".writeup-hint-spoiler-content[inert], .writeup-hint-spoiler-content[aria-hidden='true']", visible: :all
      assert_no_selector "[data-hint-spoiler-reveal]"
      assert_equal "none", page.evaluate_script("getComputedStyle(document.querySelector('.writeup-hint-spoiler-content')).filter")
      tab_to(".writeup-hint-spoiler-content a")
      press_key(:enter)
      assert_current_path "/about"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
  end

  private

  def press_key(key)
    page.driver.browser.action.send_keys(key).perform
  end

  def tab_to(selector)
    80.times do
      return if page.has_selector?("#{selector}:focus", wait: 0)

      press_key(:tab)
    end
    assert_selector "#{selector}:focus"
  end
end
