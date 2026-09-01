require "application_system_test_case"

class AboutmeTest < ApplicationSystemTestCase
  test "future About timeline events receive a dynamic Upcoming treatment" do
    travel_to Time.zone.local(2026, 9, 1, 12) do
      page.current_window.resize_to(1280, 1000)
      visit about_path
      page.execute_script(<<~JS)
        document.getElementById("talks").open = true;
        document.getElementById("joomla-sqli").open = true;
      JS

      assert_selector "#joomla-sqli .aboutme-timeline li[data-upcoming='false']", count: 3
      within "#joomla-sqli .aboutme-timeline li.aboutme-timeline-item-upcoming[data-upcoming='true']" do
        assert_selector ".aboutme-timeline-date-row > .content-upcoming-badge:first-child", text: "Upcoming"
        assert_selector "time[datetime='2026-11-09']", text: "2026-11-09"
        assert_selector ".aboutme-timeline-title", text: "Talk at BSides Munich."
        assert_no_text "Upcoming:"
      end

      upcoming_styles = page.evaluate_script(<<~JS)
        (() => {
          const item = document.querySelector("#joomla-sqli .aboutme-timeline-item-upcoming");
          const style = window.getComputedStyle(item);
          const dotStyle = window.getComputedStyle(item, "::before");

          return {
            borderWidth: style.borderTopWidth,
            borderColor: style.borderTopColor,
            backgroundColor: style.backgroundColor,
            boxShadow: style.boxShadow,
            dotColor: dotStyle.backgroundColor
          };
        })()
      JS
      assert_equal "1px", upcoming_styles["borderWidth"]
      assert_not_equal "rgba(0, 0, 0, 0)", upcoming_styles["borderColor"]
      assert_not_equal "rgba(0, 0, 0, 0)", upcoming_styles["backgroundColor"]
      assert_not_equal "none", upcoming_styles["boxShadow"]
      assert_equal "rgb(85, 170, 255)", upcoming_styles["dotColor"]
    end
  end

  test "visiting about me page renders the public profile sections" do
    repository = ContentRepository.new
    section_cases = about_section_cases(repository)

    page.current_window.resize_to(1440, 1200)
    visit about_path

    assert_selector "main.aboutme-page"
    assert_selector ".content-hero .content-hero-icon[src*='task-bar/about']"
    assert_no_selector ".aboutme-hero", visible: :all
    assert_selector ".taskbar-link[href='/about']", text: "About me", visible: :all
    section_cases.each { |section| assert_text section[:title] }

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

    assert_about_catalog_rendered(section_cases)
    assert_about_links_rendered(section_cases)
    assert_no_selector ".aboutme-card-link-overlay", visible: :all
    assert_no_selector "#talks .aboutme-tag-date", visible: :all
    assert_no_selector "#achievements .aboutme-timeline-event-tag", visible: :all
    assert_selector "#cves details.aboutme-finding-card-cve", count: section_cases.find { |item| item[:id] == "cves" }[:entries].length
    assert_selector ".aboutme-achievement-card", minimum: 1
    assert_no_selector ".aboutme-stat .aboutme-stat-icon", visible: :all
    assert_equal "center", page.evaluate_script("window.getComputedStyle(document.querySelector('.aboutme-stat')).justifyContent")
    assert_equal "700", page.evaluate_script("window.getComputedStyle(document.querySelector('.aboutme-section-title')).fontWeight")
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
    section_cases.each do |section|
      count_label = section[:count] == 1 ? section[:singular] : section[:plural]
      assert_selector "##{section[:id]} .aboutme-section-count", text: "#{section[:count]} #{count_label}"
    end
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
    achievement, event = achievement_anchor_case

    visit about_path(anchor: "cves")

    assert_selector "#cves[open]"
    assert_equal true, page.evaluate_script("document.querySelector('#cves').open")

    visit about_path
    assert_equal false, page.evaluate_script("document.querySelector('#certificates').open")
    page.execute_script("window.location.hash = '#certificates'")

    assert_selector "#certificates[open]"
    assert_equal true, page.evaluate_script("document.querySelector('#certificates').open")

    visit about_path(anchor: event.fetch("id"))

    assert_selector "#achievements[open]"
    assert_selector "##{achievement.fetch('id')}[open]"
    assert_selector "##{event.fetch('id')} .aboutme-timeline-link, ##{event.fetch('id')} .aboutme-timeline-title",
                    text: event["event"].presence || event["title"]

    anchor_metrics = nil
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

    loop do
      anchor_metrics = page.evaluate_script(<<~JS)
        (() => {
          const taskbar = document.getElementById("top-taskbar").getBoundingClientRect();
          const target = document.getElementById(#{event.fetch("id").to_json});
          const section = document.getElementById("achievements");
          const card = document.getElementById(#{achievement.fetch("id").to_json});
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
    assert_equal "rgb(85, 170, 255)", metrics["dotBackground"]
    assert_match(/(?:85,\s*170,\s*255|0\.333333\s+0\.666667\s+1)/, metrics["dotShadow"])
  end

  test "about me card tags sit below titles and links read as larger actions" do
    finding_case = cve_visual_case
    challenge_case = challenge_visual_case
    reference_links = about_reference_links(finding_case)
    reference_link = reference_links.first

    page.current_window.resize_to(1280, 1400)
    visit about_path
    page.execute_script(<<~JS)
      document.querySelectorAll(".aboutme-section").forEach((section) => { section.open = true; });
    JS

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const finding = document.getElementById(#{finding_case.fetch("id").to_json});
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
        const advisoryLink = referenceLinks[0];
        const advisoryLinkStyle = window.getComputedStyle(advisoryLink);
        const severityTags = [...document.querySelectorAll("[class*='aboutme-severity-']")];
        const highSeverity = severityTags[0];
        const highSeverityStyle = window.getComputedStyle(highSeverity);
        const mediumSeverity = severityTags[1] || severityTags[0];
        const mediumSeverityStyle = window.getComputedStyle(mediumSeverity);
        const challengeTag = document.querySelector("#my-challenges ##{challenge_case.fetch("id")} a.aboutme-card-tag[target='_blank']");
        const challengeTagStyle = window.getComputedStyle(challengeTag);
        const challengeTagActionStyle = window.getComputedStyle(challengeTag, "::after");
        const cveDetailHeading = finding.querySelector(".aboutme-detail-block h3");
        const cveDetailHeadingStyle = window.getComputedStyle(cveDetailHeading);
        const cveDetailParagraph = finding.querySelector(".aboutme-detail-block p");
        const cveDetailParagraphStyle = window.getComputedStyle(cveDetailParagraph);
        const challenge = document.getElementById(#{challenge_case.fetch("id").to_json});
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
        const achievementEventTag = document.querySelector("#achievements .aboutme-finding-badges a.aboutme-card-tag[target='_blank']");
        const achievementEventTagStyle = window.getComputedStyle(achievementEventTag);
        const achievementEventTagActionStyle = window.getComputedStyle(achievementEventTag, "::after");
        const timelinePlainTitle = document.querySelector("#achievements .aboutme-timeline-title");
        const timelinePlainTitleStyle = window.getComputedStyle(timelinePlainTitle);
        const timelineEventTag = document.querySelector("#achievements .aboutme-timeline-event-link");
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
          challengeTagActionBorderTopWidth: challengeTagActionStyle.borderTopWidth,
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
    assert_equal cve_tag_from(finding_case).fetch("url"), metrics["cveHref"]
    assert_equal "A", metrics["cweTagName"]
    assert_equal cwe_tag_from(finding_case).fetch("url"), metrics["cweHref"]
    assert href_matches?(reference_link.fetch("url"), metrics["advisoryHref"])
    assert_includes metrics["advisoryClass"], "aboutme-reference-link"
    assert_equal "Open #{reference_link.fetch('label')}", metrics["advisoryAriaLabel"]
    assert_equal "Open #{reference_link.fetch('label')}", metrics["advisoryTitle"]
    assert_equal "rgb(96, 165, 250)", metrics["advisoryColor"]
    assert_equal "underline", metrics["advisoryTextDecorationLine"]
    assert_equal "block", metrics["referenceListDisplay"]
    assert_equal "disc", metrics["referenceListStyleType"]
    assert_equal "list-item", metrics["referenceListItemDisplay"]
    assert_equal "rgba(96, 165, 250, 0.82)", metrics["referenceListMarkerColor"]
    assert_equal reference_links.map { |link| link.fetch("label") }, metrics["referenceTexts"]
    reference_links.zip(metrics["referenceHrefs"]).each do |expected, rendered_href|
      assert href_matches?(expected.fetch("url"), rendered_href)
    end
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
    assert_equal "2px", metrics["challengeTagActionBorderTopWidth"]
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
    assert_match %r{\A/timeline\?tag=}, metrics["highSeverityHref"]
    assert_includes metrics["highSeverityClass"], "aboutme-tag-timeline"
    assert_equal "pointer", metrics["highSeverityCursor"]
    assert_equal "none", metrics["highSeverityBackgroundImage"]
    assert_not_equal "none", metrics["highSeverityShadow"]
    assert_equal "A", metrics["mediumSeverityTagName"]
    assert_match %r{\A/timeline\?tag=}, metrics["mediumSeverityHref"]
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
    assert metrics["timelineEventTagText"].present?
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
    challenge, writeup_tag, post = authored_challenge_writeup_case

    visit about_path
    page.execute_script(<<~JS)
      document.querySelector("#my-challenges").open = true;
      document.getElementById(#{challenge.fetch("id").to_json}).open = true;
    JS

    within "#my-challenges" do
      assert_text challenge.fetch("title")
      link = all("a.aboutme-card-tag").find do |candidate|
        href_matches?(writeup_tag.fetch("url"), candidate["href"])
      end
      assert link, "expected a rendered link to #{writeup_tag.fetch('url')}"
      assert_equal ContentTagTaxonomy.canonical_label(writeup_tag.fetch("label")), link.text.squish
      link.click
    end

    assert_current_path writeup_tag.fetch("url")
    assert_text post.fetch(:title)
    assert_selector ".writeup-recognition-badges-article .authored-challenge-badge", text: /Authored challenge/
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
            expectedHref: element.href,
            href: link ? link.href : null,
            className: link ? link.className : null
          };
        };

        return [
          linkAtCenter("#my-challenges a.aboutme-card-tag"),
          linkAtCenter("#certificates a.aboutme-card-tag"),
          linkAtCenter("#talks a.aboutme-card-tag"),
          linkAtCenter("#achievements .aboutme-finding-badges a.aboutme-card-tag"),
          linkAtCenter("#achievements .aboutme-timeline-event-link")
        ];
      })()
    JS

    hit_targets.each do |target|
      assert_equal target["expectedHref"], target["href"], "expected #{target['selector']} to receive pointer events"
      assert_includes target["className"], "aboutme-"
    end
  end

  test "about me entries are ordered newest first" do
    repository = ContentRepository.new
    cves = repository.about_entries(ApplicationController::ABOUTME_CVES_PATH)
    achievements = repository.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH)

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

    assert_equal cves.first.fetch("subtitle"), first_cve_title
    assert_equal achievements.map { |entry| entry["title"] }, achievement_titles

    achievements.each do |entry|
      rendered_events = achievement_events.fetch(entry.fetch("title"))
      expected_events = Array(entry["timeline"])

      assert_equal expected_events.map { |event| event["title"].presence || event["event"] },
                   rendered_events.map { |event| event["title"] }
      assert_equal expected_events.map { |event| event["date"].to_s },
                   rendered_events.map { |event| event["date"] }
      assert_equal expected_events.map { |event| event["summary"].to_s },
                   rendered_events.map { |event| event["summary"] }
    end
  end

  private

  def about_section_cases(repository)
    presentation = {
      "cves" => { title: "CVEs", stat_label: "CVEs", singular: "entry", plural: "entries" },
      "bug-bounties" => { title: "Bug bounties", stat_label: "Bug bounties", singular: "finding", plural: "findings" },
      "my-challenges" => { title: "Created CTF Challenges", stat_label: "Created CTF Challenges", singular: "challenge", plural: "challenges" },
      "certificates" => { title: "Certificates", stat_label: "Certificates", singular: "certificate", plural: "certificates" },
      "talks" => { title: "Talks", stat_label: "Talks", singular: "talk", plural: "talks" },
      "achievements" => { title: "Relevant achievements", stat_label: "Achievements", singular: "event", plural: "events" }
    }

    ContentTestHelpers::ABOUT_COLLECTIONS.map do |spec|
      entries = about_collection_entries(spec, repository: repository)
      spec.merge(presentation.fetch(spec.fetch(:id))).merge(
        entries: entries,
        count: spec.fetch(:count).call(repository, entries)
      )
    end
  end

  def assert_about_catalog_rendered(section_cases)
    section_cases.each do |section|
      selector = "##{section.fetch(:id)}"
      rendered_ids = all("#{selector} #{section.fetch(:card_selector)}", visible: :all).map { |card| card["id"] }.sort

      assert_equal section.fetch(:entries).map { |entry| entry.fetch("id") }.sort, rendered_ids
      assert_selector "#{selector} .aboutme-section-title", text: section.fetch(:title)
      assert_selector ".aboutme-stat[href='##{section.fetch(:id)}'] .aboutme-stat-value", text: /^#{section.fetch(:count)}$/
      assert_selector ".aboutme-stat[href='##{section.fetch(:id)}']", text: section.fetch(:stat_label)

      if section.fetch(:entries).empty?
        assert_selector "#{selector} .aboutme-empty-state"
      else
        assert_no_selector "#{selector} .aboutme-empty-state", visible: :all
      end
    end
  end

  def assert_about_links_rendered(section_cases)
    section_cases.each do |section|
      section.fetch(:entries).each do |entry|
        card = find("##{entry.fetch('id')}", visible: :all)
        tags = normalized_about_tags(entry["tags"])
        ordered_tags = tags.partition { |tag| tag[:url].blank? }.flatten

        within card do
          assert_equal ordered_tags.map { |tag| tag.fetch(:label) },
                       all(".aboutme-card-tags > *", visible: :all).map { |tag| tag.text.squish }

          ordered_tags.select { |tag| tag[:url].present? }.each do |tag|
            rendered_tag = all("a.aboutme-card-tag", visible: :all).find do |link|
              href_matches?(tag.fetch(:url), link["href"])
            end
            assert rendered_tag, "expected #{entry['id']} to link tag #{tag[:label]} to #{tag[:url]}"
          end

          expected_links = Array(entry["links"]).select do |link|
            link.is_a?(Hash) && link["label"].present? && link["url"].present?
          end
          rendered_links = all("a.aboutme-reference-link", visible: :all)
          assert_equal expected_links.map { |link| link["label"] }, rendered_links.map { |link| link.text(:all).squish }
          expected_links.zip(rendered_links).each do |expected, rendered|
            assert href_matches?(expected.fetch("url"), rendered["href"])
          end

          expected_events = Array(entry["timeline"]).select do |event|
            event.is_a?(Hash) && (event["title"].present? || event["event"].present?)
          end
          rendered_events = all(".aboutme-timeline li", visible: :all)
          assert_equal expected_events.length, rendered_events.length

          expected_events.zip(rendered_events).each do |event, rendered_event|
            label = event["title"].presence || event["event"]
            assert_equal label, rendered_event.find(".aboutme-timeline-link, .aboutme-timeline-title", visible: :all).text(:all).squish
            assert_equal event["date"], rendered_event.find("time", visible: :all)["datetime"] if event["date"].present?
            if event["url"].present?
              rendered_href = rendered_event.find("a.aboutme-timeline-link", visible: :all)["href"]
              assert href_matches?(event.fetch("url"), rendered_href)
            end
          end
        end
      end
    end
  end

  def normalized_about_tags(raw_tags)
    Array(raw_tags).filter_map do |tag|
      if tag.is_a?(Hash)
        label = tag["label"].presence || tag["name"].presence
        next if label.blank?

        { label: ContentTagTaxonomy.canonical_label(label), url: tag["url"].presence }
      elsif tag.to_s.present?
        { label: ContentTagTaxonomy.canonical_label(tag), url: nil }
      end
    end
  end

  def achievement_anchor_case
    production_content_repository.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH).each do |achievement|
      event = Array(achievement["timeline"]).find { |candidate| candidate["id"].present? }
      return [ achievement, event ] if event
    end

    flunk("expected an achievement timeline event with an anchor")
  end

  def cve_visual_case
    production_content_repository.about_entries(ApplicationController::ABOUTME_CVES_PATH).find do |entry|
      cve_tag_from(entry) && cwe_tag_from(entry) &&
        about_reference_links(entry).length >= 2 &&
        entry["summary"].present?
    end || flunk("expected a CVE with vulnerability tags, references, and details")
  end

  def challenge_visual_case
    production_content_repository.authored_challenges.find do |entry|
      entry["summary"].present? && normalized_about_tags(entry["tags"]).any? do |tag|
        tag[:url].to_s.match?(%r{\Ahttps?://})
      end
    end || flunk("expected an authored challenge with a linked tag and details")
  end

  def cve_tag_from(entry)
    Array(entry["tags"]).find do |tag|
      tag.is_a?(Hash) && tag["url"].present? && ContentVulnerabilityTag.cve?(tag["label"])
    end
  end

  def cwe_tag_from(entry)
    Array(entry["tags"]).find do |tag|
      tag.is_a?(Hash) && tag["url"].present? && ContentVulnerabilityTag.cwe?(tag["label"])
    end
  end

  def about_reference_links(entry)
    Array(entry["links"]).select do |link|
      link.is_a?(Hash) && link["label"].present? && link["url"].present?
    end
  end

  def authored_challenge_writeup_case
    production_content_repository.authored_challenges.each do |challenge|
      tag = Array(challenge["tags"]).find do |candidate|
        candidate.is_a?(Hash) && candidate["url"].to_s.start_with?("/ctf/")
      end
      next unless tag

      post = production_content_repository.ctf_posts.find do |candidate|
        CGI.unescape(candidate[:link]) == CGI.unescape(tag.fetch("url"))
      end
      return [ challenge, tag, post ] if post
    end

    flunk("expected an authored challenge linked to a published writeup")
  end

  def href_matches?(expected, actual)
    expected = expected.to_s
    actual = actual.to_s
    return expected == actual unless expected.start_with?("/")

    uri = URI.parse(actual)
    rendered_path = uri.path
    rendered_path += "?#{uri.query}" if uri.query
    rendered_path += "##{uri.fragment}" if uri.fragment
    rendered_path == expected
  rescue URI::InvalidURIError
    false
  end
end
