require "application_system_test_case"

class SitePagesTest < ApplicationSystemTestCase
  PAGES = {
    "/" => "Welcome to my bug collection 🐛",
    "/ctf" => "CTF writeups",
    "/ctf/lactf" => "LACTF",
    "/ctf/lactf/Gamedev" => "Gamedev",
    "/blog" => "Blog",
    "/blog/htb-cpts" => "HTB CPTS",
    "/timeline" => "Timeline",
    "/search" => "Global Search"
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

  test "page background gradient stretches to the full document height" do
    page.current_window.resize_to(1280, 900)
    visit "/ctf/kitctf/xmalloc"

    assert_selector ".article-page"

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const rootStyle = window.getComputedStyle(document.documentElement);
        const bodyStyle = window.getComputedStyle(document.body);
        const beforeStyle = window.getComputedStyle(document.body, "::before");
        const pageStyle = window.getComputedStyle(document.querySelector(".content-page"));
        const scrollHeight = Math.max(
          document.documentElement.scrollHeight,
          document.documentElement.offsetHeight,
          document.body.scrollHeight,
          document.body.offsetHeight,
          window.innerHeight
        );

        return {
          hasClass: document.body.classList.contains("site-background"),
          variableHeight: Math.round(parseFloat(rootStyle.getPropertyValue("--page-background-height"))),
          scrollHeight: Math.round(scrollHeight),
          beforeHeight: Math.round(parseFloat(beforeStyle.height)),
          beforeBackground: beforeStyle.backgroundImage,
          bodyBackground: bodyStyle.backgroundColor,
          pageBackgroundColor: pageStyle.backgroundColor,
          pageBackgroundImage: pageStyle.backgroundImage
        };
      })()
    JS

    assert_equal true, metrics["hasClass"]
    assert_operator metrics["variableHeight"], :>=, metrics["scrollHeight"] - 2
    assert_operator metrics["beforeHeight"], :>=, metrics["scrollHeight"] - 2
    assert_includes metrics["beforeBackground"], "linear-gradient"
    assert_equal "rgba(0, 0, 0, 0)", metrics["bodyBackground"]
    assert_equal "rgba(0, 0, 0, 0)", metrics["pageBackgroundColor"]
    assert_includes metrics["pageBackgroundImage"], "linear-gradient"
  end

  test "sidebar keeps a usable fixed inset on narrow displays" do
    [ 320, 390 ].each do |width|
      page.current_window.resize_to(width, 900)
      visit "/"

      page.execute_script(<<~JS)
        document.querySelectorAll("#taskbar-left, .menu-icon").forEach((element) => {
          element.style.transition = "none";
        });
        document.getElementById("menu-icon-right").click();
      JS

      assert_selector "#taskbar-left.expanded", visible: :all

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const taskbar = document.getElementById("taskbar-left");
          const icon = taskbar.querySelector(".taskbar-icon");
          const shiftedMenu = document.getElementById("menu-icon-left");
          const taskbarRect = taskbar.getBoundingClientRect();
          const iconRect = icon.getBoundingClientRect();
          const menuRect = shiftedMenu.getBoundingClientRect();
          const taskbarStyle = window.getComputedStyle(taskbar);

          return {
            taskbarWidth: Math.round(taskbarRect.width),
            paddingLeft: parseFloat(taskbarStyle.paddingLeft),
            iconLeft: Math.round(iconRect.left),
            iconWidth: Math.round(iconRect.width),
            shiftedMenuLeft: Math.round(menuRect.left)
          };
        })()
      JS

      assert_operator metrics["paddingLeft"], :>=, 9, "sidebar padding collapsed at #{width}px"
      assert_operator metrics["iconLeft"], :>=, 9, "sidebar icon touched the viewport edge at #{width}px"
      assert_operator metrics["iconWidth"], :>=, 38, "sidebar icon became too small at #{width}px"
      assert_operator metrics["taskbarWidth"], :>=, 176, "expanded sidebar became too narrow at #{width}px"
      assert_in_delta metrics["taskbarWidth"], metrics["shiftedMenuLeft"], 1
    end
  end

  test "feed controls render as flat hero actions outside the filters" do
    {
      "/ctf" => [ ".ctf-rss-feed", ".ctf-rss-icon" ],
      "/blog" => [ ".blog-rss-feed", ".blog-rss-icon" ]
    }.each do |path, (button_selector, icon_selector)|
      visit path

      button = find(button_selector)
      find(icon_selector)
      assert_selector ".content-hero-actions #{button_selector}"
      assert_selector ".content-hero-title-row .content-hero-actions #{button_selector}"
      assert_no_selector ".content-filter-panel #{button_selector}"
      assert_no_selector ".ctf-header-section #{button_selector}" if path == "/ctf"
      assert_no_selector ".blog-header-section #{button_selector}" if path == "/blog"
      page.driver.browser.action.move_to(button.native).perform

      styles = page.evaluate_script(<<~JS)
        (() => {
          const button = document.querySelector("#{button_selector}");
          const icon = document.querySelector("#{icon_selector}");

          return {
            buttonTransform: window.getComputedStyle(button).transform,
            iconTransform: window.getComputedStyle(icon).transform,
            boxShadow: window.getComputedStyle(button).boxShadow
          };
        })()
      JS

      assert_not_equal "none", styles["buttonTransform"]
      assert_equal "none", styles["iconTransform"]
      assert_equal "none", styles["boxShadow"]

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const row = document.querySelector(".content-hero-title-row");
          const actions = document.querySelector(".content-hero-actions");
          const rowRect = row.getBoundingClientRect();
          const actionsRect = actions.getBoundingClientRect();

          return {
            rowRight: Math.round(rowRect.right),
            rowTop: Math.round(rowRect.top),
            rowBottom: Math.round(rowRect.bottom),
            actionsRight: Math.round(actionsRect.right),
            actionsTop: Math.round(actionsRect.top),
            actionsBottom: Math.round(actionsRect.bottom)
          };
        })()
      JS

      assert_in_delta metrics["rowRight"], metrics["actionsRight"], 2
      assert_operator metrics["actionsTop"], :>=, metrics["rowTop"]
      assert_operator metrics["actionsBottom"], :<=, metrics["rowBottom"]
    end
  end

  test "year filter uses a rounded custom dropdown" do
    [ "/ctf", "/blog" ].each do |path|
      visit path

      assert_selector ".content-filter-year-button"
      assert_selector ".content-filter-select", visible: :hidden

      find(".content-filter-year-button").click
      assert_selector ".content-filter-year-menu", visible: :visible

      styles = page.evaluate_script(<<~JS)
        (() => {
          const button = document.querySelector(".content-filter-year-button");
          const menu = document.querySelector(".content-filter-year-menu");
          const select = document.querySelector(".content-filter-select");
          const buttonStyle = window.getComputedStyle(button);
          const menuStyle = window.getComputedStyle(menu);
          const selectStyle = window.getComputedStyle(select);

          return {
            buttonRadius: buttonStyle.borderTopLeftRadius,
            menuRadius: menuStyle.borderTopLeftRadius,
            menuBoxShadow: menuStyle.boxShadow,
            nativeOpacity: selectStyle.opacity,
            nativePointerEvents: selectStyle.pointerEvents
          };
        })()
      JS

      assert_equal styles["buttonRadius"], styles["menuRadius"]
      assert_not_equal "0px", styles["menuRadius"]
      assert_equal "none", styles["menuBoxShadow"]
      assert_equal "0", styles["nativeOpacity"]
      assert_equal "none", styles["nativePointerEvents"]
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

  test "landing title emoji does not overlap profile panel on small screens" do
    [ 320, 340, 390, 721, 760, 820, 860 ].each do |width|
      page.current_window.resize_to(width, 900)
      visit "/"

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const emoji = document.querySelector(".landing-title-emoji").getBoundingClientRect();
          const panel = document.querySelector(".landing-profile-panel").getBoundingClientRect();
          const image = document.querySelector(".landing-profile-image").getBoundingClientRect();
          const links = document.querySelector(".landing-affiliation-links").getBoundingClientRect();
          const h1 = document.querySelector(".landing-page h1").getBoundingClientRect();
          const shell = document.querySelector(".landing-hero-shell").getBoundingClientRect();
          const overlaps = (a, b) => !(a.right <= b.left || a.left >= b.right || a.bottom <= b.top || a.top >= b.bottom);

          return {
            emojiOverlapsPanel: overlaps(emoji, panel),
            emojiOverlapsImage: overlaps(emoji, image),
            emojiOverlapsLinks: overlaps(emoji, links),
            titleOverflowsShell: h1.right > shell.right + 1 || h1.left < shell.left - 1
          };
        })()
      JS

      assert_equal false, metrics["emojiOverlapsPanel"], "emoji overlapped profile panel at #{width}px"
      assert_equal false, metrics["emojiOverlapsImage"], "emoji overlapped profile image at #{width}px"
      assert_equal false, metrics["emojiOverlapsLinks"], "emoji overlapped affiliation links at #{width}px"
      assert_equal false, metrics["titleOverflowsShell"], "landing title overflowed hero shell at #{width}px"
    end
  end

  test "landing hero keeps clear of the fixed sidebar toggle on compact displays" do
    [ 320, 390, 721, 760, 860 ].each do |width|
      page.current_window.resize_to(width, 900)
      visit "/"

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const menu = document.getElementById("menu-icon-right").getBoundingClientRect();
          const hero = document.querySelector(".landing-hero-shell").getBoundingClientRect();
          const top = document.getElementById("landing-top").getBoundingClientRect();

          return {
            menuRight: Math.round(menu.right),
            heroLeft: Math.round(hero.left),
            topLeft: Math.round(top.left)
          };
        })()
      JS

      assert_operator metrics["heroLeft"], :>, metrics["menuRight"], "landing hero overlapped sidebar toggle at #{width}px"
      assert_operator metrics["topLeft"], :>, metrics["menuRight"], "landing section overlapped sidebar toggle at #{width}px"
    end
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
    assert_selector ".landing-action[href='/timeline']", text: "Timeline"
    assert_selector ".landing-action[href='/about']", text: "About me"
    assert_selector ".landing-action[href='/search']", text: "Global Search"
    assert_selector ".landing-metric", count: 6
    page.execute_script("document.querySelector('.landing-metrics').scrollIntoView({ block: 'center' })")

    [
      [ "/about#cves", "CVEs", JSON.parse(File.read(ApplicationController::ABOUTME_CVES_PATH)).length ],
      [ "/about#bug-bounties", "Bug bounties", JSON.parse(File.read(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH)).length ],
      [ "/about#my-challenges", "Created Challenges", JSON.parse(File.read(ApplicationController::ABOUTME_CHALLENGES_PATH)).length ],
      [ "/about#certificates", "Certificates", JSON.parse(File.read(ApplicationController::ABOUTME_CERTIFICATES_PATH)).length ],
      [
        "/about#achievements",
        "Achievements",
        JSON.parse(File.read(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH)).sum { |entry| Array(entry["events"]).length }
      ]
    ].each do |href, label, count|
      assert_selector ".landing-metric[href='#{href}']", text: label
      assert_selector ".landing-metric[href='#{href}'] .landing-metric-value", text: count.to_s
    end

    assert_selector ".landing-metric[href='/timeline']", text: "Posts"
    post_count = JSON.parse(File.read(ApplicationController::CTF_INFO_PATH)).sum do |name, metadata|
      directory = metadata["terminal_path"].presence || name.downcase
      Dir.glob(ApplicationController::BASE_PATH.join(directory, "*.md")).length
    end + Dir.glob(ApplicationController::BLOG_BASE_PATH.join("*.md")).length
    assert_selector ".landing-metric[href='/timeline'] .landing-metric-value", text: post_count.to_s
    assert_no_selector ".landing-metric[href='/ctf']", text: "CTFs"
    assert_no_selector ".landing-metric", text: "Tags"
    assert_selector ".landing-featured-card", count: 3
    assert_selector ".landing-featured-card", text: "CVE"
    assert_selector ".landing-featured-card", text: /Certificate/i
  end

  test "TBA findings render as static cards while disclosed findings stay collapsible" do
    visit "/about"

    assert_selector "#cves article.aboutme-finding-card-static", minimum: 2
    assert_selector "#cves details.aboutme-finding-card-cve", minimum: 10
    assert_selector "#bug-bounties article.aboutme-finding-card-static"
    assert_no_selector "#bug-bounties details"
  end

  test "timeline entries are full-card links" do
    visit "/timeline"

    assert_selector "a.timeline-content[href]", minimum: 1
    assert_text "CVE"
    assert_text "Blog post"
    first_link = find("a.timeline-content", match: :first)
    assert first_link[:href].match?(%r{/((ctf/.+/.+)|(blog/.+)|(about#.+))\z})
  end

  test "global search filters all indexed content" do
    visit "/search"

    assert_selector ".search-result-card", minimum: 30
    assert_text "Global Search"
    assert_selector ".content-filter-tag-group-label", text: "CONTENT TYPE"
    assert_selector ".content-filter-tag-group-label", text: "TOPICS, PROJECTS, AND SOURCES"
    assert_selector ".content-filter-panel .filter-chip", text: "CVE"
    assert_selector ".content-filter-panel .filter-chip", text: "CTF writeup"

    fill_in "global-search-input", with: "Firedancer"
    assert_selector ".search-result-card", text: "Firedancer"
    assert_no_selector ".search-result-card", text: "HTB CPTS"

    find("[data-filter-reset='global-search']").click
    find(".content-filter-panel .filter-chip", text: "Certificate").click
    assert_selector ".content-filter-panel .filter-chip.is-active", text: "Certificate"
    assert_selector ".search-result-card", text: "Hack The Box Certified Penetration Testing Specialist"
    assert_no_selector ".search-result-card", text: "xmalloc"
  end

  test "ctf markdown preserves anchors and external links while resolving local images" do
    visit "/ctf/umdctf/A%20Minecraft%20Movie"

    assert_text "A Minecraft Movie"
    assert_selector ".markdown-content a[href='#exploitation%20variant%201']"
    assert_selector ".markdown-content a[href='https://portswigger.net/web-security/csrf/bypassing-samesite-restrictions#none']"
    assert_selector ".markdown-content img[src*='/assets/ctf/writeups/umdctf/aminecraftmovie/landingoverview']"
  end

  test "table of contents indents nested headings by depth" do
    page.current_window.resize_to(1440, 1200)
    visit "/ctf/umdctf/A%20Minecraft%20Movie"

    assert_selector "#toc-body .toc-depth-0", text: "4. Exploitation"
    assert_selector "#toc-body .toc-depth-1", text: "4.1. Exploitation Variant 1"

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const links = [...document.querySelectorAll("#toc-body .toc-anchor")];
        const top = links.find((link) => link.innerText.trim() === "4. Exploitation");
        const nested = links.find((link) => link.innerText.includes("4.1. Exploitation Variant 1"));

        return {
          topLeft: Math.round(top.getBoundingClientRect().left),
          nestedLeft: Math.round(nested.getBoundingClientRect().left),
          topClass: top.closest("li").className,
          nestedClass: nested.closest("li").className,
          topMarker: !!top.querySelector(".toc-indent-marker"),
          nestedMarker: !!nested.querySelector(".toc-indent-marker")
        };
      })()
    JS

    assert_includes metrics["topClass"], "toc-depth-0"
    assert_includes metrics["nestedClass"], "toc-depth-1"
    assert_equal false, metrics["topMarker"]
    assert_equal true, metrics["nestedMarker"]
    assert_operator metrics["nestedLeft"], :>, metrics["topLeft"] + 8
  end

  test "ctf overview cards link directly to writeup overviews" do
    visit "/ctf"

    assert_no_selector ".ctf-button"
    assert_no_text "Website"
    assert_no_text "Writeups"
    assert_selector "a.ctf-card[href^='/ctf/']", minimum: 1
    assert_selector "a.ctf-card.ui-hover-lift", minimum: 1
    assert_no_selector "a.ctf-card.ui-hover-scale"

    first_card = find("a.ctf-card", match: :first)
    target_path = URI.parse(first_card[:href]).path
    first_card.click

    assert_current_path target_path
  end

  test "content filters search by text tags and year" do
    visit "/ctf"

    ctf_filter_tags = all(".content-filter-panel .content-filter-tag-list [data-filter-tag]").map do |chip|
      chip["data-filter-tag"]
    end
    assert_equal "Writeup winner", ctf_filter_tags.first
    assert_equal 1, ctf_filter_tags.count("Writeup winner")
    assert_selector ".content-filter-panel .filter-chip.writeup-winner-badge-filter", text: "Writeup winner"
    assert_selector ".content-filter-panel .filter-chip", text: /^pwn$/i
    find(".content-filter-panel .filter-chip", text: /^pwn$/i).click
    assert_selector ".content-filter-panel .filter-chip.is-active", text: /^pwn$/i
    assert_selector ".ctf-card", text: "KITCTF"
    assert_not_includes all(".ctf-card .ctf-name").map(&:text), "GPNCTF"

    find("[data-filter-reset='ctfs']").click
    assert_selector "[data-filter-count='ctfs']", text: "10 / 10 items"
    fill_in "ctf-search-input", with: "gpn"
    assert_selector "[data-filter-count='ctfs']", text: "2 / 10 items"
    assert_selector ".ctf-card", text: "GPNCTF"
    assert_no_selector ".ctf-card", text: "CSCG"

    find("[data-filter-reset='ctfs']").click
    assert_selector "[data-filter-count='ctfs']", text: "10 / 10 items"
    select_filter_year("ctfs", "2026")
    assert_selector "[data-filter-count='ctfs']", text: "1 / 10 items"
    assert_selector ".ctf-card", text: "KITCTF"
    assert_equal [ "KITCTF" ], all(".ctf-card .ctf-name").map(&:text)

    visit "/ctf/cscg"
    assert_selector ".blog-post-authors", text: "Challenge by"
    assert_selector ".blog-post-author-link[href='https://popax21.dev/']", text: "Popax21"
    assert_selector ".content-filter-tags-label", text: "TAGS"
    assert_selector ".content-filter-panel .filter-chip", text: "Crypto"

    within ".content-filter-panel" do
      find(".filter-chip", text: "Crypto").click
      assert_selector ".filter-chip.is-active", text: "Crypto"
    end
    assert_selector "[data-filter-count='writeups']", text: "1 / 6 items"
    assert_selector ".writeup-overview .blog-post-card", text: "KDF dream"
    assert_no_selector ".writeup-overview .blog-post-card", text: "Hoster"

    find("[data-filter-reset='writeups']").click
    assert_selector "[data-filter-count='writeups']", text: "6 / 6 items"
    select_filter_year("writeups", "2024")
    assert_selector "[data-filter-count='writeups']", text: "2 / 6 items"
    assert_selector ".writeup-overview .blog-post-card", text: "Hoster"
    assert_selector ".writeup-overview .blog-post-card", text: "Photoeditor"
    assert_no_selector ".writeup-overview .blog-post-card", text: "KDF dream"

    visit "/ctf/gpnctf"
    assert_selector ".blog-post-author-link[href='/about']", text: "vurlo"
  end

  test "blog filters search text and publish year" do
    visit "/blog"

    assert_selector ".content-filter-panel .filter-chip", text: "Active Directory"

    fill_in "blog-search-input", with: "CPTS"
    assert_selector "[data-filter-count='blogs']", text: "1 / 1 item"
    assert_selector ".blog-post-card", text: "HTB CPTS"

    find("[data-filter-reset='blogs']").click
    select_filter_year("blogs", "2026")
    assert_selector "[data-filter-count='blogs']", text: "1 / 1 item"
    assert_selector ".blog-post-card", text: "HTB CPTS"

    find("[data-filter-reset='blogs']").click
    fill_in "blog-search-input", with: "definitely-not-a-post"
    assert_selector "[data-filter-count='blogs']", text: "0 / 1 item"
    assert_selector ".content-filter-empty", text: "No blog posts match the current filters."
    assert_no_selector ".blog-post-card", text: "HTB CPTS"
  end

  test "blog and writeup cards keep full-card navigation" do
    visit "/blog"

    find(".blog-post-card", text: "HTB CPTS").find(".blog-post-card-hitbox", visible: :all).click
    assert_current_path "/blog/htb-cpts"
    assert_selector ".writeup-title", text: "HTB CPTS"

    visit "/ctf/cscg"
    find(".blog-post-card", text: "Hoster").find(".blog-post-card-hitbox", visible: :all).click
    assert_text "Hoster"
    assert_selector ".writeup-title", text: "Hoster"
  end

  test "winning writeups show proof badges on overview cards and articles" do
    visit "/ctf/cscg"

    within find(".blog-post-card", text: "KDF dream") do
      assert_selector ".blog-post-meta-row > .writeup-winner-badge:first-child[href='/ctf/certifications/cscg25-best-writeup-kdfdream.pdf']", text: "Best challenge writeup"
    end

    within find(".blog-post-card", text: "Air smeller") do
      assert_selector ".blog-post-meta-row > .writeup-winner-badge:first-child[href='/ctf/certifications/cscg25-best-writeup-airsmeller.pdf']", text: "Best challenge writeup"
    end

    filter_tags = all(".content-filter-panel .content-filter-tag-list [data-filter-tag]").map do |chip|
      chip["data-filter-tag"]
    end
    assert_equal "Writeup winner", filter_tags.first
    assert_equal 1, filter_tags.count("Writeup winner")
    assert_no_selector ".content-filter-panel [data-filter-tag='Best challenge writeup']"
    assert_selector ".content-filter-panel .filter-chip.writeup-winner-badge-filter", text: "Writeup winner"
    find(".content-filter-panel .filter-chip.writeup-winner-badge-filter", text: "Writeup winner").click
    assert_selector ".content-filter-panel .filter-chip.writeup-winner-badge-filter.is-active", text: "Writeup winner"
    assert_selector "[data-filter-count='writeups']", text: "2 / 6 items"
    assert_selector ".writeup-overview .blog-post-card", text: "KDF dream"
    assert_selector ".writeup-overview .blog-post-card", text: "Air smeller"
    assert_no_selector ".writeup-overview .blog-post-card", text: "Hoster"

    visit "/ctf/cscg/KDF%20dream"
    assert_selector ".writeup-winner-article .writeup-winner-badge[href='/ctf/certifications/cscg25-best-writeup-kdfdream.pdf']", text: "Best challenge writeup"

    visit "/ctf/umdctf/A%20Minecraft%20Movie"
    assert_selector ".writeup-winner-article .writeup-winner-badge[href='https://discord.com/channels/938193497306067065/938196910039269406/1412823165213605959']", text: "Best web writeup 2025"
  end

  test "terminal stays bounded on high resolution displays" do
    page.current_window.resize_to(2560, 1440)
    visit "/"

    page.execute_script("localStorage.removeItem('terminal-open')")
    page.execute_script("document.getElementById('terminal-taskbar-button').click()")
    assert_selector ".xterm", visible: :all

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const terminal = document.querySelector("#terminal-container");
        const button = document.querySelector(".terminal-button");
        const xterm = terminal.querySelector(".xterm");
        const terminalRect = terminal.getBoundingClientRect();
        const buttonRect = button.getBoundingClientRect();
        const terminalStyle = window.getComputedStyle(terminal);
        const xtermStyle = window.getComputedStyle(xterm);

        return {
          width: Math.round(terminalRect.width),
          height: Math.round(terminalRect.height),
          maxWidth: terminalStyle.width,
          buttonWidth: Math.round(buttonRect.width),
          fontSize: parseFloat(xtermStyle.fontSize)
        };
      })()
    JS

    assert_operator metrics["width"], :<=, 1320
    assert_operator metrics["height"], :<=, 750
    assert_operator metrics["buttonWidth"], :<=, 48
    assert_operator metrics["fontSize"], :>=, 13
    assert_operator metrics["fontSize"], :<=, 18
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

  test "article markdown keeps readable heading typography" do
    {
      "/ctf/gpnctf/Smile%20at%20me" => "TL;DR",
      "/blog/htb-cpts" => "1. My Background"
    }.each do |path, heading_text|
      page.current_window.resize_to(1280, 1200)
      visit path

      assert_selector ".markdown-content"
      assert_no_selector ".markdown-content > span", visible: :all
      assert_selector ".markdown-content h1", text: heading_text

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const heading = [...document.querySelectorAll(".markdown-content h1")]
            .find((node) => node.innerText.trim() === #{heading_text.to_json});
          const paragraph = document.querySelector(".markdown-content p");
          const headingStyle = window.getComputedStyle(heading);
          const paragraphStyle = window.getComputedStyle(paragraph);
          const titleStyle = window.getComputedStyle(document.querySelector(".writeup-title"));

          return {
            headingFontSize: parseFloat(headingStyle.fontSize),
            paragraphFontSize: parseFloat(paragraphStyle.fontSize),
            headingFontWeight: parseInt(headingStyle.fontWeight, 10),
            headingMarginTop: parseFloat(headingStyle.marginTop),
            headingMarginBottom: parseFloat(headingStyle.marginBottom),
            titleTextAlign: titleStyle.textAlign
          };
        })()
      JS

      assert_operator metrics["headingFontSize"], :>, metrics["paragraphFontSize"] * 1.5
      assert_operator metrics["headingFontWeight"], :>=, 700
      assert_operator metrics["headingMarginBottom"], :>, 8
      assert_operator metrics["headingMarginTop"], :>=, 0
      assert_equal "center", metrics["titleTextAlign"]
    end
  end

  private

  def select_filter_year(scope, year)
    find("[data-year-dropdown-button='#{scope}']").click
    find("[data-year-dropdown-option='#{scope}'][data-year-value='#{year}']").click
  end
end
