require "application_system_test_case"
require_relative "../support/about_page_helpers"

class AboutLayoutTest < ApplicationSystemTestCase
  include AboutPageHelpers

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

      find("#my-challenges > summary").click
      find("#my-challenges .profile-card-details > summary", match: :first).click
      assert_selector "#my-challenges .profile-card-details[open] .aboutme-card-body", minimum: 1
      mobile_card_layout = page.evaluate_script(<<~JS)
        (() => {
          const card = document.querySelector("#my-challenges .aboutme-card");
          const summary = card.querySelector(".aboutme-card-header");
          const header = summary.querySelector(".aboutme-card-header-content");
          const media = summary.querySelector(".content-card-media.blog-post-card-logo");
          const body = summary.querySelector(".blog-post-card-details");
          const summaryRect = summary.getBoundingClientRect();
          const headerRect = header.getBoundingClientRect();
          const mediaRect = media.getBoundingClientRect();
          const bodyRect = body.getBoundingClientRect();
          const mediaStyle = window.getComputedStyle(media);
          const headerStyle = window.getComputedStyle(header);

          return {
            headerDirection: headerStyle.flexDirection,
            mediaFullWidth: Math.abs(mediaRect.width - summaryRect.width) <= 1,
            mediaLeftAligned: Math.abs(mediaRect.left - summaryRect.left) <= 1,
            mediaRightAligned: Math.abs(mediaRect.right - summaryRect.right) <= 1,
            mediaAboveBody: mediaRect.bottom <= bodyRect.top + 1,
            mediaFlexBasis: mediaStyle.flexBasis,
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
        challenge.querySelector(".profile-card-details").open = true;
        const challengeDetailHeading = challenge.querySelector(".aboutme-detail-block h3");
        const challengeDetailHeadingStyle = window.getComputedStyle(challengeDetailHeading);
        const challengeDetailParagraph = challenge.querySelector(".aboutme-detail-block p");
        const challengeDetailParagraphStyle = window.getComputedStyle(challengeDetailParagraph);
        document
          .querySelectorAll("#certificates .aboutme-achievement-card, #talks .aboutme-achievement-card, #achievements .aboutme-achievement-card")
          .forEach((card) => { card.querySelector(".profile-card-details").open = true; });
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
end
