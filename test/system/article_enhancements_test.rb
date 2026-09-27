require "application_system_test_case"

class ArticleEnhancementsTest < ApplicationSystemTestCase
  test "contents marker reaches a clicked section only after smooth scrolling there" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "no-preference" } ])
    [ 1440, 390 ].each do |width|
      page.current_window.resize_to(width, 1000)
      visit "/blog/java-strings"
      assert_selector "#toc[data-toc-enhanced]"
      find(".article-toc-compact > summary").click if width == 390
      link = all(".toc-anchor")[4]
      fragment = URI.parse(link["href"]).fragment
      page.execute_script(<<~JS)
        document.addEventListener('click', event => {
          const link = event.target.closest('.toc-anchor');
          if (!link) return;
          window.tocClickState = {
            marked: link.classList.contains('active-anchor'),
            current: link.hasAttribute('aria-current')
          };
        }, { once: true });
      JS
      link.click
      assert_equal({ "marked" => false, "current" => false }, page.evaluate_script("window.tocClickState"))
      assert_selector ".toc-anchor.active-anchor[aria-current='location'][href='##{fragment}']", visible: :all
      assert_selector ".toc-anchor[aria-current]", count: 1, visible: :all
      position = page.evaluate_script(<<~JS)
        (() => {
          const heading = document.getElementById(#{fragment.to_json}).closest('h1,h2,h3,h4,h5,h6');
          const boundary = #{width} <= 1400 ? document.getElementById('toc') : document.getElementById('top-taskbar');
          return { top: heading.getBoundingClientRect().top, boundary: boundary.getBoundingClientRect().bottom };
        })()
      JS
      assert_in_delta position["boundary"] + 16, position["top"], 2
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "a scroll request that makes no progress does not mark its destination current" do
    page.current_window.resize_to(1440, 1000)
    visit "/blog/java-strings"
    assert_selector "#toc[data-toc-enhanced]"
    original = find(".toc-anchor[aria-current='location']")["href"]
    link = all(".toc-anchor")[4]
    fragment = URI.parse(link["href"]).fragment
    page.execute_script(<<~JS)
      window.originalTocScroll = window.scrollTo;
      window.scrollTo = () => {};
    JS
    link.click
    marked = page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      requestAnimationFrame(() => requestAnimationFrame(() => {
        done(document.querySelector('.toc-anchor[aria-current="location"]').getAttribute('href'));
      }));
    JS
    assert_equal "##{URI.parse(original).fragment}", marked
    assert_no_selector ".toc-anchor.active-anchor[href='##{fragment}']", visible: :all
    assert_equal fragment, page.evaluate_script("document.activeElement.querySelector('a[id]')?.id")
    page.execute_script("window.scrollTo = window.originalTocScroll")
    link.click
    assert_selector ".toc-anchor.active-anchor[aria-current='location'][href='##{fragment}']", visible: :all
  ensure
    page.execute_script("if (window.originalTocScroll) window.scrollTo = window.originalTocScroll")
  end

  test "active contents location follows navigation and scrolling at desktop and mobile widths" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    [ 1440, 390 ].each do |width|
      page.current_window.resize_to(width, 1000)
      visit "/blog/java-strings"
      assert_selector ".toc-anchor.active-anchor[aria-current='location']", count: 1, visible: :all
      find(".article-toc-compact > summary").click if width == 390
      link = all(".toc-anchor")[1]
      href = link["href"]
      link.click
      assert_selector ".toc-anchor.active-anchor[aria-current='location'][href='##{URI.parse(href).fragment}']", visible: :all
      assert_selector ".toc-anchor[aria-current]", count: 1, visible: :all
      page.execute_script("window.scrollTo({ top: 0, behavior: 'instant' })")
      assert_selector ".toc-item:first-child > .toc-anchor[aria-current='location']", visible: :all
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "article parent links name their fixed destination independently of referrer" do
    post = production_content_repository.ctf_posts.first
    event = production_content_repository.ctf_event(post[:directory])
    [ [ "/blog/java-strings", "/blog", "All blog posts" ], [ post[:link], "/ctf/#{post[:directory]}", "#{event[:name]} writeups" ] ].each do |path, destination, label|
      page.current_window.resize_to(1440, 1000)
      visit path
      assert_selector ".article-back-desktop[href='#{destination}'][aria-label='#{label}'][title='#{label}']"
      page.current_window.resize_to(390, 1000)
      assert_selector ".article-back-link[href='#{destination}']", text: label
      find(".article-back-link").click
      assert_current_path destination
    end
  end

  test "a blocked math renderer preserves source and recovers after explicit retry" do
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "*mathjax@*" ])
    visit "/blog/climbing-stairs"
    assert_selector "[data-math-notice]", text: /Equations are shown as TeX source/
    assert_selector ".markdown-content[data-math-state='failed']"
    assert_no_selector "mjx-container", visible: :all
    source = page.evaluate_script("document.querySelector('.writeup-container > .markdown-content').textContent")
    assert source.include?("\\["), "the fallback retains display equation delimiters"
    assert_selector ".toc-anchor[aria-current='location']", count: 1, visible: :all
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
    find("[data-math-retry]").click
    assert_selector ".markdown-content[data-math-state='ready'] mjx-container", minimum: 1, wait: 30
    assert_no_selector "[data-math-notice]"
    assert_no_selector ".code-block mjx-container", visible: :all
  ensure
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
  end
end
