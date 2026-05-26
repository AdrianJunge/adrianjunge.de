require "application_system_test_case"

class SitePagesTest < ApplicationSystemTestCase
  PAGES = {
    "/" => "Welcome to my flag collection",
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

  test "TBA findings render as static cards while disclosed findings stay collapsible" do
    visit "/about"

    assert_selector "#cves article.aboutme-finding-card-static", minimum: 4
    assert_selector "#cves details.aboutme-finding-card-cve", minimum: 7
    assert_selector "#bug-bounties article.aboutme-finding-card-static"
    assert_no_selector "#bug-bounties details"
  end

  test "timeline entries are full-card links" do
    visit "/posts-timeline"

    assert_selector "a.timeline-content[href]", minimum: 1
    first_link = find("a.timeline-content", match: :first)
    assert first_link[:href].match?(%r{/((ctf/.+/.+)|(blog/.+))\z})
  end

  test "ctf writeups are ordered from latest to oldest" do
    visit "/ctf/ehax"

    titles = all(".writeup-card h5").map(&:text)
    assert_equal [ "Fantastic doom", "Cash memo" ], titles
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
