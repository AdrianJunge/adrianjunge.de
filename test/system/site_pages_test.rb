require "application_system_test_case"

class SitePagesTest < ApplicationSystemTestCase
  PAGES = {
    "/" => "Welcome to my bug collection 🐛",
    "/ctf" => "CTF writeups",
    "/ctf/lactf" => "LACTF",
    "/ctf/lactf/Gamedev" => "Gamedev",
    "/blog" => "Blog",
    "/blog/htb-cpts" => "HTB CPTS",
    "/posts-timeline" => "Posts timeline"
  }.freeze

  test "main pages use the refreshed visual shells without horizontal overflow" do
    [ [ 1280, 1400 ], [ 390, 1200 ], [ 320, 1200 ] ].each do |width, height|
      page.current_window.resize_to(width, height)

      PAGES.each do |path, expected_text|
        visit path

        overflow = page.evaluate_script(<<~JS)
          document.documentElement.scrollWidth - document.documentElement.clientWidth
        JS

        assert_operator overflow, :<=, 1, "expected no horizontal overflow at #{width}px on #{path}"
        assert_text expected_text
        assert_selector "#terminal-container", visible: :all
        assert_selector ".taskbar-link[href='/about']", visible: :all
      end
    end
  end

  test "feed controls lift as complete buttons instead of moving only their icons" do
    {
      "/ctf" => [ ".ctf-rss-feed", ".ctf-rss-icon" ],
      "/blog" => [ ".blog-rss-feed", ".blog-rss-icon" ]
    }.each do |path, (button_selector, icon_selector)|
      visit path

      button = find(button_selector)
      find(icon_selector)
      page.driver.browser.action.move_to(button.native).perform

      transforms = page.evaluate_script(<<~JS)
        (() => {
          const button = document.querySelector("#{button_selector}");
          const icon = document.querySelector("#{icon_selector}");

          return {
            button: window.getComputedStyle(button).transform,
            icon: window.getComputedStyle(icon).transform
          };
        })()
      JS

      assert_not_equal "none", transforms["button"]
      assert_equal "none", transforms["icon"]
    end
  end

  test "compact landing keeps recent post spacing even and hides scroll affordance" do
    page.current_window.resize_to(390, 700)
    visit "/"

    assert_no_selector "#scroll-down-button", visible: :visible
    assert_selector ".landing-writeup-cards .blog-post-entry", count: 3

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const container = document.querySelector(".landing-writeup-cards");
        const scrollButton = document.querySelector("#scroll-down-button");
        const cards = [...document.querySelectorAll(".landing-writeup-cards .blog-post-entry")];
        const rects = cards.map((card) => card.getBoundingClientRect());

        return {
          display: window.getComputedStyle(container).display,
          scrollButtonDisplay: window.getComputedStyle(scrollButton).display,
          gaps: [
            Math.round(rects[1].top - rects[0].bottom),
            Math.round(rects[2].top - rects[1].bottom)
          ]
        };
      })()
    JS

    assert_equal "grid", metrics["display"]
    assert_equal "none", metrics["scrollButtonDisplay"]
    assert_operator metrics["gaps"].min, :>=, 15
    assert_in_delta metrics["gaps"].first, metrics["gaps"].last, 1
  end

  test "landing recent posts render as evenly spaced full-width rows" do
    page.current_window.resize_to(1280, 1400)
    visit "/"

    assert_selector ".landing-writeup-cards .blog-post-entry", count: 3

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const container = document.querySelector(".landing-writeup-cards");
        const cards = [...document.querySelectorAll(".landing-writeup-cards .blog-post-entry")];
        const containerRect = container.getBoundingClientRect();
        const rects = cards.map((card) => card.getBoundingClientRect());

        return {
          gridColumns: window.getComputedStyle(container).gridTemplateColumns.split(" ").length,
          leftEdges: rects.map((rect) => Math.round(rect.left)),
          widths: rects.map((rect) => Math.round(rect.width)),
          containerWidth: Math.round(containerRect.width),
          gaps: [
            Math.round(rects[1].top - rects[0].bottom),
            Math.round(rects[2].top - rects[1].bottom)
          ]
        };
      })()
    JS

    assert_equal 1, metrics["gridColumns"]
    assert_equal 1, metrics["leftEdges"].uniq.length
    metrics["widths"].each do |width|
      assert_in_delta metrics["containerWidth"], width, 1
    end
    assert_in_delta metrics["gaps"].first, metrics["gaps"].last, 1
  end

  test "landing page exposes about section counters as direct links" do
    visit "/"

    assert_text "creating writeups, collecting CVEs, bounties"
    assert_text "occasionally convince software to confess"
    assert_no_text "Security researcher and computer science student focused on web security"
    assert_no_text "Welcome to my flag collection"
    assert_selector ".landing-action[href='/posts-timeline']", text: "Posts timeline"
    assert_selector ".landing-action[href='/about']", text: "About me"
    assert_selector ".landing-metric", count: 6

    [
      [ "/about#cves", "CVEs", JSON.parse(File.read(ApplicationController::ABOUTME_CVES_PATH)).length ],
      [ "/about#bug-bounties", "Bug bounties", JSON.parse(File.read(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH)).length ],
      [ "/about#certificates", "Certificates", JSON.parse(File.read(ApplicationController::ABOUTME_CERTIFICATES_PATH)).length ],
      [ "/about#achievements", "Achievements", JSON.parse(File.read(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH)).length ]
    ].each do |href, label, count|
      assert_selector ".landing-metric[href='#{href}']", text: label
      assert_selector ".landing-metric[href='#{href}'] .landing-metric-value", text: count.to_s
    end

    assert_selector ".landing-metric[href='/posts-timeline']", text: "Posts"
    assert_selector ".landing-metric[href='/ctf']", text: "CTFs"
    assert_no_selector ".landing-metric", text: "Tags"
  end

  test "TBA findings render as static cards while disclosed findings stay collapsible" do
    visit "/about"

    assert_selector "#cves article.aboutme-finding-card-static", minimum: 2
    assert_selector "#cves details.aboutme-finding-card-cve", minimum: 10
    assert_selector "#bug-bounties article.aboutme-finding-card-static"
    assert_no_selector "#bug-bounties details"
  end

  test "timeline entries are full-card links" do
    visit "/posts-timeline"

    assert_selector "a.timeline-content[href]", minimum: 1
    first_link = find("a.timeline-content", match: :first)
    assert first_link[:href].match?(%r{/((ctf/.+/.+)|(blog/.+))\z})
  end

  test "ctf overview cards link directly to writeup overviews" do
    visit "/ctf"

    assert_no_selector ".ctf-button"
    assert_no_text "Website"
    assert_no_text "Writeups"
    assert_selector "a.ctf-card[href^='/ctf/']", minimum: 1

    first_card = find("a.ctf-card", match: :first)
    target_path = URI.parse(first_card[:href]).path
    first_card.click

    assert_current_path target_path
  end

  test "ctf writeups are ordered from latest to oldest" do
    visit "/ctf/ehax"

    assert_selector ".writeup-overview .blog-post-card", count: 2
    assert_no_selector ".writeup-overview .writeup-card"

    titles = all(".writeup-overview .blog-post-title").map(&:text)
    assert_equal [ "Fantastic Doom", "Cash Memo" ], titles
  end

  test "article table of contents toggle collapses the toc column" do
    page.current_window.resize_to(1440, 1200)
    visit "/ctf/lactf/Gamedev"

    width_script = "Math.round(document.querySelector('.writeup-container').getBoundingClientRect().width)"
    original_width = page.evaluate_script(width_script)
    find("#toc-toggle").click

    assert_selector ".writeup-wrapper.toc-collapsed"
    assert_selector "#toc-toggle[aria-expanded='false']", visible: :all
    assert_selector "#toc[hidden]", visible: :all
    assert_selector ".writeup-toc-restore-button", visible: :visible
    expanded_width = page.evaluate_script(width_script)
    assert_operator expanded_width, :>, original_width
    assert_equal "sticky", page.evaluate_script("window.getComputedStyle(document.querySelector('.writeup-toc-restore-button')).position")

    page.execute_script("window.scrollTo(0, 700)")
    sticky_top = page.evaluate_script("Math.round(document.querySelector('.writeup-toc-restore-button').getBoundingClientRect().top)")
    assert_in_delta 16, sticky_top, 4

    find(".writeup-toc-restore-button").click
    assert_no_selector ".writeup-wrapper.toc-collapsed", visible: :all
    assert_no_selector "#toc[hidden]", visible: :all
  end

  test "article code blocks are centered and shrink to their content" do
    page.current_window.resize_to(1440, 1200)
    visit "/ctf/lactf/Gamedev"

    assert_selector ".code-block pre.highlight"

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const container = document.querySelector(".writeup-container");
        const block = document.querySelector(".code-block");
        const pre = document.querySelector(".code-block pre.highlight");
        const containerRect = container.getBoundingClientRect();
        const blockRect = block.getBoundingClientRect();
        const style = window.getComputedStyle(pre);

        return {
          blockWidth: Math.round(blockRect.width),
          containerWidth: Math.round(containerRect.width),
          blockCenter: Math.round(blockRect.left + (blockRect.width / 2)),
          containerCenter: Math.round(containerRect.left + (containerRect.width / 2)),
          whiteSpace: style.whiteSpace,
          overflowWrap: style.overflowWrap
        };
      })()
    JS

    assert_operator metrics["blockWidth"], :<, metrics["containerWidth"] * 0.95
    assert_in_delta metrics["containerCenter"], metrics["blockCenter"], 2
    assert_equal "pre-wrap", metrics["whiteSpace"]
    assert_equal "anywhere", metrics["overflowWrap"]
  end
end
