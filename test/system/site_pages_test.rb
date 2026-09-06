require "application_system_test_case"

require_relative "../support/site_page_helpers"

class SitePagesTest < ApplicationSystemTestCase
  include SitePageHelpers
  test "main pages use the refreshed visual shells without horizontal overflow" do
    [ [ 1280, 1400 ], [ 390, 1200 ], [ 320, 1200 ] ].each do |width, height|
      page.current_window.resize_to(width, height)

      pages_with_expected_text.each do |path, expected_text|
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
    visit first_ctf_post[:link]

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
    assert_operator metrics["beforeHeight"], :>=, metrics["scrollHeight"] - 2
    assert_includes metrics["beforeBackground"], "linear-gradient"
    assert_equal "rgba(0, 0, 0, 0)", metrics["bodyBackground"]
    assert_equal "rgba(0, 0, 0, 0)", metrics["pageBackgroundColor"]
    assert_includes metrics["pageBackgroundImage"], "linear-gradient"
  end

  test "global radius tokens keep website corners restrained" do
    visit "/timeline"
    assert_selector "body", wait: Capybara.default_max_wait_time do
      page.evaluate_script(<<~JS).present?
        window.getComputedStyle(document.documentElement).getPropertyValue("--radius-ui").trim()
      JS
    end

    radii = page.evaluate_script(<<~JS)
      (() => {
        const root = window.getComputedStyle(document.documentElement);

        return {
          surface: root.getPropertyValue("--radius-ui").trim(),
          control: root.getPropertyValue("--radius-ui-control").trim(),
          tag: root.getPropertyValue("--radius-ui-pill").trim()
        };
      })()
    JS

    assert_equal ".95rem", radii["surface"]
    assert_equal ".65rem", radii["control"]
    assert_equal ".72rem", radii["tag"]
  end

  test "top taskbar keeps usable icons on narrow displays" do
    [ 320, 390, 690, 720 ].each do |width|
      page.current_window.resize_to(width, 900)
      visit "/"

      assert_selector "#top-taskbar", visible: :all

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const taskbar = document.getElementById("top-taskbar");
          const icon = taskbar.querySelector(".taskbar-icon");
          const terminalItem = taskbar.querySelector(".taskbar-item-terminal");
          const visibleLabels = Array.from(taskbar.querySelectorAll(".taskbar-label")).filter((label) => {
            return label.getClientRects().length > 0;
          });
          const taskbarRect = taskbar.getBoundingClientRect();
          const iconRect = icon.getBoundingClientRect();
          const taskbarStyle = window.getComputedStyle(taskbar);
          const labelStyles = visibleLabels.map((label) => window.getComputedStyle(label));
          const labelFontSizes = labelStyles.map((style) => parseFloat(style.fontSize));

          return {
            taskbarHeight: Math.round(taskbarRect.height),
            paddingLeft: parseFloat(taskbarStyle.paddingLeft),
            iconLeft: Math.round(iconRect.left),
            iconWidth: Math.round(iconRect.width),
            taskbarBackground: taskbarStyle.backgroundColor,
            terminalVisible: terminalItem && window.getComputedStyle(terminalItem).display !== "none",
            visibleLabelCount: visibleLabels.length,
            labelTextOverflows: labelStyles.map((style) => style.textOverflow),
            minLabelFontSize: labelFontSizes.length ? Math.min(...labelFontSizes) : null,
            maxLabelFontSize: labelFontSizes.length ? Math.max(...labelFontSizes) : null
          };
        })()
      JS

      assert_equal "rgba(7, 31, 52, 0.64)", metrics["taskbarBackground"]
      assert_operator metrics["paddingLeft"], :>=, 7, "top taskbar padding collapsed at #{width}px"
      assert_operator metrics["iconLeft"], :>=, 7, "top taskbar icon touched the viewport edge at #{width}px"
      assert_operator metrics["iconWidth"], :>=, 24, "top taskbar icon became too small at #{width}px"
      assert_operator metrics["taskbarHeight"], :>=, 48, "top taskbar became too short at #{width}px"
      assert_empty metrics["labelTextOverflows"].grep("ellipsis"), "top taskbar labels still use ellipsis at #{width}px"
      assert_equal width >= 700, metrics["terminalVisible"], "terminal taskbar visibility was wrong at #{width}px"

      if width <= 420
        assert_equal 0, metrics["visibleLabelCount"], "top taskbar labels should be hidden at #{width}px"
      else
        assert_operator metrics["visibleLabelCount"], :>, 0, "top taskbar labels disappeared too early at #{width}px"
        assert_operator metrics["minLabelFontSize"], :>=, 8.9, "top taskbar labels became too small at #{width}px"
        assert_operator metrics["maxLabelFontSize"], :<=, 11, "top taskbar labels became too large at #{width}px"
      end
    end
  end

  test "feed controls render in the top taskbar dropdown" do
    {
      "/ctf" => [ ".ctf-rss-feed", ".ctf-atom-feed", ".ctf-json-feed" ],
      "/blog" => [ ".blog-rss-feed", ".blog-atom-feed", ".blog-json-feed" ]
    }.each do |path, old_feed_selectors|
      page.current_window.resize_to(1280, 900)
      visit path

      old_feed_selectors.each do |selector|
        assert_no_selector selector, visible: :all
      end
      assert_no_selector ".content-hero-actions", visible: :all

      toggle = find(".taskbar-feed-toggle")
      toggle.click
      assert_selector ".taskbar-feed-menu[open]", visible: :all
      assert_selector ".taskbar-feed-option[href='/feed.xml']", text: "RSS", visible: :all
      assert_selector ".taskbar-feed-option[href='/feed.atom']", text: "Atom", visible: :all
      assert_selector ".taskbar-feed-option[href='/feed.json']", text: "JSON", visible: :all

      rss_option = find(".taskbar-feed-option[href='/feed.xml']", visible: :all)
      page.driver.browser.action.move_to(rss_option.native).perform

      styles = page.evaluate_script(<<~JS)
        (() => {
          const option = document.querySelector(".taskbar-feed-option[href='/feed.xml']");
          const icon = option.querySelector(".taskbar-feed-option-icon");
          const label = document.querySelector(".taskbar-feed-toggle .taskbar-label");
          const caret = window.getComputedStyle(label, "::after");

          return {
            optionTransform: window.getComputedStyle(option).transform,
            iconTransform: window.getComputedStyle(icon).transform,
            boxShadow: window.getComputedStyle(option).boxShadow,
            caretWidth: caret.width,
            caretBorderRight: caret.borderRightWidth
          };
        })()
      JS

      assert_equal "none", styles["optionTransform"]
      assert_equal "none", styles["iconTransform"]
      assert_not_equal "none", styles["boxShadow"]
      assert_not_equal "0px", styles["caretWidth"]
      assert_not_equal "0px", styles["caretBorderRight"]

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const taskbar = document.getElementById("top-taskbar");
          const menu = document.querySelector(".taskbar-feed-menu");
          const dropdown = document.querySelector(".taskbar-feed-dropdown");
          const taskbarRect = taskbar.getBoundingClientRect();
          const menuRect = menu.getBoundingClientRect();
          const dropdownRect = dropdown.getBoundingClientRect();

          return {
            taskbarBottom: Math.round(taskbarRect.bottom),
            menuLeft: Math.round(menuRect.left),
            menuRight: Math.round(menuRect.right),
            dropdownLeft: Math.round(dropdownRect.left),
            dropdownRight: Math.round(dropdownRect.right),
            dropdownTop: Math.round(dropdownRect.top)
          };
        })()
      JS

      assert_operator metrics["dropdownTop"], :>=, metrics["taskbarBottom"]
      assert_in_delta metrics["menuLeft"], metrics["dropdownLeft"], 2
      assert_operator metrics["dropdownRight"], :>, metrics["menuRight"]

      page.current_window.resize_to(320, 900)
      mobile_metrics = page.evaluate_script(<<~JS)
        (() => {
          const dropdown = document.querySelector(".taskbar-feed-dropdown").getBoundingClientRect();
          const viewportWidth = document.documentElement.clientWidth;

          return {
            dropdownLeft: Math.round(dropdown.left),
            dropdownRight: Math.round(dropdown.right),
            viewportWidth
          };
        })()
      JS
      assert_operator mobile_metrics["dropdownLeft"], :>=, 0
      assert_operator mobile_metrics["dropdownRight"], :<=, mobile_metrics["viewportWidth"]

      page.current_window.resize_to(1280, 900)
      find(".content-hero").click
      assert_no_selector ".taskbar-feed-menu[open]", visible: :all
    end
  end

  test "page intro copy uses the full content width" do
    {
      "/ctf" => [ ".content-hero-inner", ".content-hero p" ],
      "/blog" => [ ".content-hero-inner", ".content-hero p" ],
      "/about" => [ ".content-hero-inner", ".aboutme-copy" ]
    }.each do |path, (container_selector, copy_selector)|
      page.current_window.resize_to(1280, 1200)
      visit path

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const container = document.querySelector("#{container_selector}").getBoundingClientRect();
          const copy = document.querySelector("#{copy_selector}").getBoundingClientRect();

          return {
            containerWidth: Math.round(container.width),
            copyWidth: Math.round(copy.width)
          };
        })()
      JS

      assert_operator metrics["copyWidth"], :>=, metrics["containerWidth"] * 0.95
    end
  end

  test "main page heroes share spacing and icon surface" do
    baseline = nil

    [ "/blog", "/timeline", "/about" ].each do |path|
      page.current_window.resize_to(1280, 900)
      visit path
      assert_selector "body", wait: Capybara.default_max_wait_time do
        page.evaluate_script(<<~JS)
          (() => {
            const icon = document.querySelector(".content-hero-icon-wrap");
            return icon && window.getComputedStyle(icon).width !== "auto";
          })()
        JS
      end

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const hero = document.querySelector(".content-hero");
          const icon = document.querySelector(".content-hero-icon-wrap");
          const heroStyle = window.getComputedStyle(hero);
          const iconStyle = window.getComputedStyle(icon);

          return {
            paddingTop: heroStyle.paddingTop,
            paddingBottom: heroStyle.paddingBottom,
            iconBackground: iconStyle.backgroundColor,
            iconBorderColor: iconStyle.borderTopColor,
            iconWidth: iconStyle.width,
            iconHeight: iconStyle.height,
            titleFontWeight: window.getComputedStyle(hero.querySelector("h1")).fontWeight
          };
        })()
      JS

      baseline ||= metrics
      assert_equal baseline, metrics, "expected #{path} to use shared content hero metrics"
      assert_equal "700", metrics["titleFontWeight"]
    end
  end

  test "linked content hero titles show an arrow link cue without title underline" do
    _, ctf = repository.ctf_metadata.find { |_, entry| entry["website"].present? }

    visit ctf["writeups"]

    assert_selector ".content-hero-title-link[href='#{ctf["website"]}'][target='_blank'][rel='noopener noreferrer'][title='Open #{ctf["terminal_path"].upcase}']"
    assert_no_selector ".content-hero-title-link .content-hero-link-cue"

    styles = page.evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector(".content-hero-title-link");
        const heading = link.querySelector("h1");
        const linkStyle = window.getComputedStyle(link);
        const headingStyle = window.getComputedStyle(heading);
        const cueStyle = window.getComputedStyle(link, "::after");

        return {
          title: heading.innerText.trim(),
          borderWidth: parseFloat(linkStyle.borderTopWidth),
          textDecorationLine: headingStyle.textDecorationLine,
          cueContent: cueStyle.content,
          cueWidth: parseFloat(cueStyle.width),
          cueHeight: parseFloat(cueStyle.height),
          cueBorderWidth: parseFloat(cueStyle.borderTopWidth),
          cueOpacity: parseFloat(cueStyle.opacity)
        };
      })()
    JS

    assert_equal ctf["terminal_path"].upcase, styles["title"]
    assert_equal 0, styles["borderWidth"]
    assert_equal "none", styles["textDecorationLine"]
    assert_not_equal "none", styles["cueContent"]
    assert_operator styles["cueWidth"], :>, 0
    assert_operator styles["cueHeight"], :>, 0
    assert_operator styles["cueBorderWidth"], :>=, 2
    assert_operator styles["cueOpacity"], :>, 0

    page.current_window.resize_to(320, 900)
    visit ctf["writeups"]
    mobile_link_metrics = page.evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector(".content-hero-title-link");

        return {
          text: link.innerText.trim(),
          overflowX: link.scrollWidth - link.clientWidth
        };
      })()
    JS
    assert_equal ctf["terminal_path"].upcase, mobile_link_metrics["text"]
    assert_operator mobile_link_metrics["overflowX"], :<=, 1
  end

  test "sticky top taskbar reserves compact page space without horizontal offset" do
    {
      "/" => "#landing-top",
      "/ctf" => ".content-hero-inner",
      "/timeline" => ".timeline-shell",
      "/about" => ".content-hero-inner"
    }.each do |path, selector|
      [ 320, 390 ].each do |width|
        page.current_window.resize_to(width, 900)
        visit path

        metrics = nil
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

        loop do
          metrics = page.evaluate_script(<<~JS)
            (() => {
              const taskbar = document.getElementById("top-taskbar");
              const taskbarRect = taskbar.getBoundingClientRect();
              const content = document.querySelector("#{selector}").getBoundingClientRect();
              const viewportWidth = document.documentElement.clientWidth;

              return {
                taskbarPosition: window.getComputedStyle(taskbar).position,
                taskbarTop: Math.round(taskbarRect.top),
                taskbarLeft: Math.round(taskbarRect.left),
                taskbarRight: Math.round(taskbarRect.right),
                viewportWidth,
                contentTop: Math.round(content.top),
                taskbarBottom: Math.round(taskbarRect.bottom),
                contentLeft: Math.round(content.left),
                contentRightGap: Math.round(viewportWidth - content.right)
              };
            })()
          JS

          break if metrics["taskbarPosition"] == "sticky" && metrics["taskbarBottom"].positive?
          break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          sleep 0.05
        end

        assert_equal "sticky", metrics["taskbarPosition"]
        assert_equal 0, metrics["taskbarTop"], "top taskbar drifted away from the viewport top on #{path} at #{width}px"
        assert_equal 0, metrics["taskbarLeft"], "top taskbar drifted away from the viewport edge on #{path} at #{width}px"
        assert_in_delta metrics["viewportWidth"], metrics["taskbarRight"], 1
        assert_operator metrics["contentTop"], :>=, metrics["taskbarBottom"],
                        "top taskbar overlaid content on #{path} at #{width}px"
        assert_in_delta metrics["contentLeft"], metrics["contentRightGap"], 2,
                        "content was horizontally offset by top taskbar on #{path} at #{width}px"
      end
    end
  end

  test "sticky top taskbar does not jump while scrolling compact pages" do
    page.current_window.resize_to(390, 900)
    visit "/timeline"

    measure_taskbar = lambda do
      page.evaluate_script(<<~JS)
        (() => {
          const taskbar = document.getElementById("top-taskbar");

          return {
            position: window.getComputedStyle(taskbar).position,
            top: Math.round(taskbar.getBoundingClientRect().top)
          };
        })()
      JS
    end
    wait_for_sticky_taskbar = lambda do
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

      loop do
        metrics = measure_taskbar.call
        break metrics if metrics["position"] == "sticky" && metrics["top"].abs <= 1

        flunk("top taskbar did not settle into its sticky position") if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        sleep 0.05
      end
    end

    page.execute_script("window.scrollTo(0, 0)")
    before = wait_for_sticky_taskbar.call
    page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")
    bottom = wait_for_sticky_taskbar.call
    page.execute_script("window.scrollTo(0, 0)")
    top = wait_for_sticky_taskbar.call

    assert_in_delta before["top"], bottom["top"], 1
    assert_in_delta before["top"], top["top"], 1
  end

  test "tag links only open a new tab for external destinations" do
    tag_pages = [
      "/",
      "/ctf",
      "/ctf/#{first_ctf_event_with_writeups[:directory]}",
      "/blog",
      "/timeline",
      "/about"
    ]

    checked_tag_link_count = 0

    tag_pages.each do |path|
      visit path
      if path == "/about"
        page.execute_script(<<~JS)
          document.querySelectorAll(".aboutme-section, .aboutme-card").forEach((element) => { element.open = true; });
        JS
      end

      tag_links = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll("a.content-tag-link[href], a.aboutme-card-tag[href]")).map((link) => {
          const url = new URL(link.getAttribute("href"), window.location.origin);

          return {
            className: link.className,
            href: link.getAttribute("href"),
            external: url.origin !== window.location.origin,
            target: link.getAttribute("target"),
            rel: link.getAttribute("rel")
          };
        })
      JS

      checked_tag_link_count += tag_links.length
      tag_links.each do |link|
        if link["external"]
          assert_equal "_blank", link["target"], "external tag link opened in-tab on #{path}: #{link.inspect}"
          assert_includes link["rel"].to_s.split, "noopener", "external tag link missed noopener on #{path}: #{link.inspect}"
          assert_includes link["rel"].to_s.split, "noreferrer", "external tag link missed noreferrer on #{path}: #{link.inspect}"
        else
          assert_nil link["target"], "local tag link opened a new tab on #{path}: #{link.inspect}"
        end
      end
    end

    assert_operator checked_tag_link_count, :>, 0
  end

  test "hidden TBA findings stay out of public finding sections" do
    cves = repository.about_entries(ApplicationController::ABOUTME_CVES_PATH)
    bug_bounties = repository.about_entries(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH)
    bug_bounty_count_label = "#{bug_bounties.length} #{bug_bounties.length == 1 ? 'finding' : 'findings'}"

    visit "/about"
    page.execute_script(<<~JS)
      document.querySelectorAll("#cves, #bug-bounties").forEach((section) => { section.open = true; });
    JS

    assert_no_text "TBA"
    assert_selector "#bug-bounties .aboutme-section-count", text: bug_bounty_count_label
    assert_selector_count "#bug-bounties .aboutme-finding-card", bug_bounties.length
    assert_no_selector "#bug-bounties .aboutme-empty-state"
    assert_selector_count "#cves article.aboutme-finding-card-static", cves.count { |entry| !about_finding_collapsible?(entry) }
    assert_selector_count "#cves article.aboutme-finding-card-cve > details.profile-card-details", cves.count { |entry| about_finding_collapsible?(entry) }
    assert_operator bug_bounties.length, :>=, 1
  end

  test "timeline rail metadata is centered and future events are highlighted dynamically" do
    travel_to Time.zone.local(2026, 9, 1, 12) do
      page.current_window.resize_to(1280, 1000)
      future_items = timeline_items.select { |item| item[:published].to_date > Date.new(2026, 9, 1) }

      visit "/timeline"

      assert_selector ".timeline-item.timeline-item-upcoming[data-upcoming='true']", count: future_items.length
      assert_selector ".timeline-item-upcoming .timeline-side-tags > .content-upcoming-badge:first-child",
                      count: future_items.length,
                      text: "Upcoming"
      assert_no_selector ".timeline-item[data-upcoming='false'] .content-upcoming-badge"
      assert_no_selector ".timeline-item-upcoming .timeline-title", text: /^Upcoming:/

      rail_metrics = page.evaluate_script(<<~JS)
        (() => {
          const center = (rect) => rect.top + (rect.height / 2);
          const items = [...document.querySelectorAll(".timeline-item")];
          const centerDeltas = items.map((item) => {
            const card = item.querySelector(".timeline-content").getBoundingClientRect();
            const date = item.querySelector(".timeline-date").getBoundingClientRect();
            const dot = item.querySelector(".timeline-connector .dot").getBoundingClientRect();

            return {
              date: Math.abs(center(date) - center(card)),
              dot: Math.abs(center(dot) - center(card))
            };
          });
          const upcomingCard = document.querySelector(".timeline-item-upcoming .timeline-content");
          const regularCard = document.querySelector(".timeline-item:not(.timeline-item-upcoming) .timeline-content");
          const dot = document.querySelector(".timeline-connector .dot");
          const upcomingStyle = window.getComputedStyle(upcomingCard);
          const regularStyle = window.getComputedStyle(regularCard);
          const upcomingHeadingStyle = window.getComputedStyle(
            document.querySelector(".timeline-item-upcoming .timeline-date-heading")
          );

          return {
            maxDateCenterDelta: Math.max(...centerDeltas.map((delta) => delta.date)),
            maxDotCenterDelta: Math.max(...centerDeltas.map((delta) => delta.dot)),
            dotColor: window.getComputedStyle(dot).backgroundColor,
            upcomingBorderColor: upcomingStyle.borderTopColor,
            regularBorderColor: regularStyle.borderTopColor,
            upcomingBoxShadow: upcomingStyle.boxShadow,
            upcomingHeadingBorderWidth: upcomingHeadingStyle.borderTopWidth,
            upcomingHeadingBackground: upcomingHeadingStyle.backgroundColor
          };
        })()
      JS

      assert_operator rail_metrics["maxDateCenterDelta"], :<=, 1
      assert_operator rail_metrics["maxDotCenterDelta"], :<=, 1
      assert_equal "rgb(85, 170, 255)", rail_metrics["dotColor"]
      assert_not_equal rail_metrics["regularBorderColor"], rail_metrics["upcomingBorderColor"]
      assert_not_equal "none", rail_metrics["upcomingBoxShadow"]
      assert_equal "0px", rail_metrics["upcomingHeadingBorderWidth"]
      assert_equal "rgba(0, 0, 0, 0)", rail_metrics["upcomingHeadingBackground"]

      page.current_window.resize_to(390, 1000)
      visit "/timeline"

      mobile_metrics = page.evaluate_script(<<~JS)
        (() => {
          const center = (rect) => rect.left + (rect.width / 2);
          const items = [...document.querySelectorAll(".timeline-item")];
          const positions = items.map((item) => {
            const card = item.querySelector(".timeline-content").getBoundingClientRect();
            const date = item.querySelector(".timeline-date").getBoundingClientRect();
            const heading = item.querySelector(".timeline-date-heading").getBoundingClientRect();
            const tags = [...item.querySelector(".timeline-side-tags").children]
              .map((tag) => tag.getBoundingClientRect());
            const tagsLeft = Math.min(...tags.map((tag) => tag.left));
            const tagsRight = Math.max(...tags.map((tag) => tag.right));

            return {
              date: Math.abs(center(date) - center(card)),
              heading: Math.abs(center(heading) - center(card)),
              tags: Math.abs(((tagsLeft + tagsRight) / 2) - center(card)),
              metadataAboveCard: date.bottom <= card.top + 1
            };
          });
          const dateStyle = window.getComputedStyle(document.querySelector(".timeline-date"));
          const tagsStyle = window.getComputedStyle(document.querySelector(".timeline-side-tags"));

          return {
            maxDateCenterDelta: Math.max(...positions.map((position) => position.date)),
            maxHeadingCenterDelta: Math.max(...positions.map((position) => position.heading)),
            maxTagsCenterDelta: Math.max(...positions.map((position) => position.tags)),
            allMetadataAboveCards: positions.every((position) => position.metadataAboveCard),
            dateTextAlign: dateStyle.textAlign,
            tagsJustifyContent: tagsStyle.justifyContent
          };
        })()
      JS

      assert_operator mobile_metrics["maxDateCenterDelta"], :<=, 1
      assert_operator mobile_metrics["maxHeadingCenterDelta"], :<=, 1
      assert_operator mobile_metrics["maxTagsCenterDelta"], :<=, 1
      assert mobile_metrics["allMetadataAboveCards"]
      assert_equal "center", mobile_metrics["dateTextAlign"]
      assert_equal "center", mobile_metrics["tagsJustifyContent"]
    end
  end

  test "ctf writeups are ordered from latest to oldest" do
    event = first_ctf_event_with_multiple_writeups
    expected_titles = event[:writeups].map { |post| post[:title] }

    visit "/ctf/#{event[:directory]}"

    assert_selector ".writeup-overview .blog-post-card", count: expected_titles.length
    assert_no_selector ".writeup-overview .writeup-card"

    titles = all(".writeup-overview .blog-post-title").map(&:text)
    assert_equal expected_titles, titles
  end
end
