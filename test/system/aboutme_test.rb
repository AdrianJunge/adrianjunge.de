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
    assert_text "Relevant achievements"
    assert_text "CVE-2026-39327"
    assert_text "CVE-2026-35221"
    assert_text "CVE-2026-35222"
    assert_text "CVE-2026-48898"
    assert_text "Privilege escalation through com_users batch task"
    assert_text "Authenticated blind SQL injection in com_finder"
    assert_text "Authenticated blind SQL injection in com_tags"
    assert_text "SuiteCRM advisory #1 (TBA)"
    assert_text "SuiteCRM advisory #2 (TBA)"
    assert_text "Firedancer bug bounty finding (TBA)"
    assert_text "Smile at me"
    assert_text "GPNCTF 2025"
    assert_text "Web challenge about URL parser differentials"
    assert_selector "#my-challenges .aboutme-card-link-overlay[href='/ctf/gpnctf/Smile%20at%20me']", visible: :all
    assert_selector "#my-challenges .aboutme-card-tag[href='https://ctftime.org/ctf/854/']", text: "GPNCTF 2025"
    assert_selector "#certificates .aboutme-card-link-overlay[href='/blog/htb-cpts']", visible: :all
    assert_selector "#certificates .aboutme-tag-certification[href='https://www.credly.com/badges/a9a49759-8f35-4c46-8783-a11a4a1bfdf0/public_url']", text: "Certification"
    assert_selector "#achievements #firedancer-v1-audit-competition .aboutme-card-link-overlay[href='https://immunefi.com/audit-competition/firedancer-v1-audit-comp/information/']", visible: :all
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
    assert_selector "#cves article.aboutme-finding-card-static", minimum: 1
    assert_selector "#cves details.aboutme-finding-card-cve", minimum: 1
    assert_selector "#bug-bounties article.aboutme-finding-card-static .aboutme-card-link-overlay[href='https://immunefi.com/bug-bounty/firedancer/information/']", visible: :all
    assert_no_selector "#bug-bounties details"
    assert_selector ".aboutme-achievement-card", minimum: 1
    assert_selector ".aboutme-stat[href='#cves']", text: "CVEs"
    assert_selector ".aboutme-stat[href='#bug-bounties']", text: "Bug bounties"
    assert_selector ".aboutme-stat[href='#my-challenges']", text: "Created Challenges"
    assert_selector ".aboutme-stat[href='#certificates']", text: "Certificates"
    assert_selector ".aboutme-stat[href='#achievements']", text: "Achievements"
    assert_selector "#cves .aboutme-section-count", text: /entries/
    assert_selector "#bug-bounties .aboutme-section-count", text: /finding/
    assert_selector "#my-challenges .aboutme-section-count", text: /challenge/
    assert_selector "#certificates .aboutme-section-count", text: /certificate/
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

      assert_in_delta stats_layout["statsWidth"], stats_layout["lastStatWidth"], 2
    end
  end

  test "about me entry cards use masonry columns on desktop" do
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
            columnCount: style.columnCount,
            columnGap: style.columnGap,
            cardWidths: cards.map((card) => Math.round(card.getBoundingClientRect().width)),
            cardDisplays: cards.map((card) => window.getComputedStyle(card).display),
            cardMargins: cards.map((card) => window.getComputedStyle(card).marginBottom)
          };
        };

        return {
          cves: gridMetrics("#cves .aboutme-finding-grid", ".aboutme-finding-card"),
          achievements: gridMetrics("#achievements .aboutme-achievement-grid", ".aboutme-achievement-card")
        };
      })()
    JS

    [ "cves", "achievements" ].each do |section|
      assert_equal "block", layout[section]["display"]
      assert_equal "2", layout[section]["columnCount"]
      assert_equal "16px", layout[section]["columnGap"]
      assert layout[section]["cardWidths"].all? { |width| width < 600 }
      assert layout[section]["cardDisplays"].all? { |display| display == "inline-block" }
      assert layout[section]["cardMargins"].all? { |margin| margin == "16px" }
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
        const cveTagStyle = window.getComputedStyle(finding.querySelector(".aboutme-cve-id"));
        const cweTagStyle = window.getComputedStyle(finding.querySelector(".aboutme-cwe-id"));
        const projectLinkStyle = window.getComputedStyle(finding.querySelector(".aboutme-finding-project-link"));
        const highSeverityStyle = window.getComputedStyle(document.querySelector(".aboutme-severity-high"));
        const mediumSeverityStyle = window.getComputedStyle(document.querySelector(".aboutme-severity-medium"));
        const challengeTagStyle = window.getComputedStyle(document.querySelector("#my-challenges .aboutme-tag-gpnctf-2025"));

        const achievement = document.querySelector("#achievements .aboutme-achievement-card");
        const achievementTitle = achievement.querySelector("h3").getBoundingClientRect();
        const achievementTags = achievement.querySelector(".aboutme-achievement-meta").getBoundingClientRect();
        const achievementTagStyle = window.getComputedStyle(achievement.querySelector(".aboutme-achievement-meta .aboutme-card-tag"));

        return {
          findingTagsBelowTitle: findingTags.top >= findingTitle.bottom,
          cveHref: finding.querySelector(".aboutme-cve-id").href,
          cweHref: finding.querySelector(".aboutme-cwe-id").href,
          projectDecoration: projectLinkStyle.textDecorationLine,
          achievementTagsBelowTitle: achievementTags.top >= achievementTitle.bottom,
          cveTagBackground: cveTagStyle.backgroundColor,
          cveTagBorder: cveTagStyle.borderTopColor,
          cweTagBackground: cweTagStyle.backgroundColor,
          cweTagBorder: cweTagStyle.borderTopColor,
          challengeTagBackground: challengeTagStyle.backgroundColor,
          challengeTagBorder: challengeTagStyle.borderTopColor,
          highSeverityBorder: highSeverityStyle.borderTopColor,
          highSeverityBackgroundImage: highSeverityStyle.backgroundImage,
          mediumSeverityBorder: mediumSeverityStyle.borderTopColor,
          mediumSeverityBackgroundImage: mediumSeverityStyle.backgroundImage,
          achievementTagBackground: achievementTagStyle.backgroundColor,
          achievementTagBorder: achievementTagStyle.borderTopColor,
          visibleActionRows: document.querySelectorAll(".aboutme-link-row").length
        };
      })()
    JS

    assert metrics["findingTagsBelowTitle"]
    assert metrics["achievementTagsBelowTitle"]
    assert_equal "https://www.cve.org/CVERecord?id=CVE-2026-48898", metrics["cveHref"]
    assert_equal "https://cwe.mitre.org/data/definitions/284.html", metrics["cweHref"]
    assert_equal "underline", metrics["projectDecoration"]
    assert_equal "rgba(8, 145, 178, 0.3)", metrics["cveTagBackground"]
    assert_equal "rgba(34, 211, 238, 0.68)", metrics["cveTagBorder"]
    assert_equal "rgba(109, 40, 217, 0.3)", metrics["cweTagBackground"]
    assert_equal "rgba(196, 181, 253, 0.62)", metrics["cweTagBorder"]
    assert_equal "rgba(8, 145, 178, 0.28)", metrics["challengeTagBackground"]
    assert_equal "rgba(34, 211, 238, 0.62)", metrics["challengeTagBorder"]
    assert_match(/rgba?\(251,\s*146,\s*60/, metrics["highSeverityBorder"])
    assert_includes metrics["highSeverityBackgroundImage"], "linear-gradient"
    assert_match(/rgba?\(250,\s*204,\s*21/, metrics["mediumSeverityBorder"])
    assert_includes metrics["mediumSeverityBackgroundImage"], "linear-gradient"
    assert_equal "rgba(8, 145, 178, 0.16)", metrics["achievementTagBackground"]
    assert_equal "rgba(125, 211, 252, 0.32)", metrics["achievementTagBorder"]
    assert_not_equal metrics["cveTagBackground"], metrics["achievementTagBackground"]
    assert_not_equal metrics["challengeTagBackground"], metrics["achievementTagBackground"]
    assert_equal 0, metrics["visibleActionRows"]
  end

  test "my challenges link to their writeups" do
    visit about_path

    within "#my-challenges" do
      assert_text "Smile at me"
      assert_text "CTF challenge published for GPNCTF 2025."
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
          linkAtCenter("#achievements #dhm-2025 .aboutme-card-link-overlay"),
          linkAtCenter("#achievements #kitctf-glacierctf-2025 .aboutme-card-link-overlay")
        ];
      })()
    JS

    assert_equal "https://ctftime.org/ctf/854/", hit_targets[0]["href"]
    assert_equal "https://www.credly.com/badges/a9a49759-8f35-4c46-8783-a11a4a1bfdf0/public_url", hit_targets[1]["href"]
    assert_equal "https://hacking-meisterschaft.de/", hit_targets[2]["href"]
    assert_equal "https://ctftime.org/event/2714", hit_targets[3]["href"]

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
    assert_equal [
      "Firedancer v1.0 audit competition",
      "DHM",
      "CSCG",
      "KITCTF"
    ], achievement_titles
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
