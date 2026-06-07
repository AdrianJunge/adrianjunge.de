require "application_system_test_case"

class AboutmeTest < ApplicationSystemTestCase
  test "visiting about me page renders the public profile sections" do
    visit about_path

    assert_selector "main.aboutme-page"
    assert_selector ".taskbar-link[href='/about']", text: "About me", visible: :all
    assert_text "CVEs"
    assert_text "Bug bounties"
    assert_text "Created CTF Challenges"
    assert_text "Certificates"
    assert_text "Talks"
    assert_text "Relevant achievements"
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
    assert_selector "#my-challenges .aboutme-card-link-overlay[href='/ctf/gpnctf/Smile%20at%20me']", visible: :all
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
    assert_selector "#certificates .aboutme-card-link-overlay[href='/blog/htb-cpts']", visible: :all
    assert_selector "#certificates .aboutme-card-reading-time", text: /min read/
    assert_selector "#certificates .aboutme-tag-certification[href='https://www.credly.com/badges/a9a49759-8f35-4c46-8783-a11a4a1bfdf0/public_url']", text: "Certification"
    certificate_tags = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#certificates .aboutme-card-tags > *")).map((tag) => ({
        text: tag.innerText.trim(),
        linked: tag.matches("a")
      }))
    JS
    assert_equal [
      { "text" => "2026-03-23", "linked" => false },
      { "text" => "Certification", "linked" => true }
    ], certificate_tags
    assert_selector "#talks #kitctf-web-intro-2026.aboutme-achievement-card"
    assert_selector "#talks .aboutme-card-link-overlay[href='https://kitctf.de/intro/']", visible: :all
    assert_selector "#talks .aboutme-card-title", text: "KITCTF Web Intro"
    assert_selector "#talks .aboutme-tag-date", text: "2026-05-07"
    assert_selector "#talks .aboutme-tag-slides[href='https://kitctf.de/talks/2026-05-07-web/web-26-ss.pdf'][target='_blank'][rel='noopener noreferrer']", text: "Slides"
    assert_no_selector "#achievements #firedancer-v1-audit-competition"
    assert_selector "#achievements #kitctf .aboutme-card-link-overlay[href='https://ctftime.org/team/7221/']", visible: :all
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
    assert_selector "#bug-bounties .aboutme-empty-state", text: "No public bounties yet - the disclosure timers are still pretending to be load-bearing."
    assert_selector ".aboutme-achievement-card", minimum: 1
    assert_selector ".aboutme-stat[href='#cves']", text: "CVEs"
    assert_selector ".aboutme-stat[href='#bug-bounties']", text: "0"
    assert_selector ".aboutme-stat[href='#bug-bounties']", text: "Bug bounties"
    assert_selector ".aboutme-stat[href='#my-challenges']", text: "Created Challenges"
    assert_selector ".aboutme-stat[href='#certificates']", text: "Certificates"
    assert_selector ".aboutme-stat[href='#talks']", text: "Talks"
    assert_selector ".aboutme-stat[href='#achievements']", text: "Achievements"
    assert_equal "center", page.evaluate_script("window.getComputedStyle(document.querySelector('.aboutme-stat')).justifyContent")
    assert_selector "#cves .aboutme-section-count", text: /entries/
    assert_selector "#bug-bounties .aboutme-section-count", text: "0 findings"
    assert_selector "#my-challenges .aboutme-section-count", text: /challenge/
    assert_selector "#certificates .aboutme-section-count", text: /certificate/
    assert_selector "#talks .aboutme-section-count", text: "1 talk"
    assert_selector "#achievements .aboutme-section-count", text: /events/
  end

  test "about counters scroll to their sections" do
    visit about_path

    find(".aboutme-stat[href='#my-challenges']").click

    assert_current_path "/about"
    assert_equal "#my-challenges", page.evaluate_script("window.location.hash")
    assert_selector "#my-challenges", text: "Created CTF Challenges"
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

          return {
            statsWidth: Math.round(stats.width),
            lastStatWidth: Math.round(lastStat.width)
          };
        })()
      JS

      assert_operator stats_layout["lastStatWidth"], :<=, stats_layout["statsWidth"]
    end
  end

  test "about me entry cards use row-wise two column grids on desktop" do
    page.current_window.resize_to(1280, 1400)
    visit about_path

    layout = page.evaluate_script(<<~JS)
      (() => {
        const gridMetrics = (selector, cardSelector) => {
          const grid = document.querySelector(selector);
          const cards = Array.from(grid.querySelectorAll(cardSelector)).slice(0, 4);
          const style = window.getComputedStyle(grid);

          return {
            display: style.display,
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

      assert_equal "grid", layout[section]["display"]
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

    metrics = page.evaluate_script(<<~JS)
      (() => {
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
        const projectLinkStyle = window.getComputedStyle(finding.querySelector(".aboutme-finding-project-link"));
        const advisoryLink = finding.querySelector(".aboutme-finding-advisory-link");
        const highSeverityStyle = window.getComputedStyle(document.querySelector(".aboutme-severity-high"));
        const mediumSeverityStyle = window.getComputedStyle(document.querySelector(".aboutme-severity-medium"));
        const challengeTag = document.querySelector("#my-challenges .aboutme-tag-gpnctf-2025");
        const challengeTagStyle = window.getComputedStyle(challengeTag);
        const challengeTagActionStyle = window.getComputedStyle(challengeTag, "::after");

        const achievement = document.querySelector("#achievements .aboutme-achievement-card");
        const achievementTitle = achievement.querySelector("h3").getBoundingClientRect();
        const achievementTags = achievement.querySelector(".aboutme-achievement-meta").getBoundingClientRect();
        const achievementTag = achievement.querySelector(".aboutme-achievement-meta .aboutme-card-tag");
        const achievementTagStyle = window.getComputedStyle(achievementTag);
        const achievementTagActionStyle = window.getComputedStyle(achievementTag, "::after");

        return {
          findingTagsBelowTitle: findingTags.top >= findingTitle.bottom,
          cveHref: cveTag.href,
          cweHref: cweTag.href,
          projectDecoration: projectLinkStyle.textDecorationLine,
          advisoryHref: advisoryLink.href,
          advisoryClass: advisoryLink.className,
          advisoryAriaLabel: advisoryLink.getAttribute("aria-label"),
          advisoryTitle: advisoryLink.getAttribute("title"),
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
          challengeTagClass: challengeTag.className,
          challengeTagBackground: challengeTagStyle.backgroundColor,
          challengeTagBorder: challengeTagStyle.borderTopColor,
          challengeTagCursor: challengeTagStyle.cursor,
          challengeTagActionContent: challengeTagActionStyle.content,
          challengeTagActionWidth: challengeTagActionStyle.width,
          highSeverityBorder: highSeverityStyle.borderTopColor,
          highSeverityBackgroundImage: highSeverityStyle.backgroundImage,
          highSeverityShadow: highSeverityStyle.boxShadow,
          mediumSeverityBorder: mediumSeverityStyle.borderTopColor,
          mediumSeverityBackgroundImage: mediumSeverityStyle.backgroundImage,
          mediumSeverityShadow: mediumSeverityStyle.boxShadow,
          achievementTagClass: achievementTag.className,
          achievementTagBackground: achievementTagStyle.backgroundColor,
          achievementTagBorder: achievementTagStyle.borderTopColor,
          achievementTagCursor: achievementTagStyle.cursor,
          achievementTagShadow: achievementTagStyle.boxShadow,
          achievementTagActionContent: achievementTagActionStyle.content,
          visibleActionRows: document.querySelectorAll(".aboutme-link-row").length
        };
      })()
    JS

    assert metrics["findingTagsBelowTitle"]
    assert metrics["achievementTagsBelowTitle"]
    assert_equal "https://www.cve.org/CVERecord?id=CVE-2026-48898", metrics["cveHref"]
    assert_equal "https://cwe.mitre.org/data/definitions/284.html", metrics["cweHref"]
    assert_equal "none", metrics["projectDecoration"]
    assert_equal "https://developer.joomla.org/security-centre/1045-20260513-core-privilege-escalation-through-com-users-batch-task.html", metrics["advisoryHref"]
    assert_includes metrics["advisoryClass"], "aboutme-finding-advisory-link"
    assert_equal "Open advisory for Privilege escalation through com_users batch task", metrics["advisoryAriaLabel"]
    assert_equal "Open advisory source", metrics["advisoryTitle"]
    assert_includes metrics["cveTagClass"], "ui-hover-lift"
    assert_equal "rgba(8, 145, 178, 0.16)", metrics["cveTagBackground"]
    assert_equal "rgba(125, 211, 252, 0.32)", metrics["cveTagBorder"]
    assert_equal "pointer", metrics["cveTagCursor"]
    assert_equal '""', metrics["cveTagActionContent"]
    assert_not_equal "0px", metrics["cveTagActionWidth"]
    assert_includes metrics["cweTagClass"], "ui-hover-lift"
    assert_equal "rgba(109, 40, 217, 0.2)", metrics["cweTagBackground"]
    assert_equal "rgba(167, 139, 250, 0.4)", metrics["cweTagBorder"]
    assert_equal "pointer", metrics["cweTagCursor"]
    assert_includes metrics["challengeTagClass"], "ui-hover-lift"
    assert_equal "rgba(8, 145, 178, 0.16)", metrics["challengeTagBackground"]
    assert_equal "rgba(125, 211, 252, 0.32)", metrics["challengeTagBorder"]
    assert_equal "pointer", metrics["challengeTagCursor"]
    assert_equal '""', metrics["challengeTagActionContent"]
    assert_not_equal "0px", metrics["challengeTagActionWidth"]
    assert_match(/rgba?\(251,\s*146,\s*60/, metrics["highSeverityBorder"])
    assert_includes metrics["highSeverityBackgroundImage"], "linear-gradient"
    assert_includes metrics["highSeverityShadow"], "inset"
    assert_match(/rgba?\(250,\s*204,\s*21/, metrics["mediumSeverityBorder"])
    assert_includes metrics["mediumSeverityBackgroundImage"], "linear-gradient"
    assert_includes metrics["mediumSeverityShadow"], "inset"
    assert_equal "rgba(8, 145, 178, 0.16)", metrics["achievementTagBackground"]
    assert_equal "rgba(125, 211, 252, 0.56)", metrics["achievementTagBorder"]
    assert_equal "default", metrics["achievementTagCursor"]
    assert_includes metrics["achievementTagShadow"], "inset"
    assert_not_equal '""', metrics["achievementTagActionContent"]
    assert_not_includes metrics["achievementTagClass"], "ui-hover-lift"
    assert_equal 0, metrics["visibleActionRows"]
  end

  test "my challenges link to their writeups" do
    visit about_path

    within "#my-challenges" do
      assert_text "Smile at me"
      assert_text "Published for GPNCTF 2025."
      find(".aboutme-card-link-overlay[href='/ctf/gpnctf/Smile%20at%20me']", visible: :all).click
    end

    assert_current_path "/ctf/gpnctf/Smile%20at%20me"
    assert_text "Smile at me"
    assert_text "I'm the author of this challenge"
  end

  test "about linked tags and nested achievement cards receive pointer events" do
    page.current_window.resize_to(1280, 1400)
    visit about_path

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
          linkAtCenter("#certificates .aboutme-tag-certification"),
          linkAtCenter("#talks .aboutme-tag-slides"),
          linkAtCenter("#achievements #dhm-2025 .aboutme-card-link-overlay"),
          linkAtCenter("#achievements #kitctf-glacierctf-2025 .aboutme-card-link-overlay")
        ];
      })()
    JS

    assert_equal "https://gpn23.ctf.kitctf.de/", hit_targets[0]["href"]
    assert_equal "https://www.credly.com/badges/a9a49759-8f35-4c46-8783-a11a4a1bfdf0/public_url", hit_targets[1]["href"]
    assert_equal "https://kitctf.de/talks/2026-05-07-web/web-26-ss.pdf", hit_targets[2]["href"]
    assert_equal "https://hacking-meisterschaft.de/", hit_targets[3]["href"]
    assert_equal "https://ctftime.org/event/2714", hit_targets[4]["href"]

    page.execute_script("document.querySelector('#dhm-2025').scrollIntoView({ block: 'center' });")
    find("#dhm-2025").hover

    transform = page.evaluate_script("window.getComputedStyle(document.querySelector('#dhm-2025')).transform")
    assert_not_equal "none", transform
  end

  test "about me entries are ordered newest first" do
    visit about_path

    first_cve_title = page.evaluate_script(<<~JS)
      document.querySelector("#cves .aboutme-finding-card .aboutme-finding-summary").innerText.trim()
    JS
    achievement_titles = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#achievements .aboutme-achievement-card h3"))
        .map((heading) => heading.innerText.trim())
    JS
    achievement_events = page.evaluate_script(<<~JS)
      Object.fromEntries(
        Array.from(document.querySelectorAll("#achievements .aboutme-achievement-card")).map((card) => [
          card.querySelector("h3").innerText.trim(),
          Array.from(card.querySelectorAll(".aboutme-achievement-event")).map((event) => ({
            title: event.querySelector("h4").innerText.trim(),
            date: event.querySelector("time").innerText.trim(),
            summary: event.querySelector("p") ? event.querySelector("p").innerText.trim() : ""
          }))
        ])
      )
    JS

    assert_equal "Privilege escalation through com_users batch task", first_cve_title
    assert_equal [ "KITCTF", "DHM", "CSCG" ], achievement_titles
    assert_equal [ "DHM 2025 participation", "DHM 2024 #1" ], achievement_events["DHM"].map { |event| event["title"] }
    assert_equal [ "CSCG 2025 top 10 global", "CSCG 2024 DHM qualification" ], achievement_events["CSCG"].map { |event| event["title"] }
    assert_equal [
      "KITCTF #3 at GlacierCTF 2025",
      "FluxKITtens #6 at Google CTF 2025",
      "KITCTF #3 at SwampCTF 2025",
      "KITCTF at SnakeCTF 2024 finals",
      "KITCTF #3 at GlacierCTF 2024",
      "KITCTF #1 at SwampCTF 2024"
    ], achievement_events["KITCTF"].map { |event| event["title"] }
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
