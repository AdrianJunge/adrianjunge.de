require "application_system_test_case"
require_relative "../support/site_page_helpers"

class ContentCardAccessibilityTest < ApplicationSystemTestCase
  include SitePageHelpers

  test "author links have forgiving targets above the surrounding card link" do
    author_post, = first_ctf_post_with_author_link

    [ 390, 1280 ].each do |width|
      page.current_window.resize_to(width, 1000)

      [ "/", "/ctf/cscg", "/ctf/gpnctf", author_post[:link] ].each do |path|
        visit path
        assert_selector ".blog-post-author-link"
        targets = page.evaluate_script(<<~JS)
          [...document.querySelectorAll('.blog-post-author-link')].map(link => {
            link.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'instant' });
            const rect = link.getBoundingClientRect();
            const tapTarget = getComputedStyle(link, '::before');
            const offsets = [[0, 0], [0, -11], [0, 11], [-11, 0], [11, 0]];
            return {
              name: link.textContent.trim(),
              width: Math.max(rect.width, parseFloat(tapTarget.width) || 0),
              height: rect.height,
              hits: offsets.map(([x, y]) => link.contains(document.elementFromPoint(
                rect.left + rect.width / 2 + x, rect.top + rect.height / 2 + y
              )))
            };
          })
        JS

        targets.each do |target|
          description = "#{path} at #{width}px: #{target['name']}"
          assert_operator target["width"], :>=, 32, description
          assert_operator target["height"], :>=, 32, description
          assert target["hits"].all?, "#{description}: a near-center tap reached the surrounding card"
        end
        assert_accessibility_rules ".blog-post-author-link", "target-size"
      end
    end
  end

  test "recognition badges can be addressed by their visible labels" do
    page.current_window.resize_to(390, 1000)

    [ "/timeline", "/ctf/umdctf/A%20Minecraft%20Movie", "/ctf/gpnctf/Scanwich%20Station" ].each do |path|
      visit path
      badges = all(".writeup-winner-badge, .authored-challenge-badge", minimum: 1)
      badges.each do |badge|
        label = badge.find(".content-tag-label").text
        assert_includes badge.native.accessible_name.downcase, label.downcase, "#{path}: #{label}"
      end
      assert_accessibility_rules ".content-tag-action", "label-content-name-mismatch"
    end
  end

  private

  def assert_accessibility_rules(selector, *rules)
    axe = Rails.root.join("node_modules/axe-core/axe.min.js")
    assert axe.file?, "Run npm ci before the browser suite to install axe-core"
    page.execute_script(axe.read)
    report = page.driver.browser.execute_async_script(<<~JS, selector, rules)
      const [selector, rules, done] = arguments;
      axe.run({ include: [[selector]] }, { runOnly: { type: 'rule', values: rules } })
        .then(result => done({ violations: result.violations }))
        .catch(error => done({ error: error.message }));
    JS
    assert_nil report["error"], "axe did not complete: #{report['error']}"
    assert_empty report.fetch("violations"), "#{current_path}: #{report['violations'].inspect}"
  end
end
