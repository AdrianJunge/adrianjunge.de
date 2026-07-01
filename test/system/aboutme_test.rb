require "application_system_test_case"

class AboutmeTest < ApplicationSystemTestCase
  test "visiting about me page renders the public profile sections" do
    repository = ContentRepository.new
    bug_bounties = repository.about_entries(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH)
    bug_bounty_count_label = "#{bug_bounties.length} #{bug_bounties.length == 1 ? 'finding' : 'findings'}"

    page.current_window.resize_to(1440, 1200)
    visit about_path

    assert_selector "main.aboutme-page"
    assert_selector ".content-hero .content-hero-icon[src*='task-bar/about']"
    assert_no_selector ".aboutme-hero", visible: :all
    assert_selector ".taskbar-link[href='/about']", text: "About me", visible: :all
    assert_text "CVEs"
    assert_text "Bug bounties"
    assert_text "Created CTF Challenges"
    assert_text "Certificates"
    assert_text "Talks"
    assert_text "Relevant achievements"

    section_states = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(".aboutme-section")).map((section) => section.open)
    JS
    assert_equal 6, section_states.length
    assert section_states.all? { |open| open == false }

    page.execute_script(<<~JS)
      document.querySelectorAll(".aboutme-section").forEach((section) => { section.open = true; });
    JS
    achievement_card_states = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(".aboutme-achievement-card")).map((card) => card.open)
    JS
    assert_operator achievement_card_states.length, :>, 0
    assert achievement_card_states.all? { |open| open == false }
    page.execute_script(<<~JS)
      document.querySelectorAll(".aboutme-achievement-card").forEach((card) => { card.open = true; });
    JS
    icon_coverage = page.evaluate_script(<<~JS)
      (() => {
        const cards = [...document.querySelectorAll(".aboutme-section .aboutme-card")]
          .filter((card) => card.offsetParent !== null);

        return {
          cardCount: cards.length,
          iconCount: cards.filter((card) => card.querySelector(".aboutme-card-icon")).length,
          mediaCount: cards.filter((card) => card.querySelector(".content-card-media.blog-post-card-logo")).length,
          dropdownHeaderCount: [...document.querySelectorAll("details.aboutme-card > summary.aboutme-card-header")].length,
          dropdownToggleCount: [...document.querySelectorAll("details.aboutme-card > summary.aboutme-card-header .aboutme-card-toggle")].length,
          mediaBorderWidths: [...document.querySelectorAll(".aboutme-card .content-card-media.blog-post-card-logo")]
            .map((media) => window.getComputedStyle(media).borderRightWidth)
            .filter((value, index, values) => values.indexOf(value) === index),
          dropdownMetrics: (() => {
            const summary = document.querySelector("details.aboutme-card[open] > summary.aboutme-card-header");
            const card = summary.closest(".aboutme-card");
            const header = summary.querySelector(".aboutme-card-header-content");
            const media = summary.querySelector(".content-card-media.blog-post-card-logo");
            const body = summary.querySelector(".blog-post-card-details");
            const toggle = summary.querySelector(".aboutme-card-toggle");
            const accentStyle = window.getComputedStyle(card, "::after");
            const toggleStyle = window.getComputedStyle(toggle);
            const chevronStyle = window.getComputedStyle(toggle, "::before");
            const summaryRect = summary.getBoundingClientRect();
            const headerRect = header.getBoundingClientRect();
            const mediaRect = media.getBoundingClientRect();
            const bodyRect = body.getBoundingClientRect();
            const toggleRect = toggle.getBoundingClientRect();

            return {
              summaryDisplay: window.getComputedStyle(summary).display,
              summaryZIndex: window.getComputedStyle(summary).zIndex,
              summaryBorderBottomWidth: window.getComputedStyle(summary).borderBottomWidth,
              summaryBorderBottomStyle: window.getComputedStyle(summary).borderBottomStyle,
              accentZIndex: accentStyle.zIndex,
              accentWidth: accentStyle.width,
              accentBackgroundImage: accentStyle.backgroundImage,
              headerDisplay: window.getComputedStyle(header).display,
              toggleDisplay: toggleStyle.display,
              toggleWidth: toggleStyle.width,
              toggleHeight: toggleStyle.height,
              toggleBackgroundColor: toggleStyle.backgroundColor,
              toggleBorderTopWidth: toggleStyle.borderTopWidth,
              toggleBorderLeftWidth: toggleStyle.borderLeftWidth,
              toggleBorderRightWidth: toggleStyle.borderRightWidth,
              toggleBorderBottomWidth: toggleStyle.borderBottomWidth,
              chevronContent: chevronStyle.content,
              topGap: Math.round(toggleRect.top - summaryRect.top),
              rightGap: Math.round(summaryRect.right - toggleRect.right),
              toggleInsideHeader:
                toggleRect.top >= summaryRect.top &&
                toggleRect.right <= summaryRect.right &&
                toggleRect.bottom <= summaryRect.bottom,
              headerBottomGap: Math.round(summaryRect.bottom - headerRect.bottom),
              mediaBottomGap: Math.round(summaryRect.bottom - mediaRect.bottom),
              bodyBottomGap: Math.round(summaryRect.bottom - bodyRect.bottom)
            };
          })()
        };
      })()
    JS
    assert_operator icon_coverage["cardCount"], :>, 0
    assert_equal icon_coverage["cardCount"], icon_coverage["iconCount"]
    assert_equal icon_coverage["cardCount"], icon_coverage["mediaCount"]
    assert_operator icon_coverage["dropdownHeaderCount"], :>, 0
    assert_equal icon_coverage["dropdownHeaderCount"], icon_coverage["dropdownToggleCount"]
    assert_equal [ "1px" ], icon_coverage["mediaBorderWidths"]
    assert_equal "flex", icon_coverage["dropdownMetrics"]["summaryDisplay"]
    assert_operator icon_coverage["dropdownMetrics"]["accentZIndex"].to_i, :>, icon_coverage["dropdownMetrics"]["summaryZIndex"].to_i
    assert_equal "4px", icon_coverage["dropdownMetrics"]["accentWidth"]
    assert_includes icon_coverage["dropdownMetrics"]["accentBackgroundImage"], "linear-gradient"
    assert_equal "1px", icon_coverage["dropdownMetrics"]["summaryBorderBottomWidth"]
    assert_equal "solid", icon_coverage["dropdownMetrics"]["summaryBorderBottomStyle"]
    assert_equal "flex", icon_coverage["dropdownMetrics"]["headerDisplay"]
    assert_equal "block", icon_coverage["dropdownMetrics"]["toggleDisplay"]
    assert_not_equal "0px", icon_coverage["dropdownMetrics"]["toggleWidth"]
    assert_not_equal "0px", icon_coverage["dropdownMetrics"]["toggleHeight"]
    assert_equal "rgba(0, 0, 0, 0)", icon_coverage["dropdownMetrics"]["toggleBackgroundColor"]
    assert_equal "0px", icon_coverage["dropdownMetrics"]["toggleBorderTopWidth"]
    assert_equal "0px", icon_coverage["dropdownMetrics"]["toggleBorderLeftWidth"]
    assert_equal "2px", icon_coverage["dropdownMetrics"]["toggleBorderRightWidth"]
    assert_equal "2px", icon_coverage["dropdownMetrics"]["toggleBorderBottomWidth"]
    assert_equal "none", icon_coverage["dropdownMetrics"]["chevronContent"]
    assert_in_delta icon_coverage["dropdownMetrics"]["topGap"], icon_coverage["dropdownMetrics"]["rightGap"], 1
    assert_operator icon_coverage["dropdownMetrics"]["topGap"], :>, 8
    assert_equal true, icon_coverage["dropdownMetrics"]["toggleInsideHeader"]
    assert_operator icon_coverage["dropdownMetrics"]["headerBottomGap"], :<=, 1
    assert_operator icon_coverage["dropdownMetrics"]["mediaBottomGap"], :<=, 1
    assert_operator icon_coverage["dropdownMetrics"]["bodyBottomGap"], :<=, 1

    assert_text "record of what I have worked on and learned from"
    assert_text "CVE-2026-39327"
    assert_text "CVE-2026-35221"
    assert_text "CVE-2026-35222"
    assert_text "CVE-2026-48898"
    assert_text "Privilege escalation through com_users batch task"
    assert_text "Authenticated blind SQL injection in com_finder"
    assert_text "Authenticated blind SQL injection in com_tags"
    assert_no_text "SuiteCRM advisory #1 (TBA)"
    assert_no_text "SuiteCRM advisory #2 (TBA)"
    assert_no_text "Firedancer bug bounty finding (TBA)"
    assert_text "Smile at me"
    assert_text "GPNCTF 2025"
    assert_text "Web challenge about URL parser differentials"
    assert_no_selector "#my-challenges .aboutme-card-link-overlay", visible: :all
    assert_no_selector "#my-challenges .aboutme-reference-link[href='/ctf/gpnctf/Smile%20at%20me']", visible: :all
    assert_selector "#my-challenges .aboutme-tag-writeup[href='/ctf/gpnctf/Smile%20at%20me']", text: "Writeup", visible: :all
    assert_selector "#my-challenges .aboutme-card-reading-time", text: /min read/
    reading_time_style = page.evaluate_script(<<~JS)
      (() => {
        const element = document.querySelector("#my-challenges .aboutme-card-reading-time");
        const style = window.getComputedStyle(element);

        return {
          borderTopWidth: style.borderTopWidth,
          backgroundColor: style.backgroundColor
        };
      })()
    JS
    assert_equal "0px", reading_time_style["borderTopWidth"]
    assert_equal "rgba(0, 0, 0, 0)", reading_time_style["backgroundColor"]
    assert_selector "#my-challenges .aboutme-card-tag[href='https://gpn23.ctf.kitctf.de/']", text: "GPNCTF 2025"
    assert_selector "#my-challenges .aboutme-difficulty-tag-hard", text: "Hard"
    assert_no_selector "#my-challenges .aboutme-difficulty-tag-unknown"
    assert_no_selector "#certificates .aboutme-card-link-overlay", visible: :all
    assert_no_selector "#certificates .aboutme-reference-link[href='/blog/htb-cpts']", visible: :all
    assert_no_selector "#certificates .aboutme-reference-link[href='https://www.credly.com/badges/a9a49759-8f35-4c46-8783-a11a4a1bfdf0/public_url']", visible: :all
    assert_selector "#certificates .aboutme-tag-writeup[href='/blog/htb-cpts']", text: "Writeup", visible: :all
    assert_selector "#certificates .aboutme-card-reading-time", text: /min read/
    assert_selector "#certificates .aboutme-tag-certificate[href='https://www.credly.com/badges/a9a49759-8f35-4c46-8783-a11a4a1bfdf0/public_url']", text: "Certificate"
    certificate_tags = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#certificates .aboutme-card-tags > *")).map((tag) => ({
        text: tag.innerText.trim(),
        linked: tag.matches("a")
      }))
    JS
    assert_equal [
      { "text" => "2026-03-23", "linked" => false },
      { "text" => "Certificate", "linked" => true },
      { "text" => "Writeup", "linked" => true }
    ], certificate_tags
    assert_selector "#talks #kitctf-web-intro-2026.aboutme-achievement-card"
    assert_no_selector "#talks .aboutme-card-link-overlay", visible: :all
    assert_no_selector "#talks .aboutme-reference-link[href='https://kitctf.de/intro/']", visible: :all
    assert_no_selector "#talks .aboutme-reference-link[href='https://kitctf.de/talks/2026-05-07-web/web-26-ss.pdf']", visible: :all
    assert_selector "#talks .aboutme-tag-overview[href='https://kitctf.de/intro/']", text: "Overview", visible: :all
    assert_selector "#talks .aboutme-card-title", text: "KITCTF Web Intro"
    assert_selector "#talks .aboutme-tag-date", text: "2026-05-07"
    assert_selector "#talks .aboutme-tag-slides[href='https://kitctf.de/talks/2026-05-07-web/web-26-ss.pdf'][target='_blank'][rel='noopener noreferrer']", text: "Slides"
    assert_selector "#talks .aboutme-card-icon[src*='other/talk-slides']"
    assert_selector "#achievements #firedancer-v1-audit-competition"
    assert_no_selector "#achievements .aboutme-card-link-overlay", visible: :all
    assert_no_selector "#achievements #kitctf .aboutme-reference-link[href='https://ctftime.org/team/7221/']", visible: :all
    assert_selector "#achievements #kitctf .aboutme-tag-kitctf[href='https://ctftime.org/team/7221/']", text: "KITCTF", visible: :all
    assert_no_text "KITCTF on CTFtime"
    assert_no_selector "#achievements #kitctf .aboutme-timeline-event-tag", visible: :all
    assert_selector "#achievements #kitctf .aboutme-timeline-event-link[href='https://ctftime.org/event/2714']", text: "KITCTF #3 at GlacierCTF 2025", visible: :all
    assert_selector "#achievements #kitctf .aboutme-card-icon[src*='ctf/kitctf']"
    assert_no_text "Public advisories"
    assert_no_text "Responsible disclosure"
    assert_no_text "Credentials"
    assert_no_text "Milestones"
    within "#achievements" do
      assert_no_text "Computer Science master's student at KIT"
    end
    assert_no_text "Placeholder"
    assert_no_text "Pending disclosure"
    assert_no_text "Details will be added"
    assert_no_selector "#cves article.aboutme-finding-card-static"
    assert_selector "#cves details.aboutme-finding-card-cve", minimum: 1
    assert_no_selector "#bug-bounties .aboutme-empty-state"
    assert_selector "#bug-bounties .aboutme-finding-card", count: bug_bounties.length
    assert_selector "#bug-bounties .aboutme-card-title", text: bug_bounties.first["title"]
    assert_selector ".aboutme-achievement-card", minimum: 1
    assert_selector ".aboutme-stat[href='#cves']", text: "CVEs"
    assert_selector ".aboutme-stat[href='#bug-bounties']", text: bug_bounties.length.to_s
    assert_selector ".aboutme-stat[href='#bug-bounties']", text: "Bug bounties"
    assert_selector ".aboutme-stat[href='#my-challenges']", text: "Created CTF Challenges"
    assert_selector ".aboutme-stat[href='#certificates']", text: "Certificates"
    assert_selector ".aboutme-stat[href='#talks']", text: "Talks"
    assert_selector ".aboutme-stat[href='#achievements']", text: "Achievements"
    assert_no_selector ".aboutme-stat .aboutme-stat-icon", visible: :all
    assert_equal "center", page.evaluate_script("window.getComputedStyle(document.querySelector('.aboutme-stat')).justifyContent")
    counter_surface = page.evaluate_script(<<~JS)
      (() => {
        const group = document.querySelector(".aboutme-stats");
        const first = document.querySelector(".aboutme-stat");
        const groupStyle = window.getComputedStyle(group);
        const firstStyle = window.getComputedStyle(first);

        return {
          groupGap: groupStyle.gap,
          groupBackgroundColor: groupStyle.backgroundColor,
          groupBackground: groupStyle.backgroundImage,
          firstBackground: firstStyle.backgroundColor,
          firstBackgroundImage: firstStyle.backgroundImage
        };
      })()
    JS
    assert_equal "0px", counter_surface["groupGap"]
    assert_equal "rgba(18, 34, 56, 0.9)", counter_surface["groupBackgroundColor"]
    assert_equal "none", counter_surface["groupBackground"]
    assert_equal "rgba(15, 52, 83, 0.7)", counter_surface["firstBackground"]
    assert_equal "none", counter_surface["firstBackgroundImage"]
    find(".aboutme-stat[href='#cves']").hover
    counter_hover_surface = page.evaluate_script(<<~JS)
      (() => {
        const first = document.querySelector(".aboutme-stat");
        const style = window.getComputedStyle(first);

        return {
          backgroundColor: style.backgroundColor,
          boxShadow: style.boxShadow
        };
      })()
    JS
    assert_equal "rgba(24, 76, 112, 0.94)", counter_hover_surface["backgroundColor"]
    assert_not_equal "none", counter_hover_surface["boxShadow"]
    assert_selector "#cves .aboutme-section-count", text: /entries/
    assert_selector "#bug-bounties .aboutme-section-count", text: bug_bounty_count_label
    assert_selector "#my-challenges .aboutme-section-count", text: /challenge/
    assert_selector "#certificates .aboutme-section-count", text: /certificate/
    assert_selector "#talks .aboutme-section-count", text: "1 talk"
    assert_selector "#achievements .aboutme-section-count", text: /events/
    section_count_surface = page.evaluate_script(<<~JS)
      (() => {
        const count = document.querySelector("#cves .aboutme-section-count");
        const style = window.getComputedStyle(count);

        return {
          backgroundColor: style.backgroundColor,
          borderWidth: style.borderTopWidth,
          borderRadius: style.borderTopLeftRadius,
          boxShadow: style.boxShadow,
          color: style.color,
          cursor: style.cursor,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          paddingLeft: style.paddingLeft,
          userSelect: style.userSelect
        };
      })()
    JS
    assert_equal "rgba(0, 0, 0, 0)", section_count_surface["backgroundColor"]
    assert_equal "rgb(254, 243, 199)", section_count_surface["color"]
    assert_equal "0px", section_count_surface["borderWidth"]
    assert_equal "0px", section_count_surface["borderRadius"]
    assert_equal "0px", section_count_surface["paddingLeft"]
    assert_equal "none", section_count_surface["boxShadow"]
    assert_equal "default", section_count_surface["cursor"]
    assert_equal "16px", section_count_surface["fontSize"]
    assert_equal "700", section_count_surface["fontWeight"]
    assert_equal "none", section_count_surface["userSelect"]

    section_arrow = page.evaluate_script(<<~JS)
      (() => {
        const section = document.querySelector("#certificates");
        const title = document.querySelector("#certificates .aboutme-section-title");
        const card = document.querySelector("details.aboutme-card");
        const cardToggle = card.querySelector(".aboutme-card-toggle");
        const transitionOverride = document.createElement("style");
        transitionOverride.textContent = ".aboutme-section-title::after, .aboutme-card-toggle { transition: none !important; }";
        document.head.appendChild(transitionOverride);
        const rotation = (transform) => {
          const matrix = new DOMMatrixReadOnly(transform);
          const angle = Math.round(Math.atan2(matrix.b, matrix.a) * (180 / Math.PI));

          return angle < 0 ? angle + 360 : angle;
        };
        const arrowAngle = () => rotation(window.getComputedStyle(title, "::after").transform);
        const cardAngle = () => rotation(window.getComputedStyle(cardToggle).transform);
        title.offsetHeight;
        section.open = false;
        card.open = false;
        title.offsetHeight;
        const collapsedArrowAngle = arrowAngle();
        const collapsedCardAngle = cardAngle();
        section.open = true;
        card.open = true;
        title.offsetHeight;
        const openArrowAngle = arrowAngle();
        const openCardAngle = cardAngle();
        transitionOverride.remove();
        const titleRect = title.getBoundingClientRect();
        const countRect = document.querySelector("#certificates .aboutme-section-count").getBoundingClientRect();
        const beforeStyle = window.getComputedStyle(title, "::before");
        const afterStyle = window.getComputedStyle(title, "::after");

        return {
          text: title.innerText.trim(),
          beforeContent: beforeStyle.content,
          afterContent: afterStyle.content,
          afterBorderRightWidth: afterStyle.borderRightWidth,
          afterWidth: afterStyle.width,
          collapsedArrowAngle,
          collapsedCardAngle,
          openArrowAngle,
          openCardAngle,
          titleSeparatedFromCount:
            titleRect.right < countRect.left ||
            titleRect.bottom <= countRect.top ||
            countRect.bottom <= titleRect.top
        };
      })()
    JS
    assert_equal "Certificates", section_arrow["text"]
    assert_equal "none", section_arrow["beforeContent"]
    assert_equal '""', section_arrow["afterContent"]
    assert_equal "2px", section_arrow["afterBorderRightWidth"]
    assert_not_equal "0px", section_arrow["afterWidth"]
    assert_equal section_arrow["collapsedCardAngle"], section_arrow["collapsedArrowAngle"]
    assert_equal 45, section_arrow["collapsedArrowAngle"]
    assert_equal section_arrow["openCardAngle"], section_arrow["openArrowAngle"]
    assert_equal 225, section_arrow["openArrowAngle"]
    assert_equal true, section_arrow["titleSeparatedFromCount"]
  end

  test "about counters scroll to their sections" do
    page.current_window.resize_to(1280, 900)
    visit about_path
    assert_selector ".aboutme-stat[href='#my-challenges'][data-smooth-scroll-bound='true']"

    find(".aboutme-stat[href='#my-challenges']").click

    assert_current_path "/about"
    assert_equal "#my-challenges", page.evaluate_script("window.location.hash")
    scroll_metrics = nil
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

    loop do
      scroll_metrics = page.evaluate_script(<<~JS)
        (() => {
          const taskbar = document.getElementById("top-taskbar").getBoundingClientRect();
          const section = document.getElementById("my-challenges");
          const sectionRect = section.getBoundingClientRect();

          return {
            sectionOpen: section.open,
            sectionTop: Math.round(sectionRect.top),
            taskbarBottom: Math.round(taskbar.bottom)
          };
        })()
      JS

      break if scroll_metrics["sectionOpen"] &&
        scroll_metrics["sectionTop"] >= scroll_metrics["taskbarBottom"] + 8 &&
        scroll_metrics["sectionTop"] <= scroll_metrics["taskbarBottom"] + 48
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.05
    end

    assert_equal true, scroll_metrics["sectionOpen"]
    assert_operator scroll_metrics["sectionTop"], :>=, scroll_metrics["taskbarBottom"] + 8
    assert_operator scroll_metrics["sectionTop"], :<=, scroll_metrics["taskbarBottom"] + 48
    assert_equal true, page.evaluate_script("document.querySelector('#my-challenges').open")
    assert_selector "#my-challenges", text: "Created CTF Challenges"
  end

  test "about hash links open matching collapsed sections" do
    visit about_path(anchor: "cves")

    assert_selector "#cves[open]"
    assert_equal true, page.evaluate_script("document.querySelector('#cves').open")

    visit about_path
    assert_equal false, page.evaluate_script("document.querySelector('#certificates').open")
    page.execute_script("window.location.hash = '#certificates'")

    assert_selector "#certificates[open]"
    assert_equal true, page.evaluate_script("document.querySelector('#certificates').open")

    visit about_path(anchor: "kitctf-glacierctf-2025")

    assert_selector "#achievements[open]"
    assert_selector "#kitctf[open]"
    assert_selector "#kitctf-glacierctf-2025 .aboutme-timeline-event-link", text: "KITCTF #3 at GlacierCTF 2025"

    anchor_metrics = nil
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

    loop do
      anchor_metrics = page.evaluate_script(<<~JS)
        (() => {
          const taskbar = document.getElementById("top-taskbar").getBoundingClientRect();
          const target = document.getElementById("kitctf-glacierctf-2025");
          const section = document.getElementById("achievements");
          const card = document.getElementById("kitctf");
          if (!target) return { targetExists: false };

          const targetRect = target.getBoundingClientRect();
          const cardRect = card.getBoundingClientRect();
          return {
            targetExists: true,
            sectionOpen: section.open,
            cardOpen: card.open,
            cardOffset: Math.round(cardRect.top - taskbar.bottom),
            cardTop: Math.round(cardRect.top),
            targetTop: Math.round(targetRect.top),
            targetBottom: Math.round(targetRect.bottom),
            taskbarBottom: Math.round(taskbar.bottom),
            viewportHeight: window.innerHeight
          };
        })()
      JS

      break if anchor_metrics["targetExists"] &&
        anchor_metrics["sectionOpen"] &&
        anchor_metrics["cardOpen"] &&
        anchor_metrics["cardTop"] >= anchor_metrics["taskbarBottom"] + 8 &&
        anchor_metrics["cardTop"] <= anchor_metrics["taskbarBottom"] + 48 &&
        anchor_metrics["targetBottom"] <= anchor_metrics["viewportHeight"] + 1
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.05
    end

    assert anchor_metrics["targetExists"]
    assert anchor_metrics["sectionOpen"]
    assert anchor_metrics["cardOpen"]
    assert_operator anchor_metrics["cardTop"], :>=, anchor_metrics["taskbarBottom"] + 8
    assert_operator anchor_metrics["cardTop"], :<=, anchor_metrics["taskbarBottom"] + 48
    assert_operator anchor_metrics["targetBottom"], :<=, anchor_metrics["viewportHeight"] + 1
  end

  test "about me page stays within narrow mobile viewports" do
    [ [ 390, 1200 ], [ 320, 1200 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      visit about_path

      overflow = page.evaluate_script(<<~JS)
        document.documentElement.scrollWidth - document.documentElement.clientWidth
      JS

      assert_operator overflow, :<=, 1, "expected no horizontal overflow at #{width}px"
      assert_selector "main.aboutme-page"
      assert_text "About me"
      assert_text "Certificates"
      assert_text "Created CTF Challenges"
      assert_text "Talks"
      assert_text "Relevant achievements"

      stats_layout = page.evaluate_script(<<~JS)
        (() => {
          const stats = document.querySelector(".aboutme-stats").getBoundingClientRect();
          const lastStat = document.querySelector(".aboutme-stat:last-child").getBoundingClientRect();
          const overflowingLabels = Array.from(document.querySelectorAll(".aboutme-stat-label")).filter((label) => {
            return label.scrollWidth - label.clientWidth > 1;
          }).map((label) => label.textContent.trim());

          return {
            statsWidth: Math.round(stats.width),
            lastStatWidth: Math.round(lastStat.width),
            overflowingLabels
          };
        })()
      JS

      assert_operator stats_layout["lastStatWidth"], :<=, stats_layout["statsWidth"]
      assert_empty stats_layout["overflowingLabels"], "expected about counter labels not to overflow at #{width}px"

      section_header_layout = page.evaluate_script(<<~JS)
        (() => {
          const rows = Array.from(document.querySelectorAll(".aboutme-section")).map((section) => {
            const header = section.querySelector(".aboutme-section-header");
            const titleWrap = header.firstElementChild;
            const count = header.querySelector(".aboutme-section-count");
            const headerRect = header.getBoundingClientRect();
            const titleRect = titleWrap.getBoundingClientRect();
            const countRect = count.getBoundingClientRect();

            return {
              id: section.id,
              countInsideHeader: countRect.right <= headerRect.right + 1,
              countRightAligned: Math.abs(headerRect.right - countRect.right) <= 1,
              countOnTitleRow: countRect.top < titleRect.bottom,
              titleBeforeCount: titleRect.right <= countRect.left + 1
            };
          });
          const challengeTitle = document.querySelector("#my-challenges .aboutme-section-title");
          const range = document.createRange();
          range.selectNodeContents(challengeTitle);
          const challengeTitleLineCount = range.getClientRects().length;
          range.detach();

          return { rows, challengeTitleLineCount };
        })()
      JS

      broken_rows = section_header_layout["rows"].reject do |row|
        row["countInsideHeader"] &&
          row["countRightAligned"] &&
          row["countOnTitleRow"] &&
          row["titleBeforeCount"]
      end
      assert_empty broken_rows, "expected section counters to stay pinned right at #{width}px"
      assert_operator section_header_layout["challengeTitleLineCount"], :>, 1 if width == 320

      page.execute_script(<<~JS)
        document.querySelector("#my-challenges").open = true;
        document.querySelector("#my-challenges .aboutme-card").open = true;
      JS
      mobile_card_layout = page.evaluate_script(<<~JS)
        (() => {
          const card = document.querySelector("#my-challenges .aboutme-card");
          const summary = card.querySelector(".aboutme-card-header");
          const header = summary.querySelector(".aboutme-card-header-content");
          const media = summary.querySelector(".content-card-media.blog-post-card-logo");
          const body = summary.querySelector(".blog-post-card-details");
          const toggle = summary.querySelector(".aboutme-card-toggle");
          const summaryRect = summary.getBoundingClientRect();
          const headerRect = header.getBoundingClientRect();
          const mediaRect = media.getBoundingClientRect();
          const bodyRect = body.getBoundingClientRect();
          const toggleRect = toggle.getBoundingClientRect();
          const mediaStyle = window.getComputedStyle(media);
          const headerStyle = window.getComputedStyle(header);

          return {
            headerDirection: headerStyle.flexDirection,
            mediaFullWidth: Math.abs(mediaRect.width - summaryRect.width) <= 1,
            mediaLeftAligned: Math.abs(mediaRect.left - summaryRect.left) <= 1,
            mediaRightAligned: Math.abs(mediaRect.right - summaryRect.right) <= 1,
            mediaAboveBody: mediaRect.bottom <= bodyRect.top + 1,
            mediaFlexBasis: mediaStyle.flexBasis,
            toggleTopGap: Math.round(toggleRect.top - summaryRect.top),
            toggleRightGap: Math.round(summaryRect.right - toggleRect.right),
            toggleInsideSummary:
              toggleRect.top >= summaryRect.top &&
              toggleRect.right <= summaryRect.right &&
              toggleRect.bottom <= summaryRect.bottom,
            headerInsideSummary:
              headerRect.left >= summaryRect.left &&
              headerRect.right <= summaryRect.right + 1
          };
        })()
      JS

      assert_equal "column", mobile_card_layout["headerDirection"]
      assert_equal true, mobile_card_layout["mediaFullWidth"], "expected about card media to fill card width at #{width}px"
      assert_equal true, mobile_card_layout["mediaLeftAligned"], "expected about card media left edge to align at #{width}px"
      assert_equal true, mobile_card_layout["mediaRightAligned"], "expected about card media right edge to align at #{width}px"
      assert_equal true, mobile_card_layout["mediaAboveBody"]
      assert_equal "auto", mobile_card_layout["mediaFlexBasis"]
      assert_in_delta mobile_card_layout["toggleTopGap"], mobile_card_layout["toggleRightGap"], 1
      assert_operator mobile_card_layout["toggleTopGap"], :>=, 10
      assert_equal true, mobile_card_layout["toggleInsideSummary"]
      assert_equal true, mobile_card_layout["headerInsideSummary"]
    end
  end

  test "about counters add row separators on mobile two-column layouts" do
    page.current_window.resize_to(390, 1200)
    visit about_path

    separators = nil
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

    loop do
      separators = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll(".aboutme-stat")).map((stat) => {
          const style = window.getComputedStyle(stat);

          return {
            borderTopWidth: style.borderTopWidth,
            borderTopStyle: style.borderTopStyle
          };
        })
      JS

      break if separators[2]["borderTopWidth"] == "1px" && separators[3]["borderTopWidth"] == "1px"
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.05
    end

    assert_equal "0px", separators[0]["borderTopWidth"]
    assert_equal "0px", separators[1]["borderTopWidth"]
    assert_equal "1px", separators[2]["borderTopWidth"]
    assert_equal "solid", separators[2]["borderTopStyle"]
    assert_equal "1px", separators[3]["borderTopWidth"]
    assert_equal "solid", separators[3]["borderTopStyle"]
  end

  test "about me entry cards use row-wise two column grids on desktop" do
    page.current_window.resize_to(1280, 1400)
    visit about_path
    page.execute_script(<<~JS)
      document.querySelectorAll(".aboutme-section").forEach((section) => { section.open = true; });
    JS

    layout = page.evaluate_script(<<~JS)
      (() => {
        const gridMetrics = (selector, cardSelector) => {
          const grid = document.querySelector(selector);
          const cards = Array.from(grid.querySelectorAll(cardSelector)).slice(0, 4);
          const style = window.getComputedStyle(grid);

          return {
            columnCount: style.gridTemplateColumns.split(" ").length,
            gap: style.gap,
            cardWidths: cards.map((card) => Math.round(card.getBoundingClientRect().width)),
            cardDisplays: cards.map((card) => window.getComputedStyle(card).display),
            cardPositions: cards.map((card) => {
              const rect = card.getBoundingClientRect();
              return { left: Math.round(rect.left), top: Math.round(rect.top) };
            })
          };
        };

        return {
          cves: gridMetrics("#cves .aboutme-finding-grid", ".aboutme-finding-card"),
          achievements: gridMetrics("#achievements .aboutme-achievement-grid", ".aboutme-achievement-card")
        };
      })()
    JS

    [ "cves", "achievements" ].each do |section|
      positions = layout[section]["cardPositions"]

      assert_equal 2, layout[section]["columnCount"]
      assert_equal "16px", layout[section]["gap"]
      assert layout[section]["cardWidths"].all? { |width| width < 600 }
      assert layout[section]["cardDisplays"].all? { |display| display == "block" }
      assert_in_delta positions[0]["top"], positions[1]["top"], 2
      assert_operator positions[0]["left"], :<, positions[1]["left"]
      assert_operator positions[2]["top"], :>, positions[0]["top"]
      assert_in_delta positions[0]["left"], positions[2]["left"], 2
    end
  end

  test "cve disclosure timelines use a rail with dots" do
    visit about_path

    metrics = nil
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

    loop do
      metrics = page.evaluate_script(<<~JS)
        (() => {
          document.querySelector("#cves").open = true;
          const timeline = document.querySelector("#cves details .aboutme-timeline");
          const details = timeline.closest("details");
          details.open = true;
          details.scrollIntoView({ block: "center" });

          const railStyle = window.getComputedStyle(timeline, "::before");
          const firstItem = timeline.querySelector("li");
          const dotStyle = window.getComputedStyle(firstItem, "::before");
          const timelineRect = timeline.getBoundingClientRect();
          const itemRect = firstItem.getBoundingClientRect();
          const railTop = parseFloat(railStyle.top);
          const railCenter = parseFloat(railStyle.left) + (parseFloat(railStyle.width) / 2);
          const dotTop = parseFloat(dotStyle.top);
          const dotSize = parseFloat(dotStyle.width) + (parseFloat(dotStyle.borderLeftWidth) * 2);
          const dotCenter = (itemRect.left - timelineRect.left) + parseFloat(dotStyle.left) + (dotSize / 2);

          return {
            railContent: railStyle.content,
            railWidth: railStyle.width,
            railBackground: railStyle.backgroundImage,
            railStartsInsideFirstDot: railTop >= dotTop && railTop <= (dotTop + dotSize),
            centerDelta: Math.abs(railCenter - dotCenter),
            dotContent: dotStyle.content,
            dotRadius: dotStyle.borderTopLeftRadius,
            dotBackground: dotStyle.backgroundColor,
            dotShadow: dotStyle.boxShadow
          };
        })()
      JS

      break if metrics["railContent"] == '""' && metrics["dotContent"] == '""'
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.05
    end

    assert_equal '""', metrics["railContent"]
    assert_equal "2px", metrics["railWidth"]
    assert_includes metrics["railBackground"], "linear-gradient"
    assert metrics["railStartsInsideFirstDot"]
    assert_operator metrics["centerDelta"], :<=, 1
    assert_equal '""', metrics["dotContent"]
    assert_not_equal "0px", metrics["dotRadius"]
    assert_match(/rgba?\(125,\s*211,\s*252/, metrics["dotBackground"])
    assert_match(/rgba?\(125,\s*211,\s*252/, metrics["dotShadow"])
  end

  test "about me card tags sit below titles and links read as larger actions" do
    page.current_window.resize_to(1280, 1400)
    visit about_path
    page.execute_script(<<~JS)
      document.querySelectorAll(".aboutme-section").forEach((section) => { section.open = true; });
    JS

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const finding = document.querySelector("#cves .aboutme-finding-card");
        const findingTitle = finding.querySelector(".aboutme-finding-project").getBoundingClientRect();
        const findingTags = finding.querySelector(".aboutme-finding-badges").getBoundingClientRect();
        const cveTag = finding.querySelector(".aboutme-cve-id");
        const cweTag = finding.querySelector(".aboutme-cwe-id");
        const cveTagStyle = window.getComputedStyle(cveTag);
        const cveTagActionStyle = window.getComputedStyle(cveTag, "::after");
        const cweTagStyle = window.getComputedStyle(cweTag);
        const cweTagActionStyle = window.getComputedStyle(cweTag, "::after");
        const projectLink = finding.querySelector(".aboutme-finding-project-link");
        const referenceList = finding.querySelector(".aboutme-card-body .aboutme-card-details");
        const referenceListStyle = window.getComputedStyle(referenceList);
        const referenceListItem = referenceList.querySelector("li");
        const referenceListItemStyle = window.getComputedStyle(referenceListItem);
        const referenceListItemMarkerStyle = window.getComputedStyle(referenceListItem, "::marker");
        const referenceLinks = [...finding.querySelectorAll(".aboutme-card-body .aboutme-reference-link")];
        const advisoryLink = referenceLinks.find((link) => link.textContent.trim() === "Advisory source");
        const advisoryLinkStyle = window.getComputedStyle(advisoryLink);
        const highSeverity = document.querySelector(".aboutme-severity-high");
        const highSeverityStyle = window.getComputedStyle(highSeverity);
        const mediumSeverity = document.querySelector(".aboutme-severity-medium");
        const mediumSeverityStyle = window.getComputedStyle(mediumSeverity);
        const challengeTag = document.querySelector("#my-challenges .aboutme-tag-gpnctf-2025");
        const challengeTagStyle = window.getComputedStyle(challengeTag);
        const challengeTagActionStyle = window.getComputedStyle(challengeTag, "::after");
        const cveDetailHeading = finding.querySelector(".aboutme-detail-block h3");
        const cveDetailHeadingStyle = window.getComputedStyle(cveDetailHeading);
        const cveDetailParagraph = finding.querySelector(".aboutme-detail-block p");
        const cveDetailParagraphStyle = window.getComputedStyle(cveDetailParagraph);
        const challenge = document.querySelector("#my-challenges .aboutme-achievement-card");
        challenge.open = true;
        const challengeDetailHeading = challenge.querySelector(".aboutme-detail-block h3");
        const challengeDetailHeadingStyle = window.getComputedStyle(challengeDetailHeading);
        const challengeDetailParagraph = challenge.querySelector(".aboutme-detail-block p");
        const challengeDetailParagraphStyle = window.getComputedStyle(challengeDetailParagraph);
        document
          .querySelectorAll("#certificates .aboutme-achievement-card, #talks .aboutme-achievement-card, #achievements .aboutme-achievement-card")
          .forEach((card) => { card.open = true; });
        const nonCveDetailHeadingStyles = [
          ...document.querySelectorAll("#my-challenges .aboutme-detail-block h3, #certificates .aboutme-detail-block h3, #talks .aboutme-detail-block h3, #achievements .aboutme-detail-block h3")
        ].map((heading) => {
          const style = window.getComputedStyle(heading);
          return { color: style.color, fontSize: style.fontSize };
        });
        const nonCveDetailParagraphStyles = [
          ...document.querySelectorAll("#my-challenges .aboutme-detail-block p, #certificates .aboutme-detail-block p, #talks .aboutme-detail-block p, #achievements .aboutme-detail-block p")
        ].map((paragraph) => {
          const style = window.getComputedStyle(paragraph);
          return { color: style.color, fontSize: style.fontSize };
        });

        const achievement = document.querySelector("#achievements .aboutme-achievement-card");
        const achievementTitle = achievement.querySelector("h3").getBoundingClientRect();
        const achievementTags = achievement.querySelector(".aboutme-finding-badges").getBoundingClientRect();
        const achievementTag = achievement.querySelector(".aboutme-finding-badges .aboutme-card-tag");
        const achievementTagStyle = window.getComputedStyle(achievementTag);
        const achievementTagActionStyle = window.getComputedStyle(achievementTag, "::after");
        const achievementEventTag = document.querySelector("#achievements #kitctf .aboutme-finding-badges .aboutme-tag-kitctf");
        const achievementEventTagStyle = window.getComputedStyle(achievementEventTag);
        const achievementEventTagActionStyle = window.getComputedStyle(achievementEventTag, "::after");
        const timelinePlainTitle = document.querySelector("#achievements #dhm .aboutme-timeline-title");
        const timelinePlainTitleStyle = window.getComputedStyle(timelinePlainTitle);
        const timelineEventTag = document.querySelector("#achievements #kitctf .aboutme-timeline-event-link");
        const timelineEventTagStyle = window.getComputedStyle(timelineEventTag);
        const timelineEventTagActionStyle = window.getComputedStyle(timelineEventTag, "::after");

        return {
          findingTagsBelowTitle: findingTags.top >= findingTitle.bottom,
          cveTagName: cveTag.tagName,
          cveHref: cveTag.getAttribute("href"),
          cweTagName: cweTag.tagName,
          cweHref: cweTag.getAttribute("href"),
          projectLinkPresent: !!projectLink,
          advisoryHref: advisoryLink.href,
          advisoryClass: advisoryLink.className,
          advisoryAriaLabel: advisoryLink.getAttribute("aria-label"),
          advisoryTitle: advisoryLink.getAttribute("title"),
          advisoryColor: advisoryLinkStyle.color,
          advisoryTextDecorationLine: advisoryLinkStyle.textDecorationLine,
          referenceListDisplay: referenceListStyle.display,
          referenceListStyleType: referenceListStyle.listStyleType,
          referenceListItemDisplay: referenceListItemStyle.display,
          referenceListMarkerColor: referenceListItemMarkerStyle.color,
          referenceTexts: referenceLinks.map((link) => link.textContent.trim()),
          referenceHrefs: referenceLinks.map((link) => link.href),
          achievementTagsBelowTitle: achievementTags.top >= achievementTitle.bottom,
          cveTagClass: cveTag.className,
          cveTagBackground: cveTagStyle.backgroundColor,
          cveTagBorder: cveTagStyle.borderTopColor,
          cveTagCursor: cveTagStyle.cursor,
          cveTagActionContent: cveTagActionStyle.content,
          cveTagActionWidth: cveTagActionStyle.width,
          cweTagClass: cweTag.className,
          cweTagBackground: cweTagStyle.backgroundColor,
          cweTagBorder: cweTagStyle.borderTopColor,
          cweTagCursor: cweTagStyle.cursor,
          cweTagActionContent: cweTagActionStyle.content,
          cweTagActionWidth: cweTagActionStyle.width,
          challengeTagClass: challengeTag.className,
          challengeTagBackground: challengeTagStyle.backgroundColor,
          challengeTagBorder: challengeTagStyle.borderTopColor,
          challengeTagCursor: challengeTagStyle.cursor,
          challengeTagActionContent: challengeTagActionStyle.content,
          challengeTagActionWidth: challengeTagActionStyle.width,
          cveDetailHeadingColor: cveDetailHeadingStyle.color,
          cveDetailHeadingFontSize: cveDetailHeadingStyle.fontSize,
          challengeDetailHeadingColor: challengeDetailHeadingStyle.color,
          challengeDetailHeadingFontSize: challengeDetailHeadingStyle.fontSize,
          cveDetailParagraphColor: cveDetailParagraphStyle.color,
          cveDetailParagraphFontSize: cveDetailParagraphStyle.fontSize,
          challengeDetailParagraphColor: challengeDetailParagraphStyle.color,
          challengeDetailParagraphFontSize: challengeDetailParagraphStyle.fontSize,
          nonCveDetailHeadingStyles,
          nonCveDetailParagraphStyles,
          highSeverityTagName: highSeverity.tagName,
          highSeverityHref: highSeverity.getAttribute("href"),
          highSeverityClass: highSeverity.className,
          highSeverityCursor: highSeverityStyle.cursor,
          highSeverityBorder: highSeverityStyle.borderTopColor,
          highSeverityBackgroundImage: highSeverityStyle.backgroundImage,
          highSeverityShadow: highSeverityStyle.boxShadow,
          mediumSeverityTagName: mediumSeverity.tagName,
          mediumSeverityHref: mediumSeverity.getAttribute("href"),
          mediumSeverityClass: mediumSeverity.className,
          mediumSeverityCursor: mediumSeverityStyle.cursor,
          mediumSeverityBorder: mediumSeverityStyle.borderTopColor,
          mediumSeverityBackgroundImage: mediumSeverityStyle.backgroundImage,
          mediumSeverityShadow: mediumSeverityStyle.boxShadow,
          achievementTagHref: achievementTag.getAttribute("href"),
          achievementTagClass: achievementTag.className,
          achievementTagBackground: achievementTagStyle.backgroundColor,
          achievementTagBorder: achievementTagStyle.borderTopColor,
          achievementTagCursor: achievementTagStyle.cursor,
          achievementTagPointerEvents: achievementTagStyle.pointerEvents,
          achievementTagShadow: achievementTagStyle.boxShadow,
          achievementTagTransform: achievementTagStyle.transform,
          achievementTagActionContent: achievementTagActionStyle.content,
          achievementEventTagClass: achievementEventTag.className,
          achievementEventTagColor: achievementEventTagStyle.color,
          achievementEventTagBackground: achievementEventTagStyle.backgroundColor,
          achievementEventTagBorder: achievementEventTagStyle.borderTopColor,
          achievementEventTagCursor: achievementEventTagStyle.cursor,
          achievementEventTagShadow: achievementEventTagStyle.boxShadow,
          achievementEventTagTextDecorationLine: achievementEventTagStyle.textDecorationLine,
          achievementEventTagActionContent: achievementEventTagActionStyle.content,
          achievementEventTagActionWidth: achievementEventTagActionStyle.width,
          timelineEventTagClass: timelineEventTag.className,
          timelineEventTagText: timelineEventTag.textContent.trim(),
          timelineEventTagColor: timelineEventTagStyle.color,
          timelineEventTagBackground: timelineEventTagStyle.backgroundColor,
          timelineEventTagBorderWidth: timelineEventTagStyle.borderTopWidth,
          timelineEventTagShadow: timelineEventTagStyle.boxShadow,
          timelineEventTagTextDecorationLine: timelineEventTagStyle.textDecorationLine,
          timelineEventTagActionContent: timelineEventTagActionStyle.content,
          timelineEventTagFontSize: timelineEventTagStyle.fontSize,
          timelineEventTagFontWeight: timelineEventTagStyle.fontWeight,
          timelineEventTagLineHeight: timelineEventTagStyle.lineHeight,
          timelinePlainTitleFontSize: timelinePlainTitleStyle.fontSize,
          timelinePlainTitleFontWeight: timelinePlainTitleStyle.fontWeight,
          timelinePlainTitleLineHeight: timelinePlainTitleStyle.lineHeight,
          visibleActionRows: document.querySelectorAll(".aboutme-link-row").length
        };
      })()
    JS

    assert metrics["findingTagsBelowTitle"]
    assert metrics["achievementTagsBelowTitle"]
    assert_equal "A", metrics["cveTagName"]
    assert_equal "https://www.cve.org/CVERecord?id=CVE-2026-48898", metrics["cveHref"]
    assert_equal "A", metrics["cweTagName"]
    assert_equal "https://cwe.mitre.org/data/definitions/284.html", metrics["cweHref"]
    assert_equal false, metrics["projectLinkPresent"]
    assert_equal "https://developer.joomla.org/security-centre/1045-20260513-core-privilege-escalation-through-com-users-batch-task.html", metrics["advisoryHref"]
    assert_includes metrics["advisoryClass"], "aboutme-reference-link"
    assert_equal "Open Advisory source", metrics["advisoryAriaLabel"]
    assert_equal "Open Advisory source", metrics["advisoryTitle"]
    assert_equal "rgb(96, 165, 250)", metrics["advisoryColor"]
    assert_equal "underline", metrics["advisoryTextDecorationLine"]
    assert_equal "block", metrics["referenceListDisplay"]
    assert_equal "disc", metrics["referenceListStyleType"]
    assert_equal "list-item", metrics["referenceListItemDisplay"]
    assert_equal "rgba(96, 165, 250, 0.82)", metrics["referenceListMarkerColor"]
    assert_includes metrics["referenceTexts"], "Repository"
    assert_includes metrics["referenceTexts"], "Advisory source"
    assert_includes metrics["referenceHrefs"], "https://github.com/joomla/joomla-cms"
    assert_not_includes metrics["referenceHrefs"], "https://www.cve.org/CVERecord?id=CVE-2026-48898"
    assert_not_includes metrics["referenceHrefs"], "https://cwe.mitre.org/data/definitions/284.html"
    assert_includes metrics["cveTagClass"], "ui-hover-lift"
    assert_includes metrics["cveTagClass"], "cve-badge"
    assert_equal "rgba(14, 116, 144, 0.42)", metrics["cveTagBackground"]
    assert_equal "rgba(125, 211, 252, 0.34)", metrics["cveTagBorder"]
    assert_equal "pointer", metrics["cveTagCursor"]
    assert_equal '""', metrics["cveTagActionContent"]
    assert_not_equal "0px", metrics["cveTagActionWidth"]
    assert_includes metrics["cweTagClass"], "ui-hover-lift"
    assert_includes metrics["cweTagClass"], "cwe-badge"
    assert_equal "rgba(14, 116, 144, 0.42)", metrics["cweTagBackground"]
    assert_equal "rgba(125, 211, 252, 0.34)", metrics["cweTagBorder"]
    assert_equal "pointer", metrics["cweTagCursor"]
    assert_equal '""', metrics["cweTagActionContent"]
    assert_not_equal "0px", metrics["cweTagActionWidth"]
    assert_includes metrics["challengeTagClass"], "ui-hover-lift"
    assert_equal "rgba(14, 116, 144, 0.42)", metrics["challengeTagBackground"]
    assert_equal "rgba(125, 211, 252, 0.34)", metrics["challengeTagBorder"]
    assert_equal "pointer", metrics["challengeTagCursor"]
    assert_equal '""', metrics["challengeTagActionContent"]
    assert_not_equal "0px", metrics["challengeTagActionWidth"]
    assert_equal "rgb(254, 243, 199)", metrics["cveDetailHeadingColor"]
    assert_equal metrics["cveDetailHeadingColor"], metrics["challengeDetailHeadingColor"]
    assert_equal metrics["cveDetailHeadingFontSize"], metrics["challengeDetailHeadingFontSize"]
    assert_equal metrics["cveDetailParagraphColor"], metrics["challengeDetailParagraphColor"]
    assert_equal metrics["cveDetailParagraphFontSize"], metrics["challengeDetailParagraphFontSize"]
    assert metrics["nonCveDetailHeadingStyles"].any?
    assert metrics["nonCveDetailParagraphStyles"].any?
    metrics["nonCveDetailHeadingStyles"].each do |style|
      assert_equal metrics["cveDetailHeadingColor"], style["color"]
      assert_equal metrics["cveDetailHeadingFontSize"], style["fontSize"]
    end
    metrics["nonCveDetailParagraphStyles"].each do |style|
      assert_equal metrics["cveDetailParagraphColor"], style["color"]
      assert_equal metrics["cveDetailParagraphFontSize"], style["fontSize"]
    end
    assert_equal "A", metrics["highSeverityTagName"]
    assert_equal "/timeline?tag=High", metrics["highSeverityHref"]
    assert_includes metrics["highSeverityClass"], "aboutme-tag-timeline"
    assert_equal "pointer", metrics["highSeverityCursor"]
    assert_equal "none", metrics["highSeverityBackgroundImage"]
    assert_not_equal "none", metrics["highSeverityShadow"]
    assert_equal "A", metrics["mediumSeverityTagName"]
    assert_equal "/timeline?tag=Moderate", metrics["mediumSeverityHref"]
    assert_includes metrics["mediumSeverityClass"], "aboutme-tag-timeline"
    assert_equal "pointer", metrics["mediumSeverityCursor"]
    assert_equal "none", metrics["mediumSeverityBackgroundImage"]
    assert_not_equal "none", metrics["mediumSeverityShadow"]
    assert_match %r{\A/timeline\?tag=}, metrics["achievementTagHref"]
    assert_includes metrics["achievementTagClass"], "aboutme-tag-timeline"
    assert_includes metrics["achievementTagClass"], "aboutme-tag-action"
    assert_includes metrics["achievementTagClass"], "ui-hover-lift"
    assert_equal "rgba(14, 116, 144, 0.42)", metrics["achievementTagBackground"]
    assert_equal "rgba(125, 211, 252, 0.34)", metrics["achievementTagBorder"]
    assert_equal "pointer", metrics["achievementTagCursor"]
    assert_equal "auto", metrics["achievementTagPointerEvents"]
    assert_not_equal "none", metrics["achievementTagShadow"]
    assert_equal "none", metrics["achievementTagActionContent"]
    assert_includes metrics["achievementEventTagClass"], "aboutme-card-tag"
    assert_includes metrics["achievementEventTagClass"], "ui-hover-lift"
    assert_equal "rgb(223, 247, 255)", metrics["achievementEventTagColor"]
    assert_equal "rgba(14, 116, 144, 0.42)", metrics["achievementEventTagBackground"]
    assert_equal "rgba(125, 211, 252, 0.34)", metrics["achievementEventTagBorder"]
    assert_equal "pointer", metrics["achievementEventTagCursor"]
    assert_not_equal "none", metrics["achievementEventTagShadow"]
    assert_equal "none", metrics["achievementEventTagTextDecorationLine"]
    assert_equal '""', metrics["achievementEventTagActionContent"]
    assert_not_equal "0px", metrics["achievementEventTagActionWidth"]
    assert_not_includes metrics["timelineEventTagClass"], "aboutme-card-tag"
    assert_equal "KITCTF #3 at GlacierCTF 2025", metrics["timelineEventTagText"]
    assert_equal "rgb(96, 165, 250)", metrics["timelineEventTagColor"]
    assert_equal "rgba(0, 0, 0, 0)", metrics["timelineEventTagBackground"]
    assert_equal "0px", metrics["timelineEventTagBorderWidth"]
    assert_equal "none", metrics["timelineEventTagShadow"]
    assert_equal "underline", metrics["timelineEventTagTextDecorationLine"]
    assert_equal "none", metrics["timelineEventTagActionContent"]
    assert_equal metrics["timelinePlainTitleFontSize"], metrics["timelineEventTagFontSize"]
    assert_equal metrics["timelinePlainTitleFontWeight"], metrics["timelineEventTagFontWeight"]
    assert_equal metrics["timelinePlainTitleLineHeight"], metrics["timelineEventTagLineHeight"]
    assert_equal 0, metrics["visibleActionRows"]

    find("#achievements .aboutme-finding-badges .aboutme-card-tag", match: :first).hover
    hovered_timeline_tag = page.evaluate_async_script(<<~JS)
      (() => {
        const done = arguments[0];
        const initialShadow = #{metrics["achievementTagShadow"].to_json};
        const initialTransform = #{metrics["achievementTagTransform"].to_json};
        const started = performance.now();
        const readState = () => {
          const tag = document.querySelector("#achievements .aboutme-finding-badges .aboutme-card-tag");
          const style = window.getComputedStyle(tag);

          return {
            backgroundColor: style.backgroundColor,
            borderColor: style.borderTopColor,
            boxShadow: style.boxShadow,
            transform: style.transform
          };
        };
        const waitForHoverStyles = () => {
          const state = readState();
          if (
            (state.boxShadow !== initialShadow && state.transform !== initialTransform) ||
            performance.now() - started > 1000
          ) {
            done(state);
          } else {
            requestAnimationFrame(waitForHoverStyles);
          }
        };

        waitForHoverStyles();
      })()
    JS
    assert_not_equal metrics["achievementTagShadow"], hovered_timeline_tag["boxShadow"]
    assert_not_equal metrics["achievementTagTransform"], hovered_timeline_tag["transform"]
  end

  test "my challenges link to their writeups" do
    visit about_path
    page.execute_script(<<~JS)
      document.querySelector("#my-challenges").open = true;
      document.querySelector("#my-challenges #smile-at-me").open = true;
    JS

    within "#my-challenges" do
      assert_text "Smile at me"
      assert_text "Published for GPNCTF 2025."
      find(".aboutme-tag-writeup[href='/ctf/gpnctf/Smile%20at%20me']").click
    end

    assert_current_path "/ctf/gpnctf/Smile%20at%20me"
    assert_text "Smile at me"
    assert_text "I'm the author of this challenge"
  end

  test "about linked tags and achievement timeline links receive pointer events" do
    page.current_window.resize_to(1280, 1400)
    visit about_path
    page.execute_script(<<~JS)
      document.querySelectorAll("#my-challenges, #certificates, #talks, #achievements").forEach((section) => { section.open = true; });
      document.querySelectorAll("#achievements .aboutme-achievement-card").forEach((card) => { card.open = true; });
    JS

    hit_targets = page.evaluate_script(<<~JS)
      (() => {
        const linkAtCenter = (selector) => {
          const element = document.querySelector(selector);
          element.scrollIntoView({ block: "center" });
          const rect = element.getBoundingClientRect();
          const link = Array.from(document.elementsFromPoint(rect.left + (rect.width / 2), rect.top + (rect.height / 2)))
            .map((hit) => hit.closest("a"))
            .find(Boolean);

          return {
            selector,
            href: link ? link.href : null,
            className: link ? link.className : null
          };
        };

        return [
          linkAtCenter("#my-challenges .aboutme-tag-gpnctf-2025"),
          linkAtCenter("#certificates .aboutme-tag-certificate"),
          linkAtCenter("#talks .aboutme-tag-slides"),
          linkAtCenter("#achievements #dhm .aboutme-tag-dhm[href='https://hacking-meisterschaft.de/']"),
          linkAtCenter("#achievements #kitctf .aboutme-timeline-event-link[href='https://ctftime.org/event/2714']")
        ];
      })()
    JS

    assert_equal "https://gpn23.ctf.kitctf.de/", hit_targets[0]["href"]
    assert_equal "https://www.credly.com/badges/a9a49759-8f35-4c46-8783-a11a4a1bfdf0/public_url", hit_targets[1]["href"]
    assert_equal "https://kitctf.de/talks/2026-05-07-web/web-26-ss.pdf", hit_targets[2]["href"]
    assert_equal "https://hacking-meisterschaft.de/", hit_targets[3]["href"]
    assert_equal "https://ctftime.org/event/2714", hit_targets[4]["href"]
  end

  test "about me entries are ordered newest first" do
    repository = ContentRepository.new

    visit about_path
    page.execute_script(<<~JS)
      document.querySelectorAll(".aboutme-section").forEach((section) => { section.open = true; });
      document.querySelectorAll("#achievements .aboutme-achievement-card").forEach((card) => { card.open = true; });
    JS

    first_cve_title = page.evaluate_script(<<~JS)
      document.querySelector("#cves .aboutme-finding-card .aboutme-finding-summary").innerText.trim()
    JS
    achievement_titles = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#achievements .aboutme-achievement-card > summary h3"))
        .map((heading) => heading.innerText.trim())
    JS
    achievement_events = page.evaluate_script(<<~JS)
      Object.fromEntries(
        Array.from(document.querySelectorAll("#achievements .aboutme-achievement-card")).map((card) => [
          card.querySelector("h3").innerText.trim(),
          Array.from(card.querySelectorAll(".aboutme-timeline li")).map((event) => ({
            title: event.querySelector(".aboutme-timeline-link, .aboutme-timeline-title").innerText.trim(),
            date: event.querySelector("time").innerText.trim(),
            summary: event.querySelector(".aboutme-timeline-summary") ? event.querySelector(".aboutme-timeline-summary").innerText.trim() : "",
            href: event.querySelector(".aboutme-timeline-link") ? event.querySelector(".aboutme-timeline-link").href : null
          }))
        ])
      )
    JS

    assert_equal "Privilege escalation through com_users batch task", first_cve_title
    assert_equal repository.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH).map { |entry| entry["title"] }, achievement_titles
    achievement_entries = repository.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH).index_by { |entry| entry["title"] }
    assert_equal achievement_entries["DHM"]["timeline"].map { |event| event["title"] }, achievement_events["DHM"].map { |event| event["title"] }
    assert_equal achievement_entries["CSCG"]["timeline"].map { |event| event["title"] }, achievement_events["CSCG"].map { |event| event["title"] }
    assert_equal achievement_entries["KITCTF"]["timeline"].map { |event| event["title"] }, achievement_events["KITCTF"].map { |event| event["title"] }
    assert_text "Placed #1 at the Deutsche Hacking Meisterschaft."
    assert_text "Participated in the DHM finals after qualifying through CSCG."
    assert_text "Qualified for DHM through CSCG."
    assert_text "Qualified for DHM again and finished top 10 globally."
    assert_text "#3 at GlacierCTF, qualifying for DHM 2025 as KITCTF team."
    assert_text "#3 at SwampCTF."
    assert_text "#1 at SwampCTF."
    assert_text "Qualified for and participated in the SnakeCTF finals in Italy."
    assert_text "#6 at Google CTF as the FluxKITtens merger team"
    assert_text "qualifying for the Hackceler8 finals in Mexico."
  end
end
