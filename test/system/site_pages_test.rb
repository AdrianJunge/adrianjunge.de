require "application_system_test_case"

class SitePagesTest < ApplicationSystemTestCase
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
    assert_operator metrics["variableHeight"], :>=, metrics["scrollHeight"] - 2
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

      assert_not_equal "none", styles["optionTransform"]
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

  test "terminal cd command accepts listed labels" do
    page.current_window.resize_to(1280, 900)
    visit "/"

    find("#terminal-taskbar-button").click
    assert_selector "#terminal-container:not(.terminal-minimized)"
    assert_selector ".xterm-rows", text: "about"

    find(".xterm-helper-textarea", visible: :all).send_keys("cd ctf", :enter)
    assert_current_path "/ctf"

    assert_selector "#terminal-container:not(.terminal-minimized)"
    assert_selector ".xterm-rows", text: "adrian@my-space:/ctf$"
    assert_selector ".xterm-rows", text: "gpnctf"

    find(".xterm-helper-textarea", visible: :all).send_keys("cd gpnctf", :enter)
    assert_current_path "/ctf/gpnctf"
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
    visit "/ctf/umdctf"
    mobile_link_metrics = page.evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector(".content-hero-title-link");

        return {
          text: link.innerText.trim(),
          overflowX: link.scrollWidth - link.clientWidth
        };
      })()
    JS
    assert_equal "UMDCTF", mobile_link_metrics["text"]
    assert_operator mobile_link_metrics["overflowX"], :<=, 1
  end

  test "year filter uses a rounded custom dropdown" do
    [ "/ctf", "/blog" ].each do |path|
      visit path

      assert_selector ".content-filter-year-button"
      assert_selector ".content-filter-select", visible: :hidden

      find(".content-filter-year-button").click
      assert_selector ".content-filter-year-menu", visible: :visible
      hovered_option = all(".content-filter-year-option:not(.is-active)", visible: :visible).first
      page.driver.browser.action.move_to(hovered_option.native).perform

      styles = page.evaluate_script(<<~JS)
        (() => {
          const button = document.querySelector(".content-filter-year-button");
          const menu = document.querySelector(".content-filter-year-menu");
          const select = document.querySelector(".content-filter-select");
          const activeOption = document.querySelector(".content-filter-year-option.is-active");
          const hoveredOption = document.querySelector(".content-filter-year-option:not(.is-active)");
          const buttonStyle = window.getComputedStyle(button);
          const menuStyle = window.getComputedStyle(menu);
          const selectStyle = window.getComputedStyle(select);
          const activeOptionStyle = window.getComputedStyle(activeOption);
          const hoveredOptionStyle = window.getComputedStyle(hoveredOption);

          return {
            buttonRadius: buttonStyle.borderTopLeftRadius,
            menuRadius: menuStyle.borderTopLeftRadius,
            menuBoxShadow: menuStyle.boxShadow,
            nativeOpacity: selectStyle.opacity,
            nativePointerEvents: selectStyle.pointerEvents,
            activeOptionBoxShadow: activeOptionStyle.boxShadow,
            hoveredOptionBackground: hoveredOptionStyle.backgroundColor,
            hoveredOptionBorderColor: hoveredOptionStyle.borderTopColor
          };
        })()
      JS

      assert_equal styles["buttonRadius"], styles["menuRadius"]
      assert_not_equal "0px", styles["menuRadius"]
      assert_not_equal "none", styles["menuBoxShadow"]
      assert_equal "0", styles["nativeOpacity"]
      assert_equal "none", styles["nativePointerEvents"]
      assert_no_match(/3px 0px 0px/, styles["activeOptionBoxShadow"])
      assert_not_equal "rgba(0, 0, 0, 0)", styles["hoveredOptionBackground"]
      assert_not_equal "rgba(0, 0, 0, 0)", styles["hoveredOptionBorderColor"]
    end
  end

  test "compact landing keeps recent post spacing even and hides scroll affordance" do
    page.current_window.resize_to(390, 700)
    expected_card_count = landing_latest_posts.length
    visit "/"

    assert_no_selector "#scroll-down-button", visible: :visible
    assert_selector ".landing-writeup-cards .blog-post-entry", count: expected_card_count

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const container = document.querySelector(".landing-writeup-cards");
        const scrollButton = document.querySelector("#scroll-down-button");
        const cards = [...document.querySelectorAll(".landing-writeup-cards .blog-post-entry")];
        const rects = cards.map((card) => card.getBoundingClientRect());
        const gaps = rects.slice(1).map((rect, index) => Math.round(rect.top - rects[index].bottom));

        return {
          display: window.getComputedStyle(container).display,
          scrollButtonDisplay: window.getComputedStyle(scrollButton).display,
          gaps: gaps
        };
      })()
    JS

    assert_equal "grid", metrics["display"]
    assert_equal "none", metrics["scrollButtonDisplay"]
    assert_operator metrics["gaps"].length, :>=, 1
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
          const kicker = document.querySelector(".landing-kicker").getBoundingClientRect();
          const shell = document.querySelector(".landing-hero-shell").getBoundingClientRect();
          const taskbar = document.getElementById("top-taskbar").getBoundingClientRect();
          const overlaps = (a, b) => !(a.right <= b.left || a.left >= b.right || a.bottom <= b.top || a.top >= b.bottom);

          return {
            emojiOverlapsPanel: overlaps(emoji, panel),
            emojiOverlapsImage: overlaps(emoji, image),
            emojiOverlapsLinks: overlaps(emoji, links),
            kickerTopGap: Math.round(kicker.top - taskbar.bottom),
            titleOverflowsShell: h1.right > shell.right + 1 || h1.left < shell.left - 1
          };
        })()
      JS

      assert_equal false, metrics["emojiOverlapsPanel"], "emoji overlapped profile panel at #{width}px"
      assert_equal false, metrics["emojiOverlapsImage"], "emoji overlapped profile image at #{width}px"
      assert_equal false, metrics["emojiOverlapsLinks"], "emoji overlapped affiliation links at #{width}px"
      assert_operator metrics["kickerTopGap"], :>=, 24, "landing kicker sat too close to the taskbar at #{width}px"
      assert_equal false, metrics["titleOverflowsShell"], "landing title overflowed hero shell at #{width}px"
    end
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

  test "landing recent posts render as evenly spaced full-width rows" do
    page.current_window.resize_to(1280, 1400)
    expected_card_count = landing_latest_posts.length
    visit "/"

    assert_selector ".landing-writeup-cards .blog-post-entry", count: expected_card_count

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const container = document.querySelector(".landing-writeup-cards");
        const cards = [...document.querySelectorAll(".landing-writeup-cards .blog-post-entry")];
        const containerRect = container.getBoundingClientRect();
        const rects = cards.map((card) => card.getBoundingClientRect());
        const gaps = rects.slice(1).map((rect, index) => Math.round(rect.top - rects[index].bottom));

        return {
          gridColumns: window.getComputedStyle(container).gridTemplateColumns.split(" ").length,
          leftEdges: rects.map((rect) => Math.round(rect.left)),
          widths: rects.map((rect) => Math.round(rect.width)),
          containerWidth: Math.round(containerRect.width),
          gaps: gaps
        };
      })()
    JS

    assert_equal 1, metrics["gridColumns"]
    assert_equal 1, metrics["leftEdges"].uniq.length
    metrics["widths"].each do |width|
      assert_in_delta metrics["containerWidth"], width, 1
    end
    assert_operator metrics["gaps"].length, :>=, 1
    assert_in_delta metrics["gaps"].first, metrics["gaps"].last, 1
  end

  test "landing latest notes use the shared post card styling" do
    page.current_window.resize_to(1280, 1400)
    expected_card_count = landing_latest_posts.length
    expected_card_scopes = landing_latest_posts.map { |post| post[:type] == "ctf" ? "writeups" : "blogs" }.uniq
    expected_logo_count = landing_latest_posts.count { |post| landing_post_logo?(post) }
    expected_placeholder_count = landing_latest_posts.count { |post| landing_post_placeholder?(post) }
    expected_svg_count = landing_latest_posts.count { |post| landing_post_inline_svg?(post) }
    expected_writeup_count = landing_latest_posts.count { |post| post[:type] == "ctf" }

    visit "/"
    assert_selector ".landing-writeup-cards .blog-post-card", count: expected_card_count
    assert_selector ".landing-writeup-cards .content-card.blog-post-card", count: expected_card_count
    assert_selector ".landing-writeup-cards .blog-post-card-hitbox[href]", count: expected_card_count, visible: :all
    assert_selector ".landing-writeup-cards .filter-chip", minimum: 1
    assert_selector ".landing-writeup-cards .content-tag-timeline-link[href^='/timeline?tag=']", minimum: 1
    expected_card_scopes.each do |scope|
      assert_selector ".landing-writeup-cards .blog-post-card[data-filter-card='#{scope}']", minimum: 1
    end
    assert_selector ".landing-writeup-cards .blog-post-reading-time", minimum: expected_card_count, text: /min read/
    assert_selector ".landing-writeup-cards .blog-post-card-logo", count: expected_card_count
    assert_selector_count ".landing-writeup-cards .blog-logo", expected_logo_count
    assert_selector_count ".landing-writeup-cards .blog-logo-placeholder", expected_placeholder_count
    if expected_card_scopes.include?("writeups")
      ctf_logo_count = landing_latest_posts.count { |post| post[:type] == "ctf" && landing_post_logo?(post) }
      assert_selector ".landing-writeup-cards .writeup-post-card .blog-post-authors", count: expected_writeup_count
      assert_selector_count ".landing-writeup-cards .writeup-post-card .blog-logo[src*='#{asset_path_prefix}/ctf/']", ctf_logo_count
    end
    landing_authored_posts = landing_latest_posts.select { |post| post[:type] == "ctf" && AuthoredChallenge.from_metadata(post[:metadata] || {}) }
    if landing_authored_posts.any?
      authored_post = landing_authored_posts.first
      authored_timeline_path = timeline_path(tag: AuthoredChallenge::FILTER_LABEL)

      within find(".landing-writeup-cards .blog-post-card", text: authored_post[:title]) do
        assert_selector ".blog-post-meta-row > a.authored-challenge-badge.content-tag-timeline-link[href='#{authored_timeline_path}']:not([target])[rel='noopener']",
                        text: /Authored challenge/
        assert_no_selector ".blog-post-meta-row > a.authored-challenge-badge .content-tag-arrow", text: ">"
        assert_no_selector ".blog-post-meta-row > button.authored-challenge-badge"
        assert_no_selector ".blog-post-meta-row > .authored-challenge-badge.blog-post-static-chip"
      end
      authored_hit = link_hit_target(".landing-writeup-cards .authored-challenge-badge")
      assert_equal URI.join(page.server_url, authored_timeline_path).to_s, authored_hit["href"]
      assert_includes authored_hit["className"], "authored-challenge-badge"
    end
    landing_winner_posts = landing_latest_posts.select { |post| post[:type] == "ctf" && WriteupWinner.from_metadata(post[:metadata] || {}) }
    if landing_winner_posts.any?
      winner_post = landing_winner_posts.first
      winner = WriteupWinner.from_metadata(winner_post[:metadata] || {})
      winner_timeline_path = timeline_path(tag: WriteupWinner::FILTER_LABEL)

      within find(".landing-writeup-cards .blog-post-card", text: winner_post[:title]) do
        assert_selector ".blog-post-meta-row > a.writeup-winner-badge.content-tag-timeline-link[href='#{winner_timeline_path}']:not([target])[rel='noopener']",
                        text: winner[:label]
        assert_no_selector ".blog-post-meta-row > a.writeup-winner-badge .content-tag-arrow", text: ">"
        assert_no_selector ".blog-post-meta-row > button.writeup-winner-badge"
        assert_no_selector ".blog-post-meta-row > .writeup-winner-badge.blog-post-static-chip"
      end
    end
    if expected_card_scopes.include?("blogs")
      blog_logo_count = landing_latest_posts.count { |post| post[:type] == "blog" && landing_post_logo?(post) }
      assert_selector_count ".landing-writeup-cards .blog-post-card[data-filter-card='blogs'] .blog-logo[src*='#{asset_path_prefix}/blog/']", blog_logo_count
    end
    assert_no_selector ".landing-writeup-cards .filter-chip[data-filter-tag]", visible: :all
    assert_no_selector ".landing-writeup-cards .filter-chip.ui-hover-lift", visible: :all
    assert_selector_count ".landing-writeup-cards .blog-post-card-logo svg", expected_svg_count
    timeline_chip_styles = page.evaluate_script(<<~JS)
      (() => {
        const chip = document.querySelector(".landing-writeup-cards .content-tag-timeline-link");
        const style = window.getComputedStyle(chip);

        return {
          href: chip.getAttribute("href"),
          target: chip.getAttribute("target"),
          rel: chip.getAttribute("rel"),
          cursor: style.cursor,
          className: chip.className,
          pointerEvents: style.pointerEvents,
          backgroundColor: style.backgroundColor,
          borderColor: style.borderTopColor,
          boxShadow: style.boxShadow,
          transitionDuration: style.transitionDuration,
          transform: style.transform
        };
      })()
    JS
    assert_match %r{\A/timeline\?tag=}, timeline_chip_styles["href"]
    assert_nil timeline_chip_styles["target"]
    assert_equal "noopener", timeline_chip_styles["rel"]
    assert_equal "pointer", timeline_chip_styles["cursor"]
    assert_includes timeline_chip_styles["className"], "content-tag-timeline-link"
    assert_includes timeline_chip_styles["className"], "content-tag-action"
    assert_not_includes timeline_chip_styles["className"], "content-tag-static"
    assert_equal "auto", timeline_chip_styles["pointerEvents"]
    assert_not_equal "0s", timeline_chip_styles["transitionDuration"]
    assert_equal "none", timeline_chip_styles["transform"]
    find(".landing-writeup-cards .content-tag-timeline-link", match: :first).hover
    timeline_chip_hover_styles = page.evaluate_script(<<~JS)
      (() => {
        const chip = document.querySelector(".landing-writeup-cards .content-tag-timeline-link");
        const style = window.getComputedStyle(chip);

        return {
          backgroundColor: style.backgroundColor,
          borderColor: style.borderTopColor,
          boxShadow: style.boxShadow,
          transform: style.transform
        };
      })()
    JS
    assert_not_equal timeline_chip_styles["transform"], timeline_chip_hover_styles["transform"]

    landing_difficulty_styles = page.evaluate_script(<<~JS)
      (() => {
        const chip = document.querySelector(".landing-writeup-cards .difficulty-badge");
        if (!chip) return null;
        const style = window.getComputedStyle(chip);

        return {
          className: chip.className,
          href: chip.getAttribute("href"),
          target: chip.getAttribute("target"),
          rel: chip.getAttribute("rel"),
          cursor: style.cursor,
          pointerEvents: style.pointerEvents,
          backgroundColor: style.backgroundColor,
          borderColor: style.borderTopColor,
          boxShadow: style.boxShadow,
          transform: style.transform
        };
      })()
    JS
    if landing_difficulty_styles
      assert_includes landing_difficulty_styles["className"], "content-tag-timeline-link"
      assert_includes landing_difficulty_styles["className"], "content-tag-action"
      assert_not_includes landing_difficulty_styles["className"], "content-tag-static"
      assert_match %r{\A/timeline\?tag=}, landing_difficulty_styles["href"]
      assert_nil landing_difficulty_styles["target"]
      assert_equal "noopener", landing_difficulty_styles["rel"]
      assert_equal "pointer", landing_difficulty_styles["cursor"]
      assert_equal "auto", landing_difficulty_styles["pointerEvents"]
      find(".landing-writeup-cards .difficulty-badge", match: :first).hover
      landing_difficulty_hover_styles = page.evaluate_script(<<~JS)
        (() => {
          const chip = document.querySelector(".landing-writeup-cards .difficulty-badge");
          const style = window.getComputedStyle(chip);

          return {
            backgroundColor: style.backgroundColor,
            borderColor: style.borderTopColor,
            boxShadow: style.boxShadow,
            transform: style.transform
          };
        })()
      JS
      assert_not_equal "none", landing_difficulty_hover_styles["transform"]
    end

    landing_styles = post_card_styles(".landing-writeup-cards .blog-post-card")

    visit "/blog"
    assert_selector ".blog-posts-container .blog-post-card"
    blog_styles = post_card_styles(".blog-posts-container .blog-post-card")

    assert_equal blog_styles, landing_styles
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

  test "post pages show reading time in the article header" do
    page.current_window.resize_to(1440, 1200)
    blog_post = first_blog_post
    ctf_post = first_ctf_post

    visit "/blog"
    assert_selector ".blog-posts-container .blog-post-reading-time", minimum: 1, text: /min read/

    visit "/ctf/#{ctf_post[:directory]}"
    assert_selector ".writeup-overview .blog-post-reading-time", minimum: 1, text: /min read/

    visit blog_post[:link]
    assert_selector ".post-meta-line", text: /min read/
    assert_no_selector ".writeup-wrapper.toc-collapsed", visible: :all
    assert_no_selector "#toc[hidden]", visible: :all
    assert_selector "#toc .article-progress[data-word-total]", text: %r{\d+\s*/\s*[\d,.]+\s+words}
    assert_selector ".article-progress-percent", text: /\d+%/
    progress_metrics = page.evaluate_script(<<~JS)
      (() => {
        const element = document.querySelector('.article-progress');
        const toc = document.getElementById('toc');
        const tocBody = document.getElementById('toc-body');
        const rect = element.getBoundingClientRect();
        const tocBodyRect = tocBody.getBoundingClientRect();
        const style = window.getComputedStyle(element);

        return {
          position: style.position,
          inToc: toc.contains(element),
          belowTocBody: rect.top >= tocBodyRect.bottom - 1
        };
      })()
    JS
    assert_equal "static", progress_metrics["position"]
    assert_equal true, progress_metrics["inToc"]
    assert_equal true, progress_metrics["belowTocBody"]
    assert_operator page.evaluate_script("parseInt(document.querySelector('.article-progress').dataset.wordTotal, 10)"), :>, 0
    progress_gradient = page.evaluate_script("window.getComputedStyle(document.querySelector('.article-progress-bar')).backgroundImage")
    assert_includes progress_gradient, "rgb(2, 11, 31)"
    assert_includes progress_gradient, "rgb(125, 211, 252)"
    find("#toc-toggle").click
    assert_selector ".writeup-wrapper.toc-collapsed", visible: :all
    assert_no_selector ".article-progress", visible: :visible

    visit ctf_post[:link]
    assert_selector ".post-meta-line", text: /min read/
    assert_no_selector ".writeup-wrapper.toc-collapsed", visible: :all
    assert_selector "#toc .article-progress[data-word-total]", text: %r{\d+\s*/\s*[\d,.]+\s+words}
    assert_selector ".article-progress-percent", text: /\d+%/

    page.current_window.resize_to(390, 900)
    [ blog_post[:link], ctf_post[:link] ].each do |post_path|
      visit post_path
      assert_no_selector ".article-progress", visible: :visible
      assert_no_selector ".table-of-content", visible: :visible

      mobile_article_layout = page.evaluate_script(<<~JS)
        (() => {
          const wrapper = document.querySelector(".writeup-wrapper");
          const container = document.querySelector(".writeup-container");
          const wrapperRect = wrapper.getBoundingClientRect();
          const containerRect = container.getBoundingClientRect();
          const containerStyle = window.getComputedStyle(container);

          return {
            viewportWidth: document.documentElement.clientWidth,
            wrapperWidth: Math.round(wrapperRect.width),
            containerWidth: Math.round(containerRect.width),
            leftAligned: Math.abs(containerRect.left - wrapperRect.left) <= 1,
            rightAligned: Math.abs(containerRect.right - wrapperRect.right) <= 1,
            flexBasis: containerStyle.flexBasis,
            maxWidth: containerStyle.maxWidth
          };
        })()
      JS

      assert_operator mobile_article_layout["wrapperWidth"], :>=, mobile_article_layout["viewportWidth"] - 40
      assert_in_delta mobile_article_layout["wrapperWidth"], mobile_article_layout["containerWidth"], 1
      assert_equal true, mobile_article_layout["leftAligned"]
      assert_equal true, mobile_article_layout["rightAligned"]
      assert_equal "100%", mobile_article_layout["flexBasis"]
      assert_equal "100%", mobile_article_layout["maxWidth"]
    end
  end

  test "article pages show metadata descriptions before the markdown body" do
    page.current_window.resize_to(1280, 1200)

    [
      [ first_blog_post[:link], first_blog_post[:description], "Post description" ],
      [ first_ctf_post[:link], first_ctf_post[:description], "Challenge description" ]
    ].each do |path, description, label|
      visit path

      assert_selector ".writeup-container > .article-meta-panel > .article-description[aria-label='#{label}']"
      assert_selector ".article-description-heading", text: /description/i
      assert_selector ".article-description p", text: description.to_s.squish
      assert_equal true, page.evaluate_script(<<~JS)
        (() => {
          const container = document.querySelector(".writeup-container");
          const panel = container?.querySelector(":scope > .article-meta-panel");
          const description = panel?.querySelector(":scope > .article-description");
          const markdown = container?.querySelector(":scope > .markdown-content");
          const leadingMeta = [
            ".writeup-badge-groups-article",
            ".writeup-authors-article",
            ".writeup-hints",
            ".writeup-article-actions"
          ].flatMap((selector) => Array.from(panel?.querySelectorAll(`:scope > ${selector}`) || []));

          return Boolean(
            panel &&
            description &&
            markdown &&
            description === panel.lastElementChild &&
            leadingMeta.every((node) => node.compareDocumentPosition(description) & Node.DOCUMENT_POSITION_FOLLOWING) &&
            (description.compareDocumentPosition(markdown) & Node.DOCUMENT_POSITION_FOLLOWING)
          );
        })()
      JS
    end
  end

  test "ctf solve counts and points appear after reading time" do
    visit "/ctf/gpnctf"

    scanwich_card = find(".writeup-post-card", text: "Scanwich Station")
    within scanwich_card do
      assert_selector ".blog-post-challenge-stats", text: "5 solves / 405 points"
      assert_match(/min read\s*·\s*5 solves \/ 405 points/, find(".blog-post-date").text.squish)
    end

    smile_card = find(".writeup-post-card", text: "Smile at me")
    within smile_card do
      assert_selector ".blog-post-challenge-stats", text: "1 solve / 500 points"
      assert_match(/min read\s*·\s*1 solve \/ 500 points/, find(".blog-post-date").text.squish)
    end

    visit "/ctf/gpnctf/Scanwich%20Station"

    assert_selector ".post-meta-line", text: /5 solves \/ 405 points/
    assert_match(/min read\s*·\s*5 solves \/ 405 points/, find(".post-meta-line").text.squish)
    assert_selector ".writeup-year-link[href='https://gpn24.ctf.kitctf.de/'][target='_blank'][rel='noopener noreferrer']",
                    text: /GPNCTF-2026/

    visit "/ctf/gpnctf/Smile%20at%20me"

    assert_selector ".post-meta-line", text: /1 solve \/ 500 points/
    assert_selector ".writeup-year-link[href='https://gpn23.ctf.kitctf.de/'][target='_blank'][rel='noopener noreferrer']",
                    text: /GPNCTF-2025/
  end

  test "post card author links stay clickable above full card hitboxes" do
    page.current_window.resize_to(1280, 1400)
    author_post, author = first_ctf_post_with_author_link

    visit "/"
    if page.has_selector?(".landing-writeup-cards .blog-post-author-link", wait: 0)
      landing_hit = link_hit_target(".landing-writeup-cards .blog-post-author-link")
      assert_match %r{\Ahttps?://|/about}, landing_hit["href"]
      assert_includes landing_hit["className"], "blog-post-author-link"
    end

    visit "/ctf/#{author_post[:directory]}"
    author_selector = ".writeup-overview .blog-post-author-link[href='#{author[:url]}']"
    assert_selector author_selector, text: author[:name]
    overview_hit = link_hit_target(author_selector)
    assert_href_matches author[:url], overview_hit["href"]
    assert_includes overview_hit["className"], "blog-post-author-link"

    visit author_post[:link]
    assert_selector ".writeup-authors-article.blog-post-authors", text: /challenge by/i
    assert_selector ".writeup-authors-article", text: author[:name]
    article_author_selector = ".writeup-authors-article .blog-post-author-link[href='#{author[:url]}']"
    assert_selector article_author_selector, text: author[:name]
    article_hit = link_hit_target(article_author_selector)
    assert_href_matches author[:url], article_hit["href"]
    assert_includes article_hit["className"], "blog-post-author-link"
  end

  test "main content cards share the blue surface treatment" do
    visit "/"
    assert_selector ".landing-writeup-cards .blog-post-card.ui-card-surface", count: landing_latest_posts.length
    latest_styles = card_surface_styles(".landing-writeup-cards .blog-post-card")

    visit "/timeline"
    assert_selector ".timeline-content.ui-card-surface", minimum: 1
    assert_selector ".timeline-content.content-card", minimum: 1
    assert_equal latest_styles, card_surface_styles(".timeline-content")

    visit "/ctf"
    assert_selector ".ctf-card.ui-card-surface", minimum: 1
    assert_selector ".ctf-card.content-card", minimum: 1
    assert_equal latest_styles, card_surface_styles(".ctf-card")

    visit "/ctf/#{first_ctf_event_with_writeups[:directory]}"
    assert_selector ".writeup-overview .blog-post-card.ui-card-surface", minimum: 1
    assert_selector ".writeup-overview .blog-post-card.content-card", minimum: 1
    assert_equal latest_styles, card_surface_styles(".writeup-overview .blog-post-card")

    visit "/blog"
    assert_selector ".blog-posts-container .blog-post-card.ui-card-surface", minimum: 1
    assert_selector ".blog-posts-container .blog-post-card.content-card", minimum: 1
    assert_equal latest_styles, card_surface_styles(".blog-posts-container .blog-post-card")

    visit "/about"
    page.execute_script(<<~JS)
      document.querySelectorAll(".aboutme-section").forEach((section) => { section.open = true; });
    JS
    assert_selector ".aboutme-finding-card.ui-card-surface", minimum: 1
    assert_selector ".aboutme-achievement-card.ui-card-surface", minimum: 1
    assert_equal latest_styles, card_surface_styles(".aboutme-finding-card")
    assert_equal profile_card_highlight_styles(".aboutme-finding-card"), profile_card_highlight_styles("#cves .aboutme-finding-card")
  end

  test "landing page exposes about section counters as direct links" do
    page.current_window.resize_to(1280, 1200)
    visit "/"

    assert_text "creating writeups, collecting CVEs, bounties, and notes"
    assert_text "occasionally convince software to confess"
    assert_no_text "Security researcher and computer science student focused on web security"
    assert_no_text "Welcome to my flag collection"
    assert_selector ".landing-action[href='/timeline']", text: "Timeline"
    assert_selector ".landing-action[href='/about']", text: "About me"
    assert_selector ".landing-typed-line .typed-cursor"
    typed_cursor_layout = page.evaluate_script(<<~JS)
      (() => {
        const line = document.querySelector(".landing-typed-line");
        const typing = document.getElementById("typing");
        const cursor = line.querySelector(".typed-cursor");

        typing.textContent = "";

        const lineStyle = window.getComputedStyle(line);
        const cursorStyle = window.getComputedStyle(cursor);
        const lineRect = line.getBoundingClientRect();
        const cursorRect = cursor.getBoundingClientRect();

        return {
          lineDisplay: lineStyle.display,
          lineAlignItems: lineStyle.alignItems,
          cursorMarginLeft: cursorStyle.marginLeft,
          cursorWithinLine: cursorRect.top >= lineRect.top - 1 && cursorRect.bottom <= lineRect.bottom + 1,
          cursorStartsAtLine: cursorRect.left >= lineRect.left - 1 && cursorRect.left <= lineRect.left + 12
        };
      })()
    JS
    assert_equal "flex", typed_cursor_layout["lineDisplay"]
    assert_equal "center", typed_cursor_layout["lineAlignItems"]
    assert_equal "0px", typed_cursor_layout["cursorMarginLeft"]
    assert_equal true, typed_cursor_layout["cursorWithinLine"]
    assert_equal true, typed_cursor_layout["cursorStartsAtLine"]
    discord_profile = "https://discord.com/users/305624492221267968/"
    kitctf_link = "https://kitctf.de/"
    kit_link = "https://www.kit.edu/"
    assert_selector ".landing-profile-link[href='#{discord_profile}'][target='_blank'][rel='noopener noreferrer'] .landing-profile-image"
    assert_selector ".landing-affiliation-link[href='#{kitctf_link}'][target='_blank'][rel='noopener noreferrer']", text: "KITCTF"
    assert_selector ".landing-affiliation-link[href='#{kit_link}'][target='_blank'][rel='noopener noreferrer']", text: "KIT"
    assert_selector ".landing-affiliation-link[href='#{kitctf_link}'] img"
    assert_selector ".landing-affiliation-link[href='#{kit_link}'] img"
    assert_selector ".landing-affiliation-link-pgp[href='/pgp-vurlo.asc']", text: "PGP key"
    assert_selector ".landing-affiliation-link-pgp img[src*='pgp']"
    assert_selector "footer a[href='mailto:todo@adrianjunge.de'] img[alt='Mail Icon']"
    assert_selector "footer a[href='https://t.me/FullyIncredibleCreativeUsername'][target='_blank'][rel='noopener noreferrer'] img[alt='Telegram Icon']"
    assert File.exist?(Rails.root.join("public", "pgp-vurlo.asc"))
    affiliation_image_size = page.evaluate_script(<<~JS)
      (() => {
        const image = document.querySelector(".landing-affiliation-link[href='#{kitctf_link}'] img");
        const rect = image.getBoundingClientRect();

        return Math.round(rect.width);
      })()
    JS
    assert_operator affiliation_image_size, :>=, 44
    profile_link_styles = page.evaluate_script(<<~JS)
      (() => {
        const profileLink = document.querySelector(".landing-profile-link");
        const profileImage = document.querySelector(".landing-profile-image");
        const profileLinkStyle = window.getComputedStyle(profileLink);
        const profileStyle = window.getComputedStyle(profileImage);

        return {
          profileLinkBorderWidth: profileLinkStyle.borderTopWidth,
          profileImageBorderWidth: profileStyle.borderTopWidth,
          profileLinkBackground: profileLinkStyle.backgroundColor,
          profileImageAnimation: profileStyle.animationName,
          profileImageAnimationDuration: profileStyle.animationDuration
        };
      })()
    JS
    assert_equal "0px", profile_link_styles["profileLinkBorderWidth"]
    assert_equal "0px", profile_link_styles["profileImageBorderWidth"]
    assert_equal "rgba(0, 0, 0, 0)", profile_link_styles["profileLinkBackground"]
    assert_equal "landing-profile-bounce", profile_link_styles["profileImageAnimation"]
    assert_equal "2.35s", profile_link_styles["profileImageAnimationDuration"]
    assert_selector ".landing-metrics.aboutme-stats"
    assert_selector ".landing-metric", count: 4
    assert_selector ".landing-metric.aboutme-stat", count: 4
    assert_selector ".landing-metric:first-child[href='/timeline']", text: "Posts"
    assert_equal "center", page.evaluate_script("window.getComputedStyle(document.querySelector('.landing-metric')).justifyContent")
    landing_metric_surface = page.evaluate_script(<<~JS)
      (() => {
        const group = document.querySelector(".landing-metrics");
        const first = document.querySelector(".landing-metric");
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
    assert_equal "0px", landing_metric_surface["groupGap"]
    assert_equal "rgba(18, 34, 56, 0.9)", landing_metric_surface["groupBackgroundColor"]
    assert_equal "none", landing_metric_surface["groupBackground"]
    assert_equal "rgba(15, 52, 83, 0.7)", landing_metric_surface["firstBackground"]
    assert_equal "none", landing_metric_surface["firstBackgroundImage"]
    find(".landing-metric:first-child").hover
    landing_metric_hover_surface = page.evaluate_script(<<~JS)
      (() => {
        const first = document.querySelector(".landing-metric");
        const style = window.getComputedStyle(first);

        return {
          backgroundColor: style.backgroundColor,
          boxShadow: style.boxShadow
        };
      })()
    JS
    assert_equal "rgba(24, 76, 112, 0.94)", landing_metric_hover_surface["backgroundColor"]
    assert_not_equal "none", landing_metric_hover_surface["boxShadow"]
    assert_selector ".landing-metric:first-child .landing-metric-sublabel", text: /min read/
    metric_order = page.evaluate_script(<<~JS)
      (() => {
        const metric = document.querySelector(".landing-metric:first-child");
        const label = metric.querySelector(".landing-metric-label").getBoundingClientRect();
        const sublabel = metric.querySelector(".landing-metric-sublabel").getBoundingClientRect();

        return {
          sublabelBelowLabel: sublabel.top >= label.bottom - 1
        };
      })()
    JS
    assert_equal true, metric_order["sublabelBelowLabel"]
    page.execute_script("document.querySelector('.landing-metrics').scrollIntoView({ block: 'center' })")

    [
      [ "/about#cves", "CVEs", repository.about_entries(ApplicationController::ABOUTME_CVES_PATH).length ],
      [ "/about#bug-bounties", "Bounties", repository.about_entries(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH).length ]
    ].each do |href, label, count|
      assert_selector ".landing-metric[href='#{href}']", text: label
      assert_selector ".landing-metric[href='#{href}'] .landing-metric-value", text: count.to_s
    end

    assert_selector ".landing-metric[href='/timeline']", text: "Posts"
    assert_selector ".landing-metric[href='/timeline'] .landing-metric-value", text: repository.post_count.to_s
    assert_selector ".landing-metric[href='/about']", text: "& more..."
    assert_no_selector ".landing-metric[href='/about'] .landing-metric-value"
    assert_no_selector ".landing-metric", text: "Created CTF Challenges"
    assert_no_selector ".landing-metric", text: "Certificates"
    assert_no_selector ".landing-metric", text: "Achievements"
    assert_no_selector ".landing-metric[href='/ctf']", text: "CTFs"
    assert_no_selector ".landing-metric", text: "Tags"
    find("#terminal-taskbar-button").click
    assert_selector "#terminal-container:not(.terminal-minimized)"
    assert_selector ".xterm-rows", text: "Email:"
    assert_selector ".xterm-rows", text: "PGP:"
    assert_selector ".xterm-rows", text: "GitHub:"
    assert_selector ".xterm-rows", text: "LinkedIn:"
    assert_selector ".xterm-rows", text: "Discord"
    assert_selector ".xterm-rows", text: "Telegram:"
    terminal_text_without_wraps = page.evaluate_script(<<~JS)
      document.querySelector(".xterm-rows").innerText.replace(/\\s+/g, "")
    JS
    assert_includes terminal_text_without_wraps, "@FullyIncredibleCreativeUsername"
    terminal_contact_order = page.evaluate_script(<<~JS)
      (() => {
        const text = document.querySelector(".xterm-rows").innerText;

        return {
          email: text.indexOf("Email:"),
          pgp: text.indexOf("PGP:"),
          github: text.indexOf("GitHub:"),
          linkedin: text.indexOf("LinkedIn:"),
          discord: text.indexOf("Discord:"),
          telegram: text.indexOf("Telegram:")
        };
      })()
    JS
    assert_operator terminal_contact_order["email"], :>=, 0
    assert_operator terminal_contact_order["email"], :<, terminal_contact_order["pgp"]
    assert_operator terminal_contact_order["pgp"], :<, terminal_contact_order["github"]
    assert_operator terminal_contact_order["github"], :<, terminal_contact_order["linkedin"]
    assert_operator terminal_contact_order["linkedin"], :<, terminal_contact_order["discord"]
    assert_operator terminal_contact_order["discord"], :<, terminal_contact_order["telegram"]
    find("#minimize-terminal").click
    assert_selector "#terminal-container.terminal-minimized", visible: :all
    assert_no_selector "#landing-featured-title", visible: :all
    assert_no_selector ".landing-featured-card", visible: :all
    assert_no_selector ".landing-metric .aboutme-stat-icon", visible: :all
  end

  test "landing metrics add row separators on mobile two-column layouts" do
    page.current_window.resize_to(390, 1200)
    visit "/"

    separators = nil
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

    loop do
      separators = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll(".landing-metric")).map((metric) => {
          const style = window.getComputedStyle(metric);

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

    assert_equal 4, separators.length
    assert_equal "0px", separators[0]["borderTopWidth"]
    assert_equal "0px", separators[1]["borderTopWidth"]
    assert_equal "1px", separators[2]["borderTopWidth"]
    assert_equal "solid", separators[2]["borderTopStyle"]
    assert_equal "1px", separators[3]["borderTopWidth"]
    assert_equal "solid", separators[3]["borderTopStyle"]
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
    assert_selector_count "#cves details.aboutme-finding-card-cve", cves.count { |entry| about_finding_collapsible?(entry) }
    assert_operator bug_bounties.length, :>=, 1
  end

  test "timeline entries are full-card links" do
    page.current_window.resize_to(1280, 1200)
    timeline_post = first_timeline_post_with_tags
    tag_name = first_visible_timeline_tag

    visit "/timeline"

    assert_selector ".timeline-content .timeline-card-hitbox[href]", minimum: 1
    assert_text "CVE"
    assert_text "Blog post"
    first_link = find(".timeline-content .timeline-card-hitbox", match: :first, visible: :all)
    assert first_link[:href].match?(%r{/((ctf/.+/.+)|(blog/.+)|(about#.+))\z})

    timeline_card = find(".timeline-card-hitbox[href='#{timeline_post[:link]}']", visible: :all)
                         .find(:xpath, "./ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' timeline-content ')]")
    page.driver.browser.action.move_to(timeline_card.find(".timeline-title").native).click.perform
    assert_current_path timeline_post[:link]

    visit "/timeline"
    empty_card_area_target = page.evaluate_script(<<~JS)
      (() => {
        const hitbox = document.querySelector(".timeline-card-hitbox[href='#{timeline_post[:link]}']");
        const card = hitbox.closest(".timeline-content");
        card.scrollIntoView({ block: "center", inline: "nearest" });
        const rect = card.getBoundingClientRect();
        const target = document.elementFromPoint(rect.right - 36, rect.bottom - 36);

        target.click();

        return {
          className: target.className,
          href: target.getAttribute("href")
        };
      })()
    JS

    assert_includes empty_card_area_target["className"], "timeline-card-hitbox"
    assert_match %r{#{Regexp.escape(timeline_post[:link])}\z}, empty_card_area_target["href"]
    assert_current_path timeline_post[:link]

    visit "/timeline"
    find(".timeline-tags .timeline-tag-pill", text: tag_name, match: :first).click
    assert_current_path "/timeline?#{Rack::Utils.build_query(tag: tag_name)}"
    assert_selector ".timeline-tags .timeline-tag-pill.is-active", text: tag_name
    assert_selector ".content-filter-panel .filter-chip.is-active", text: tag_name
  end

  test "timeline about links open target cards below the top taskbar" do
    page.current_window.resize_to(1280, 1000)
    timeline_item = first_timeline_about_achievement
    target_id = timeline_item[:link].split("#", 2).last

    visit "/timeline"

    timeline_card = find(".timeline-card-hitbox[href='#{timeline_item[:link]}']", visible: :all)
                    .find(:xpath, "./ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' timeline-content ')]")
    page.driver.browser.action.move_to(timeline_card.find(".timeline-title").native).click.perform
    assert_current_path "/about"
    assert_equal "##{target_id}", page.evaluate_script("window.location.hash")

    anchor_metrics = nil
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

    loop do
      anchor_metrics = page.evaluate_script(<<~JS)
        (() => {
          const taskbar = document.getElementById("top-taskbar").getBoundingClientRect();
          const target = document.getElementById(#{target_id.to_json});
          if (!target) return { targetExists: false };

          const scrollTarget = target.closest(".aboutme-card") || target.closest(".aboutme-section") || target;
          const scrollTargetRect = scrollTarget.getBoundingClientRect();
          const openDetails = [...target.closest(".aboutme-page").querySelectorAll("details")]
            .filter((details) => details.contains(target))
            .map((details) => details.open);

          return {
            targetExists: true,
            allParentsOpen: openDetails.every(Boolean),
            scrollTargetTop: Math.round(scrollTargetRect.top),
            taskbarBottom: Math.round(taskbar.bottom),
            viewportHeight: window.innerHeight
          };
        })()
      JS

      break if anchor_metrics["targetExists"] &&
        anchor_metrics["allParentsOpen"] &&
        anchor_metrics["scrollTargetTop"] >= anchor_metrics["taskbarBottom"] + 8 &&
        anchor_metrics["scrollTargetTop"] <= anchor_metrics["taskbarBottom"] + 48
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.05
    end

    assert anchor_metrics["targetExists"]
    assert anchor_metrics["allParentsOpen"]
    assert_operator anchor_metrics["scrollTargetTop"], :>=, anchor_metrics["taskbarBottom"] + 8
    assert_operator anchor_metrics["scrollTargetTop"], :<=, anchor_metrics["taskbarBottom"] + 48
  end

  test "timeline filters all indexed content" do
    total_items = timeline_items.length
    search_case = timeline_search_case
    certificate_count = timeline_items.count { |item| item[:tags].include?("Certificate") }
    winner_items = timeline_items.select { |item| item[:tags].include?(WriteupWinner::FILTER_LABEL) }
    first_winner_label = winner_items.first&.dig(:writeup_winner, :label) || "Contest win"
    difficulty_case = timeline_difficulty_case
    severity_case = timeline_severity_case
    ctf_competition_case = timeline_ctf_competition_case
    cve_case = timeline_cve_case
    cwe_case = timeline_cwe_case
    tag_case = timeline_tag_case

    visit "/timeline"

    assert_selector ".timeline-content", count: total_items
    assert_selector ".timeline-content .timeline-card-logo", count: total_items
    assert_no_selector ".timeline-content .blog-logo-placeholder"
    timeline_icon_coverage = page.evaluate_script(<<~JS)
      (() => {
        const cards = [...document.querySelectorAll(".timeline-content")];

        return cards.filter((card) => (
          card.querySelector(".timeline-card-logo img") ||
          card.querySelector(".timeline-card-logo svg") ||
          card.querySelector(".timeline-card-logo .category-split-icon")
        )).length;
      })()
    JS
    assert_equal total_items, timeline_icon_coverage
    authored_challenge_timeline_item = timeline_items.find { |item| Array(item[:merged_item_ids]).include?("about-challenge-scanwich-station") }
    assert authored_challenge_timeline_item, "expected Scanwich Station to be merged into its writeup timeline entry"
    assert_selector ".timeline-card-hitbox[href='#{authored_challenge_timeline_item[:link]}']", count: 1, visible: :all
    authored_challenge_timeline_entry = find(".timeline-card-hitbox[href='#{authored_challenge_timeline_item[:link]}']", visible: :all)
                                         .find(:xpath, "./ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' timeline-item ')]")
    within authored_challenge_timeline_entry do
      assert_selector ".timeline-date .timeline-kind-pill", text: "CTF writeup"
      assert_no_selector ".timeline-date .timeline-kind-pill", text: "Created CTF challenge"
      assert_no_selector ".timeline-tags [data-filter-tag='Created CTF challenges']"
    end
    htb_cpts_timeline_item = timeline_items.find { |item| Array(item[:merged_item_ids]).include?("about-certificate-htb-cpts") }
    assert htb_cpts_timeline_item, "expected HTB CPTS certificate to be merged into its blog timeline entry"
    assert_equal "blog-htb-cpts", htb_cpts_timeline_item[:id]
    assert_equal "/blog/htb-cpts", htb_cpts_timeline_item[:link]
    assert_selector ".timeline-card-hitbox[href='/blog/htb-cpts']", count: 1, visible: :all
    assert_no_selector ".timeline-card-hitbox[href='/about#htb-cpts']", visible: :all
    htb_cpts_timeline_entry = find(".timeline-card-hitbox[href='/blog/htb-cpts']", visible: :all)
                              .find(:xpath, "./ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' timeline-item ')]")
    within htb_cpts_timeline_entry do
      assert_selector ".timeline-date .timeline-kind-pill", text: "Blog post"
      assert_selector ".timeline-date .timeline-kind-pill", text: "Certificate"
      assert_selector ".timeline-content .timeline-card-logo"
    end
    assert_timeline_year_counts_match_visible_cards
    timeline_year_count_style = page.evaluate_script(<<~JS)
      (() => {
        const count = document.querySelector(".timeline-year-count");
        const filterCount = document.querySelector("[data-filter-count='timeline']");
        const style = window.getComputedStyle(count);
        const filterCountStyle = window.getComputedStyle(filterCount);

        return {
          className: count.className,
          backgroundColor: style.backgroundColor,
          borderWidth: style.borderTopWidth,
          borderRadius: style.borderTopLeftRadius,
          boxShadow: style.boxShadow,
          color: style.color,
          cursor: style.cursor,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          paddingLeft: style.paddingLeft,
          userSelect: style.userSelect,
          filterCountCursor: filterCountStyle.cursor,
          filterCountUserSelect: filterCountStyle.userSelect
        };
      })()
    JS
    assert_includes timeline_year_count_style["className"], "timeline-year-count"
    assert_not_includes timeline_year_count_style["className"], "bg-slate-800"
    assert_equal "rgba(0, 0, 0, 0)", timeline_year_count_style["backgroundColor"]
    assert_equal "0px", timeline_year_count_style["borderWidth"]
    assert_equal "0px", timeline_year_count_style["borderRadius"]
    assert_equal "0px", timeline_year_count_style["paddingLeft"]
    assert_equal "none", timeline_year_count_style["boxShadow"]
    assert_equal "rgb(254, 243, 199)", timeline_year_count_style["color"]
    assert_equal "default", timeline_year_count_style["cursor"]
    assert_equal "16px", timeline_year_count_style["fontSize"]
    assert_equal "700", timeline_year_count_style["fontWeight"]
    assert_equal "none", timeline_year_count_style["userSelect"]
    assert_equal "default", timeline_year_count_style["filterCountCursor"]
    assert_equal "none", timeline_year_count_style["filterCountUserSelect"]
    timeline_tag_positions = page.evaluate_script(<<~JS)
      (() => {
        const card = [...document.querySelectorAll(".timeline-content")].find((entry) => entry.querySelector(".timeline-tags"));
        const title = card.querySelector(".timeline-title").getBoundingClientRect();
        const tags = card.querySelector(".timeline-tags").getBoundingClientRect();
        const nextContent = card.querySelector(".timeline-meta").getBoundingClientRect();

        return {
          tagsBelowTitle: tags.top >= title.bottom - 1,
          nextContentBelowTags: nextContent.top >= tags.bottom - 1
        };
      })()
    JS
    assert_equal true, timeline_tag_positions["tagsBelowTitle"]
    assert_equal true, timeline_tag_positions["nextContentBelowTags"]
    assert_no_selector ".timeline-source"
    timeline_side_tags = all(".timeline-date .timeline-kind-pill").map { |chip| chip["data-filter-tag"] }
    assert timeline_side_tags.any?
    timeline_side_tags.each do |tag|
      assert ContentTagTaxonomy.content_type?(tag), "Expected #{tag.inspect} to be a timeline side content type tag"
    end
    timeline_card_body_tags = all(".timeline-tags [data-filter-tag]").map { |chip| chip["data-filter-tag"] }
    timeline_card_body_tags.each do |tag|
      assert_not ContentTagTaxonomy.content_type?(tag), "Expected #{tag.inspect} to stay out of the timeline card body tags"
    end
    assert_text "Timeline"
    assert_selector ".content-filter-tag-group-label", text: "CONTENT TYPE"
    assert_selector ".content-filter-tag-group-label", text: "DIFFICULTY"
    assert_selector ".content-filter-tag-group-label", text: "SEVERITY"
    assert_selector ".content-filter-tag-group-label", text: "CTF COMPETITIONS"
    assert_selector ".content-filter-tag-group-label", text: "REPOSITORIES"
    assert_selector ".content-filter-tag-group-label", text: "CVES"
    assert_selector ".content-filter-tag-group-label", text: "CWES"
    assert_selector ".content-filter-tag-group-label", text: "CATEGORIES"
    assert_selector ".content-filter-tag-group-label", text: "TOPICS, PROJECTS, AND SOURCES"
    assert_selector ".content-filter-panel .filter-chip", text: "CVE"
    assert_selector ".content-filter-panel .filter-chip", text: "CTF writeup"
    assert_no_selector ".content-filter-panel .filter-chip", text: /^Created CTF challenges$/
    within find(".content-filter-tag-group", text: "CONTENT TYPE") do
      assert_selector ".filter-chip", text: /^Security Research$/
      assert_selector ".filter-chip", text: /^Slides$/
    end
    assert_selector ".content-filter-panel .filter-chip.difficulty-badge-filter.difficulty-badge-#{difficulty_case[:key]}",
                    text: /^#{Regexp.escape(difficulty_case[:label])}$/
    assert_selector ".content-filter-panel .filter-chip.severity-badge-filter.severity-badge-#{severity_case[:key]}",
                    text: /^#{Regexp.escape(severity_case[:label])}$/
    assert_selector ".content-filter-panel .filter-chip",
                    text: /^#{Regexp.escape(ctf_competition_case[:label])}$/
    assert_selector ".content-filter-panel .filter-chip", text: /^Joomla CMS$/
    assert_selector ".content-filter-panel .filter-chip", text: /^ChurchCRM$/
    assert_selector ".content-filter-panel .filter-chip.cve-badge-filter",
                    text: /^#{Regexp.escape(cve_case[:label])}$/
    assert_selector ".content-filter-panel .filter-chip.cwe-badge-filter",
                    text: /^#{Regexp.escape(cwe_case[:label])}$/
    timeline_items.map { |item| item[:label] }.uniq.each do |label|
      assert_selector ".content-filter-panel .filter-chip", text: /^#{Regexp.escape(label)}$/
    end
    assert_selector ".timeline-tags .difficulty-badge-filter.difficulty-badge-#{difficulty_case[:key]}[data-filter-tag='#{difficulty_case[:label]}']",
                    text: /^#{Regexp.escape(difficulty_case[:label])}$/
    assert_selector ".timeline-tags .severity-badge-filter.severity-badge-#{severity_case[:key]}[data-filter-tag='#{severity_case[:label]}']",
                    text: /^#{Regexp.escape(severity_case[:label])}$/
    assert_selector ".timeline-tags .timeline-tag-pill[data-filter-tag='#{ctf_competition_case[:label]}']",
                    text: /^#{Regexp.escape(ctf_competition_case[:label])}$/
    assert_selector ".timeline-tags .cve-badge-filter[data-filter-tag='#{cve_case[:label]}']",
                    text: /^#{Regexp.escape(cve_case[:label])}$/
    assert_selector ".timeline-tags .cwe-badge-filter[data-filter-tag='#{cwe_case[:label]}']",
                    text: /^#{Regexp.escape(cwe_case[:label])}$/
    assert_selector ".timeline-tags .writeup-winner-badge-timeline[data-filter-tag='Writeup winner']", text: first_winner_label
    within timeline_content_card(timeline_items.find { |item| item[:kind] == "blog" }) do
      assert_selector ".timeline-card-logo"
      assert_selector ".timeline-card-logo .blog-logo, .timeline-card-logo .blog-logo-placeholder"
    end
    within timeline_content_card(timeline_items.find { |item| item[:kind] == "writeup" }) do
      assert_selector ".timeline-card-logo.writeup-post-card-logo"
      assert_selector ".timeline-card-logo.writeup-post-card-logo .blog-logo, .timeline-card-logo.writeup-post-card-logo .category-split-icon, .timeline-card-logo.writeup-post-card-logo svg"
    end
    difficulty_backgrounds = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".content-filter-panel .difficulty-badge-filter")]
        .map((chip) => window.getComputedStyle(chip).getPropertyValue("--difficulty-bg").trim())
        .filter((value, index, values) => values.indexOf(value) === index)
    JS
    assert_operator difficulty_backgrounds.length, :>, 1

    fill_in "timeline-search-input", with: search_case[:query]
    assert_current_path "/timeline?#{Rack::Utils.build_query(q: search_case[:query])}"
    assert_selector "[data-filter-count='timeline']", text: filter_count_text(search_case[:items].length, total_items)
    assert_selector ".timeline-content", text: search_case[:items].first[:title]
    assert_hidden_timeline_item search_case[:items]
    assert_timeline_year_counts_match_visible_cards

    find("[data-filter-reset='timeline']").click
    assert_current_path "/timeline"
    find(".content-filter-panel .filter-chip", text: "Certificate").click
    assert_current_path "/timeline?tag=Certificate"
    assert_selector ".content-filter-panel .filter-chip.is-active", text: "Certificate"
    assert_selector "[data-filter-count='timeline']", text: filter_count_text(certificate_count, total_items)
    assert_selector ".timeline-content", count: certificate_count
    assert_hidden_timeline_item timeline_items.select { |item| item[:tags].include?("Certificate") }
    assert_timeline_year_counts_match_visible_cards

    find("[data-filter-reset='timeline']").click
    find(".content-filter-panel .filter-chip.writeup-winner-badge-filter", text: "Writeup winner").click
    assert_selector ".content-filter-panel .filter-chip.writeup-winner-badge-filter.is-active", text: "Writeup winner"
    assert_selector "[data-filter-count='timeline']", text: filter_count_text(winner_items.length, total_items)
    winner_items.each do |item|
      assert_selector ".timeline-content", text: item[:title]
    end
    assert_hidden_timeline_item winner_items
    assert_timeline_year_counts_match_visible_cards

    find("[data-filter-reset='timeline']").click
    find(".content-filter-panel .filter-chip.difficulty-badge-filter", text: /^#{Regexp.escape(difficulty_case[:label])}$/).click
    assert_selector ".content-filter-panel .filter-chip.difficulty-badge-filter.is-active", text: difficulty_case[:label]
    assert_selector "[data-filter-count='timeline']", text: filter_count_text(difficulty_case[:items].length, total_items)
    assert_selector ".timeline-content", text: difficulty_case[:items].first[:title]
    assert_hidden_timeline_item difficulty_case[:items]
    assert_timeline_year_counts_match_visible_cards

    find("[data-filter-reset='timeline']").click
    find(".timeline-tags .cve-badge-filter", text: /^#{Regexp.escape(cve_case[:label])}$/).click
    assert_selector ".timeline-tags .cve-badge-filter.is-active", text: cve_case[:label]
    assert_selector ".content-filter-panel .cve-badge-filter.is-active", text: cve_case[:label]
    active_timeline_cve_styles = page.evaluate_script(<<~JS)
      (() => {
        const chip = document.querySelector(".timeline-tags .cve-badge-filter.is-active");
        const style = window.getComputedStyle(chip);
        return {
          backgroundColor: style.backgroundColor,
          borderColor: style.borderTopColor
        };
      })()
    JS
    active_timeline_cve_background = active_timeline_cve_styles["backgroundColor"].scan(/[\d.]+/).map(&:to_f)
    active_timeline_cve_border = active_timeline_cve_styles["borderColor"].scan(/[\d.]+/).map(&:to_f)
    assert_in_delta 20, active_timeline_cve_background[0], 2
    assert_in_delta 132, active_timeline_cve_background[1], 6
    assert_in_delta 166, active_timeline_cve_background[2], 8
    assert_operator active_timeline_cve_background[3], :>=, 0.45
    assert_operator active_timeline_cve_background[3], :<=, 0.55
    assert_operator active_timeline_cve_border[0], :>=, 120
    assert_operator active_timeline_cve_border[0], :<=, 180
    assert_operator active_timeline_cve_border[1], :>=, 220
    assert_operator active_timeline_cve_border[1], :<=, 250
    assert_operator active_timeline_cve_border[2], :>=, 245
    assert_operator active_timeline_cve_border[2], :<=, 255
    assert_operator active_timeline_cve_border[1], :>, active_timeline_cve_border[0]
    assert_operator active_timeline_cve_border[2], :>=, active_timeline_cve_border[1]
    assert_operator active_timeline_cve_border[3], :>=, 0.55
    assert_operator active_timeline_cve_border[3], :<=, 0.69
    assert_selector "[data-filter-count='timeline']", text: filter_count_text(cve_case[:items].length, total_items)
    assert_hidden_timeline_item cve_case[:items]
    assert_timeline_year_counts_match_visible_cards

    find("[data-filter-reset='timeline']").click
    find(".timeline-tags .timeline-tag-pill", text: tag_case[:tag], match: :first).click
    assert_selector ".timeline-tags .timeline-tag-pill.is-active", text: tag_case[:tag]
    assert_selector ".content-filter-panel .filter-chip.is-active", text: tag_case[:tag]
    assert_selector "[data-filter-count='timeline']", text: filter_count_text(tag_case[:items].length, total_items)
    assert_selector ".timeline-content", text: tag_case[:items].first[:title]
    assert_hidden_timeline_item tag_case[:items]
    assert_timeline_year_counts_match_visible_cards

    query_year = search_case[:items].first[:published].year.to_s
    visit "/timeline?#{Rack::Utils.build_query(q: search_case[:query], year: query_year, tag: tag_case[:tag])}"
    assert_field "timeline-search-input", with: search_case[:query]
    assert_equal query_year, page.evaluate_script("document.querySelector('[data-filter-year=\"timeline\"]').value")
    assert_selector ".content-filter-panel .filter-chip.is-active", text: tag_case[:tag]
  end

  test "timeline search matches tags and skipped search letters" do
    total_items = timeline_items.length
    tag_search_case = timeline_tag_search_case
    fuzzy_search_case = timeline_fuzzy_search_case
    certificate_items = timeline_items.select { |item| item[:tags].include?("Certificate") }

    visit "/timeline"

    fill_in "timeline-search-input", with: "certificate"
    assert_current_path "/timeline?#{Rack::Utils.build_query(q: "certificate")}"
    assert_selector "[data-filter-count='timeline']", text: filter_count_text(certificate_items.length, total_items)
    assert_equal certificate_items.map { |item| item[:title] }.sort, visible_timeline_titles.sort
    assert_hidden_timeline_item certificate_items

    find("[data-filter-reset='timeline']").click
    assert_current_path "/timeline"

    page.execute_script(<<~JS)
      document.querySelectorAll('[data-filter-card="timeline"]').forEach((card) => {
        card.dataset.filterText = '';
      });
    JS

    fill_in "timeline-search-input", with: tag_search_case[:query]
    assert_current_path "/timeline?#{Rack::Utils.build_query(q: tag_search_case[:query])}"
    assert_selector "[data-filter-count='timeline']", text: filter_count_text(tag_search_case[:items].length, total_items)
    assert_selector ".timeline-content", text: tag_search_case[:exact_items].first[:title]
    assert_hidden_timeline_item tag_search_case[:items]

    visit "/timeline"

    fill_in "timeline-search-input", with: fuzzy_search_case[:query]
    assert_current_path "/timeline?#{Rack::Utils.build_query(q: fuzzy_search_case[:query])}"
    assert_selector "[data-filter-count='timeline']", text: filter_count_text(fuzzy_search_case[:items].length, total_items)
    assert_selector ".timeline-content", text: fuzzy_search_case[:item][:title]
    assert_hidden_timeline_item fuzzy_search_case[:items]
  end

  test "ctf markdown preserves anchors and external links while resolving local images" do
    post = ctf_post_with_anchor_external_link_and_image

    visit post[:link]

    assert_text post[:title]
    assert_selector ".markdown-content a[href^='#']"
    assert_selector ".markdown-content a[href^='http']"
    assert_selector ".markdown-content img[src*='#{asset_path_prefix}/ctf/writeups/']"
  end

  test "table of contents indents nested headings by depth" do
    page.current_window.resize_to(1440, 1200)
    post, top_heading, nested_heading = ctf_post_with_nested_headings

    visit post[:link]
    assert_no_selector ".writeup-wrapper.toc-collapsed", visible: :all

    assert_selector "#toc-body .toc-depth-#{top_heading[:level] - 1}", text: top_heading[:rendered_text]
    assert_selector "#toc-body .toc-depth-#{nested_heading[:level] - 1}", text: nested_heading[:rendered_text]

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const links = [...document.querySelectorAll("#toc-body .toc-anchor")];
        const top = links.find((link) => link.innerText.trim() === #{top_heading[:rendered_text].to_json});
        const nested = links.find((link) => link.innerText.trim() === #{nested_heading[:rendered_text].to_json});

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

    assert_includes metrics["topClass"], "toc-depth-#{top_heading[:level] - 1}"
    assert_includes metrics["nestedClass"], "toc-depth-#{nested_heading[:level] - 1}"
    assert_equal top_heading[:level] > 1, metrics["topMarker"]
    assert_equal nested_heading[:level] > 1, metrics["nestedMarker"]
    assert_operator metrics["nestedLeft"], :>, metrics["topLeft"] + 8
  end

  test "table of contents scrolls target headings below the top taskbar" do
    page.current_window.resize_to(1440, 900)
    visit ctf_post_with_headings[:link]
    assert_selector "#toc-body .toc-anchor", minimum: 1

    candidate_index = page.evaluate_script(<<~JS)
      (() => {
        const links = [...document.querySelectorAll("#toc-body .toc-anchor")];
        const taskbar = document.getElementById("top-taskbar").getBoundingClientRect();
        const configuredHeight = parseFloat(
          window.getComputedStyle(document.documentElement).getPropertyValue("--top-taskbar-height")
        ) || 0;
        const offset = Math.max(taskbar.bottom, configuredHeight) + 16;
        const maxScroll = document.documentElement.scrollHeight - window.innerHeight;

        const candidates = links.map((link, index) => {
          const hash = link.getAttribute("href").replace(/^#/, "");
          const id = decodeURIComponent(hash);
          const anchor = document.getElementById(id);
          const heading = anchor?.closest("h1, h2, h3, h4, h5, h6") || anchor;
          if (!heading) return null;

          const pageTop = window.scrollY + heading.getBoundingClientRect().top;
          return { index, desiredScroll: pageTop - offset };
        }).filter(Boolean);

        const aligned = candidates.find((candidate) => {
          return candidate.desiredScroll > 100 && candidate.desiredScroll < maxScroll - 50;
        });

        return (aligned || candidates[0]).index;
      })()
    JS

    all("#toc-body .toc-anchor", minimum: 1)[candidate_index].click

    metrics = nil
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

    loop do
      metrics = page.evaluate_script(<<~JS)
        (() => {
          let id = window.location.hash.replace(/^#/, "");
          try {
            id = decodeURIComponent(id);
          } catch (_error) {}

          const anchor = id ? document.getElementById(id) : null;
          const heading = anchor?.closest("h1, h2, h3, h4, h5, h6") || anchor;
          const taskbar = document.getElementById("top-taskbar").getBoundingClientRect();
          const headingRect = heading?.getBoundingClientRect();

          return {
            targetExists: Boolean(anchor && heading),
            headingTop: headingRect ? Math.round(headingRect.top) : null,
            taskbarBottom: Math.round(taskbar.bottom)
          };
        })()
      JS

      break if metrics["targetExists"] &&
        metrics["headingTop"] >= metrics["taskbarBottom"] + 8 &&
        metrics["headingTop"] <= metrics["taskbarBottom"] + 48
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.05
    end

    assert metrics["targetExists"]
    assert_operator metrics["headingTop"], :>=, metrics["taskbarBottom"] + 8
    assert_operator metrics["headingTop"], :<=, metrics["taskbarBottom"] + 48
  end

  test "ctf overview cards link directly to writeup overviews" do
    visit "/ctf"

    assert_no_selector ".ctf-button"
    assert_no_text "Website"
    assert_no_text "Writeups"
    assert_selector ".ctf-card .blog-post-card-hitbox[href^='/ctf/']", minimum: 1
    assert_selector ".ctf-card.ui-hover-lift", minimum: 1
    assert_selector ".ctf-card.ui-card-surface", minimum: 1
    assert_no_selector ".ctf-card.ui-hover-scale"

    first_card = find(".ctf-card", match: :first)
    assert_no_selector ".ctf-card .ctf-event-chip"
    assert_no_selector ".ctf-card .ctf-card-cta"
    assert_selector ".ctf-card .ctf-writeup-count-text", minimum: 1, text: /writeups?/
    target_path = URI.parse(first_card.find(".blog-post-card-hitbox", visible: :all)[:href]).path
    ctf_metadata_styles = page.evaluate_script(<<~JS)
      (() => {
        const count = document.querySelector(".ctf-card .ctf-writeup-count-text");
        const readingTime = document.querySelector(".ctf-card .ctf-total-reading-time");
        const countStyle = window.getComputedStyle(count);
        const readingTimeStyle = window.getComputedStyle(readingTime);

        return {
          countClassName: count.className,
          countColor: countStyle.color,
          countBackgroundColor: countStyle.backgroundColor,
          countBorderTopWidth: countStyle.borderTopWidth,
          countBorderTopLeftRadius: countStyle.borderTopLeftRadius,
          countPaddingLeft: countStyle.paddingLeft,
          countFontSize: countStyle.fontSize,
          countFontWeight: countStyle.fontWeight,
          countLineHeight: countStyle.lineHeight,
          readingTimeColor: readingTimeStyle.color,
          readingTimeFontSize: readingTimeStyle.fontSize,
          readingTimeFontWeight: readingTimeStyle.fontWeight,
          readingTimeLineHeight: readingTimeStyle.lineHeight
        };
      })()
    JS
    assert_not_includes ctf_metadata_styles["countClassName"], "content-tag"
    assert_equal "rgb(254, 243, 199)", ctf_metadata_styles["countColor"]
    assert_equal "rgba(0, 0, 0, 0)", ctf_metadata_styles["countBackgroundColor"]
    assert_equal "0px", ctf_metadata_styles["countBorderTopWidth"]
    assert_equal "0px", ctf_metadata_styles["countBorderTopLeftRadius"]
    assert_equal "0px", ctf_metadata_styles["countPaddingLeft"]
    assert_selector ".ctf-card .ctf-total-reading-time", minimum: 1, text: /min read/

    visit target_path
    writeup_metadata_styles = page.evaluate_script(<<~JS)
      (() => {
        const date = document.querySelector(".writeup-overview .blog-post-date-text");
        const readingTime = document.querySelector(".writeup-overview .blog-post-reading-time");
        const dateStyle = window.getComputedStyle(date);
        const readingTimeStyle = window.getComputedStyle(readingTime);

        return {
          dateColor: dateStyle.color,
          dateFontSize: dateStyle.fontSize,
          dateFontWeight: dateStyle.fontWeight,
          dateLineHeight: dateStyle.lineHeight,
          readingTimeColor: readingTimeStyle.color,
          readingTimeFontSize: readingTimeStyle.fontSize,
          readingTimeFontWeight: readingTimeStyle.fontWeight,
          readingTimeLineHeight: readingTimeStyle.lineHeight
        };
      })()
    JS
    assert_equal writeup_metadata_styles["dateColor"], ctf_metadata_styles["countColor"]
    assert_equal writeup_metadata_styles["dateFontSize"], ctf_metadata_styles["countFontSize"]
    assert_equal writeup_metadata_styles["dateFontWeight"], ctf_metadata_styles["countFontWeight"]
    assert_equal writeup_metadata_styles["dateLineHeight"], ctf_metadata_styles["countLineHeight"]
    assert_equal writeup_metadata_styles["readingTimeColor"], ctf_metadata_styles["readingTimeColor"]
    assert_equal writeup_metadata_styles["readingTimeFontSize"], ctf_metadata_styles["readingTimeFontSize"]
    assert_equal writeup_metadata_styles["readingTimeFontWeight"], ctf_metadata_styles["readingTimeFontWeight"]
    assert_equal writeup_metadata_styles["readingTimeLineHeight"], ctf_metadata_styles["readingTimeLineHeight"]

    visit "/ctf"
    first_card = find(".ctf-card", match: :first)
    click_card_link_area(first_card)

    assert_current_path target_path
  end

  test "multi-category writeup cards split the category icon" do
    visit "/ctf/gpnctf"

    scanwich_post = ctf_posts.find { |post| post[:title] == "Scanwich Station" } || flunk("expected Scanwich Station writeup")
    categories = Array(scanwich_post[:metadata]["categories"])
    category_keys = categories.map { |category| ContentCategoryTag.css_key(category) }

    scanwich_card = find(".writeup-post-card", text: "Scanwich Station")
    within scanwich_card do
      assert_selector ".writeup-post-card-logo .category-split-icon[data-category-count='#{category_keys.length}'][aria-label='#{categories.to_sentence} categories']"
      category_keys.each_with_index do |category_key, index|
        assert_selector ".category-split-icon-slice[data-category='#{category_key}'][style*='--category-index: #{index}; --category-count: #{category_keys.length}; --category-clip: polygon(50% 50%'] .category-split-icon-image[src*='ctf/categories/#{category_key}-']", visible: :all
      end
      assert_selector ".category-split-icon-divider", count: category_keys.length, visible: :all
    end

    single_category_card = find(".writeup-post-card", text: "Smile at me")
    within single_category_card do
      assert_no_selector ".category-split-icon"
      assert_selector ".writeup-post-card-logo img.blog-logo[src*='ctf/categories/web-'][alt='Web category']"
    end
  end

  test "content filters search by text tags and year" do
    ctf_total = ctf_overview_items.length
    ctf_tag_case = ctf_overview_tag_case
    ctf_difficulty_case = ctf_overview_difficulty_case
    ctf_search_case = ctf_overview_search_case
    ctf_year_case = ctf_overview_year_case
    writeup_case = writeup_filter_case
    writeup_difficulty_case = writeup_case[:difficulty]
    internal_author_post, internal_author = first_ctf_post_with_internal_author_link

    visit "/ctf"

    ctf_filter_tags = all(".content-filter-panel .content-filter-tag-list [data-filter-tag]").map do |chip|
      chip["data-filter-tag"]
    end
    assert_equal "Writeup winner", ctf_filter_tags.first
    assert_equal "Authored challenge", ctf_filter_tags.second
    assert_equal 1, ctf_filter_tags.count("Writeup winner")
    assert_equal 1, ctf_filter_tags.count("Authored challenge")
    assert_selector ".content-filter-tag-group-label", text: "DIFFICULTY"
    assert_selector ".content-filter-panel .filter-chip.writeup-winner-badge-filter", text: "Writeup winner"
    assert_selector ".content-filter-panel .filter-chip.authored-challenge-badge-filter", text: "Authored challenge"
    assert_selector ".content-filter-panel .filter-chip.difficulty-badge-filter.difficulty-badge-#{ctf_difficulty_case[:key]}",
                    text: /^#{Regexp.escape(ctf_difficulty_case[:label])}$/
    colored_filter_styles = page.evaluate_script(<<~JS)
      (() => {
        const winner = document.querySelector(".content-filter-panel .writeup-winner-badge-filter");
        const authored = document.querySelector(".content-filter-panel .authored-challenge-badge-filter");
        const difficulty = document.querySelector(".content-filter-panel .difficulty-badge-filter.difficulty-badge-#{ctf_difficulty_case[:key]}");
        const winnerStyle = window.getComputedStyle(winner);
        const authoredStyle = window.getComputedStyle(authored);
        const difficultyStyle = window.getComputedStyle(difficulty);

        return {
          winnerBackground: winnerStyle.backgroundColor,
          winnerBorder: winnerStyle.borderTopColor,
          authoredBackground: authoredStyle.backgroundColor,
          authoredBorder: authoredStyle.borderTopColor,
          difficultyBackground: difficultyStyle.backgroundColor,
          difficultyBorder: difficultyStyle.borderTopColor
        };
      })()
    JS
    assert_equal "rgba(14, 116, 144, 0.42)", colored_filter_styles["winnerBackground"]
    assert_equal colored_filter_styles["winnerBackground"], colored_filter_styles["authoredBackground"]
    assert_equal colored_filter_styles["winnerBackground"], colored_filter_styles["difficultyBackground"]
    assert_equal "rgba(125, 211, 252, 0.34)", colored_filter_styles["winnerBorder"]
    assert_equal colored_filter_styles["winnerBorder"], colored_filter_styles["authoredBorder"]
    assert_equal colored_filter_styles["winnerBorder"], colored_filter_styles["difficultyBorder"]
    filter_panel_initial = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector(".content-filter-panel");
        const reset = document.querySelector("[data-filter-reset='ctfs']");
        const resetStyle = window.getComputedStyle(reset);

        return {
          height: Math.round(panel.getBoundingClientRect().height),
          resetVisibility: resetStyle.visibility,
          resetAriaHidden: reset.getAttribute("aria-hidden"),
          resetTabIndex: reset.tabIndex
        };
      })()
    JS
    assert_equal "hidden", filter_panel_initial["resetVisibility"]
    assert_equal "true", filter_panel_initial["resetAriaHidden"]
    assert_equal(-1, filter_panel_initial["resetTabIndex"])
    assert_selector ".content-filter-panel .filter-chip.category-badge-filter.category-badge-#{ContentCategoryTag.css_key(ctf_tag_case[:tag])}",
                    text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i
    assert_selector ".ctf-card .filter-chip.category-badge-filter.category-badge-#{ContentCategoryTag.css_key(ctf_tag_case[:tag])}",
                    text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i
    category_before_content = page.evaluate_script(<<~JS)
      window.getComputedStyle(document.querySelector(".content-filter-panel .filter-chip.category-badge-filter"), "::before").content
    JS
    assert_includes [ "none", "\"\"" ], category_before_content
    assert_selector ".ctf-card .filter-chip.writeup-winner-badge-filter", text: "Writeup winner"
    assert_selector ".ctf-card .filter-chip.authored-challenge-badge-filter", text: "Authored challenge"
    assert_selector ".ctf-card .filter-chip.difficulty-badge-filter.difficulty-badge-#{ctf_difficulty_case[:key]}",
                    text: /^#{Regexp.escape(ctf_difficulty_case[:label])}$/
    ctf_card_tag_order = page.evaluate_script(<<~JS)
      (() => {
        const card = [...document.querySelectorAll(".ctf-card")].find((entry) => {
          const tags = [...entry.querySelectorAll(".blog-post-meta-row > *")];
          return tags.some((tag) => tag.classList.contains("difficulty-badge-filter")) &&
            tags.some((tag) => !tag.classList.contains("difficulty-badge-filter") &&
              !tag.classList.contains("writeup-winner-badge-filter") &&
              !tag.classList.contains("authored-challenge-badge-filter"));
        });
        if (!card) return [];

        return [...card.querySelectorAll(".blog-post-meta-row > *")].map((tag) => {
          if (tag.classList.contains("writeup-winner-badge-filter") || tag.classList.contains("authored-challenge-badge-filter")) return "shiny";
          if (tag.classList.contains("difficulty-badge-filter")) return "difficulty";
          return "category";
        });
      })()
    JS
    assert_includes ctf_card_tag_order, "difficulty"
    assert_includes ctf_card_tag_order, "category"
    assert_operator ctf_card_tag_order.index("difficulty"), :<, ctf_card_tag_order.index("category")
    assert_operator ctf_card_tag_order.index("shiny"), :<, ctf_card_tag_order.index("difficulty") if ctf_card_tag_order.include?("shiny")
    find(".content-filter-panel .filter-chip", text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i).click
    assert_current_path "/ctf?#{Rack::Utils.build_query(tag: ctf_tag_case[:tag])}"
    assert_selector ".content-filter-panel .filter-chip.is-active", text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i
    assert_selector "[data-filter-count='ctfs']", text: filter_count_text(ctf_tag_case[:items].length, ctf_total)
    assert_equal ctf_tag_case[:items].map { |item| item[:name] }, visible_ctf_names
    filter_panel_after_tag = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector(".content-filter-panel");
        const reset = document.querySelector("[data-filter-reset='ctfs']");
        const resetStyle = window.getComputedStyle(reset);

        return {
          height: Math.round(panel.getBoundingClientRect().height),
          resetVisibility: resetStyle.visibility,
          resetAriaHidden: reset.getAttribute("aria-hidden"),
          resetTabIndex: reset.tabIndex
        };
      })()
    JS
    assert_in_delta filter_panel_initial["height"], filter_panel_after_tag["height"], 1
    assert_equal "visible", filter_panel_after_tag["resetVisibility"]
    assert_equal "false", filter_panel_after_tag["resetAriaHidden"]
    assert_equal 0, filter_panel_after_tag["resetTabIndex"]

    find("[data-filter-reset='ctfs']").click
    assert_current_path "/ctf"
    filter_panel_after_reset = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector(".content-filter-panel");
        const reset = document.querySelector("[data-filter-reset='ctfs']");
        const resetStyle = window.getComputedStyle(reset);

        return {
          height: Math.round(panel.getBoundingClientRect().height),
          resetVisibility: resetStyle.visibility,
          resetAriaHidden: reset.getAttribute("aria-hidden"),
          resetTabIndex: reset.tabIndex
        };
      })()
    JS
    assert_in_delta filter_panel_initial["height"], filter_panel_after_reset["height"], 1
    assert_equal "hidden", filter_panel_after_reset["resetVisibility"]
    assert_equal "true", filter_panel_after_reset["resetAriaHidden"]
    assert_equal(-1, filter_panel_after_reset["resetTabIndex"])
    find(".content-filter-panel .filter-chip.difficulty-badge-filter", text: /^#{Regexp.escape(ctf_difficulty_case[:label])}$/).click
    assert_current_path "/ctf?#{Rack::Utils.build_query(tag: ctf_difficulty_case[:label])}"
    assert_selector ".content-filter-panel .filter-chip.difficulty-badge-filter.is-active", text: ctf_difficulty_case[:label]
    active_difficulty_styles = page.evaluate_script(<<~JS)
      (() => {
        const chip = document.querySelector(".content-filter-panel .filter-chip.difficulty-badge-filter.is-active");
        const style = window.getComputedStyle(chip);
        return {
          boxShadow: style.boxShadow,
          transform: style.transform
        };
      })()
    JS
    assert_not_equal "none", active_difficulty_styles["boxShadow"]
    assert_equal "none", active_difficulty_styles["transform"]
    assert_selector "[data-filter-count='ctfs']", text: filter_count_text(ctf_difficulty_case[:items].length, ctf_total)
    assert_equal ctf_difficulty_case[:items].map { |item| item[:name] }, visible_ctf_names

    find("[data-filter-reset='ctfs']").click
    assert_current_path "/ctf"
    assert_selector "[data-filter-count='ctfs']", text: filter_count_text(ctf_total, ctf_total)
    fill_in "ctf-search-input", with: ctf_search_case[:query]
    assert_current_path "/ctf?#{Rack::Utils.build_query(q: ctf_search_case[:query])}"
    assert_selector "[data-filter-count='ctfs']", text: filter_count_text(ctf_search_case[:items].length, ctf_total)
    assert_selector ".content-filter-panel .search-wrapper.is-filled #ctf-search-clear"
    search_visual_styles = page.evaluate_script(<<~JS)
      (() => {
        const input = document.getElementById("ctf-search-input");
        const wrapper = input.closest(".search-wrapper");
        const clearButton = document.getElementById("ctf-search-clear");
        const inputStyle = window.getComputedStyle(input);
        const wrapperBefore = window.getComputedStyle(wrapper, "::before");
        const clearStyle = window.getComputedStyle(clearButton);
        const inputRect = input.getBoundingClientRect();
        const clearRect = clearButton.getBoundingClientRect();
        const inputCenterY = inputRect.top + (inputRect.height / 2);
        const clearCenterY = clearRect.top + (clearRect.height / 2);

        return {
          inputBoxShadow: inputStyle.boxShadow,
          wrapperBeforeOpacity: parseFloat(wrapperBefore.opacity),
          clearButtonBackground: clearStyle.backgroundColor,
          clearButtonPosition: clearStyle.position,
          clearButtonMarginLeft: clearStyle.marginLeft,
          clearButtonRightInset: Math.round(inputRect.right - clearRect.right),
          clearButtonCenterDelta: Math.abs(clearCenterY - inputCenterY),
          clearButtonWithinInput:
            clearRect.left >= inputRect.left &&
            clearRect.right <= inputRect.right &&
            clearRect.top >= inputRect.top &&
            clearRect.bottom <= inputRect.bottom
        };
      })()
    JS
    assert_not_equal "none", search_visual_styles["inputBoxShadow"]
    assert_operator search_visual_styles["wrapperBeforeOpacity"], :>, 0
    assert_not_equal "rgba(0, 0, 0, 0)", search_visual_styles["clearButtonBackground"]
    assert_equal "absolute", search_visual_styles["clearButtonPosition"]
    assert_equal "0px", search_visual_styles["clearButtonMarginLeft"]
    assert_operator search_visual_styles["clearButtonRightInset"], :>=, 6
    assert_operator search_visual_styles["clearButtonCenterDelta"], :<=, 1
    assert_equal true, search_visual_styles["clearButtonWithinInput"]
    assert_equal ctf_search_case[:items].map { |item| item[:name] }, visible_ctf_names

    find("[data-filter-reset='ctfs']").click
    assert_current_path "/ctf"
    assert_selector "[data-filter-count='ctfs']", text: filter_count_text(ctf_total, ctf_total)
    select_filter_year("ctfs", ctf_year_case[:year].to_s)
    assert_current_path "/ctf?#{Rack::Utils.build_query(year: ctf_year_case[:year])}"
    assert_selector "[data-filter-count='ctfs']", text: filter_count_text(ctf_year_case[:items].length, ctf_total)
    assert_equal ctf_year_case[:items].map { |item| item[:name] }, visible_ctf_names
    filter_panel_after_year = page.evaluate_script(<<~JS)
      Math.round(document.querySelector(".content-filter-panel").getBoundingClientRect().height)
    JS
    assert_in_delta filter_panel_initial["height"], filter_panel_after_year, 1

    visit "/ctf?#{Rack::Utils.build_query(q: ctf_search_case[:query], year: ctf_year_case[:year], tag: ctf_tag_case[:tag])}"
    assert_field "ctf-search-input", with: ctf_search_case[:query]
    assert_equal ctf_year_case[:year].to_s, page.evaluate_script("document.querySelector('[data-filter-year=\"ctfs\"]').value")
    assert_selector ".content-filter-panel .filter-chip.is-active", text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i

    visit "/ctf/#{writeup_case[:directory]}"
    assert_selector ".blog-post-authors", text: "Challenge by"
    writeup_filter_initial_height = page.evaluate_script(<<~JS)
      Math.round(document.querySelector(".content-filter-panel").getBoundingClientRect().height)
    JS
    assert_selector ".content-filter-tags-label", text: "TAGS"
    assert_selector ".content-filter-tag-group-label", text: "DIFFICULTY"
    assert_selector ".content-filter-panel .filter-chip.difficulty-badge-filter.difficulty-badge-#{writeup_difficulty_case[:key]}",
                    text: /^#{Regexp.escape(writeup_difficulty_case[:label])}$/
    assert_selector ".content-filter-panel .filter-chip.category-badge-filter.category-badge-#{ContentCategoryTag.css_key(writeup_case[:tag])}",
                    text: /^#{Regexp.escape(writeup_case[:tag])}$/i

    within ".content-filter-panel" do
      find(".filter-chip.difficulty-badge-filter", text: /^#{Regexp.escape(writeup_difficulty_case[:label])}$/).click
      assert_selector ".filter-chip.difficulty-badge-filter.is-active", text: writeup_difficulty_case[:label]
    end
    assert_current_path "/ctf/#{writeup_case[:directory]}?#{Rack::Utils.build_query(tag: writeup_difficulty_case[:label])}"
    writeup_filter_after_tag_height = page.evaluate_script(<<~JS)
      Math.round(document.querySelector(".content-filter-panel").getBoundingClientRect().height)
    JS
    assert_in_delta writeup_filter_initial_height, writeup_filter_after_tag_height, 1
    assert_selector "[data-filter-count='writeups']", text: filter_count_text(writeup_difficulty_case[:posts].length, writeup_case[:posts].length)
    assert_equal writeup_difficulty_case[:posts].map { |post| post[:title] }, visible_writeup_titles

    find("[data-filter-reset='writeups']").click
    assert_current_path "/ctf/#{writeup_case[:directory]}"
    within ".content-filter-panel" do
      find(".filter-chip.category-badge-filter", text: /^#{Regexp.escape(writeup_case[:tag])}$/i).click
      assert_selector ".filter-chip.category-badge-filter.is-active", text: /^#{Regexp.escape(writeup_case[:tag])}$/i
    end
    assert_current_path "/ctf/#{writeup_case[:directory]}?#{Rack::Utils.build_query(tag: writeup_case[:tag])}"
    assert_selector "[data-filter-count='writeups']", text: filter_count_text(writeup_case[:tag_posts].length, writeup_case[:posts].length)
    assert_equal writeup_case[:tag_posts].map { |post| post[:title] }, visible_writeup_titles

    find("[data-filter-reset='writeups']").click
    assert_current_path "/ctf/#{writeup_case[:directory]}"
    assert_selector "[data-filter-count='writeups']", text: filter_count_text(writeup_case[:posts].length, writeup_case[:posts].length)
    select_filter_year("writeups", writeup_case[:year].to_s)
    assert_current_path "/ctf/#{writeup_case[:directory]}?#{Rack::Utils.build_query(year: writeup_case[:year])}"
    assert_selector "[data-filter-count='writeups']", text: filter_count_text(writeup_case[:year_posts].length, writeup_case[:posts].length)
    assert_equal writeup_case[:year_posts].map { |post| post[:title] }, visible_writeup_titles

    visit "/ctf/#{internal_author_post[:directory]}"
    assert_selector ".blog-post-author-link[href='#{internal_author[:url]}']", text: internal_author[:name]
  end

  test "filter chips clear active state when tapped twice" do
    ctf_tag_case = ctf_overview_tag_case

    visit "/ctf"

    chip = find(".content-filter-panel .filter-chip", text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i)
    chip.click
    assert_selector ".content-filter-panel .filter-chip.is-active", text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i

    chip.click
    assert_no_selector ".content-filter-panel .filter-chip.is-active", text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i
    assert_selector "[data-filter-count='ctfs']", text: filter_count_text(ctf_overview_items.length, ctf_overview_items.length)
  end

  test "filter panel marks tags that cannot combine with the current filters" do
    tag_pair = ctf_uncombinable_tag_pair

    visit "/ctf"

    find(".content-filter-panel .filter-chip", text: /^#{Regexp.escape(tag_pair[:first])}$/i).click
    assert_current_path "/ctf?#{Rack::Utils.build_query(tag: tag_pair[:first])}"
    assert_selector ".content-filter-panel .filter-chip.is-active", text: /^#{Regexp.escape(tag_pair[:first])}$/i

    uncombinable_state = page.evaluate_script(<<~JS)
      (() => {
        const chip = [...document.querySelectorAll(".content-filter-panel .filter-chip")]
          .find((candidate) => candidate.dataset.filterTag === #{tag_pair[:second].to_json});

        return {
          found: Boolean(chip),
          className: chip?.className || "",
          ariaDisabled: chip?.getAttribute("aria-disabled"),
          ariaLabel: chip?.getAttribute("aria-label"),
          combinable: chip?.dataset.filterCombinable,
          tabIndex: chip?.tabIndex,
          title: chip?.getAttribute("title")
        };
      })()
    JS

    assert_equal true, uncombinable_state["found"]
    assert_includes uncombinable_state["className"], "is-uncombinable"
    assert_equal "true", uncombinable_state["ariaDisabled"]
    assert_equal "false", uncombinable_state["combinable"]
    assert_equal(-1, uncombinable_state["tabIndex"])
    assert_includes uncombinable_state["ariaLabel"], "no results"
    assert_equal "No results with current filters", uncombinable_state["title"]

    find(".content-filter-panel .filter-chip", text: /^#{Regexp.escape(tag_pair[:second])}$/i).click
    assert_current_path "/ctf?#{Rack::Utils.build_query(tag: tag_pair[:first])}"
    assert_selector ".content-filter-panel .filter-chip.is-active", count: 1
    assert_no_selector ".content-filter-panel .filter-chip.is-active", text: /^#{Regexp.escape(tag_pair[:second])}$/i

    find("[data-filter-reset='ctfs']").click
    assert_no_selector ".content-filter-panel .filter-chip.is-uncombinable"
  end

  test "blog filters search text and publish year" do
    blog_total = blog_posts.length
    tag_case = blog_tag_case
    search_case = blog_search_case
    year_case = blog_year_case
    logo_posts = blog_posts.select { |post| repository.blog_metadata.dig(post[:slug], "logo").present? }

    visit "/blog"

    assert_selector ".content-filter-tag-group-label", text: "CONTENT TYPE"
    within find(".content-filter-tag-group", text: "CONTENT TYPE") do
      assert_selector ".filter-chip", text: /^Security Research$/
    end
    assert_selector ".content-filter-panel .filter-chip", text: tag_case[:tag]
    assert_selector ".blog-post-card", text: search_case[:post][:title]
    assert_selector ".blog-post-card[data-filter-tags*='Security Research']"
    assert_selector ".blog-post-card[data-filter-tags*='#{tag_case[:tag]}']"
    assert_selector ".blog-post-card[data-filter-card='blogs'] .blog-logo", minimum: logo_posts.length if logo_posts.any?
    if (privilege_escalation_post = blog_posts.find { |post| Array(post[:categories]).include?("Privilege Escalation") })
      within find(".blog-post-card", text: privilege_escalation_post[:title]) do
        assert_selector ".category-badge.category-badge-privesc", text: "Privilege Escalation"
      end
      category_before_content = page.evaluate_script(<<~JS)
        window.getComputedStyle(document.querySelector(".blog-post-card .category-badge-privesc"), "::before").content
      JS
      assert_includes [ "none", "\"\"" ], category_before_content
    end

    visit "/blog?#{Rack::Utils.build_query(tag: tag_case[:tag])}"
    assert_selector ".content-filter-panel .filter-chip.is-active", text: /^#{Regexp.escape(tag_case[:tag])}$/i
    assert_selector "[data-filter-count='blogs']", text: filter_count_text(tag_case[:items].length, blog_total)

    find("[data-filter-reset='blogs']").click
    assert_current_path "/blog"
    fill_in "blog-search-input", with: search_case[:query]
    assert_current_path "/blog?#{Rack::Utils.build_query(q: search_case[:query])}"
    assert_selector "[data-filter-count='blogs']", text: filter_count_text(search_case[:items].length, blog_total)
    assert_equal search_case[:items].map { |post| post[:title] }.sort, visible_blog_titles.sort

    find("[data-filter-reset='blogs']").click
    assert_current_path "/blog"
    select_filter_year("blogs", year_case[:year].to_s)
    assert_current_path "/blog?#{Rack::Utils.build_query(year: year_case[:year])}"
    assert_selector "[data-filter-count='blogs']", text: filter_count_text(year_case[:items].length, blog_total)
    assert_equal year_case[:items].map { |post| post[:title] }.sort, visible_blog_titles.sort

    find("[data-filter-reset='blogs']").click
    assert_current_path "/blog"
    normal_result_gap = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector(".content-filter-panel").getBoundingClientRect();
        const firstCard = document.querySelector(".blog-post-card").getBoundingClientRect();

        return Math.round(firstCard.top - panel.bottom);
      })()
    JS
    unmatched_blog_query = "zzzzzzzzzzzzzzzz"
    fill_in "blog-search-input", with: unmatched_blog_query
    assert_current_path "/blog?#{Rack::Utils.build_query(q: unmatched_blog_query)}"
    assert_selector "[data-filter-count='blogs']", text: filter_count_text(0, blog_total)
    assert_selector ".content-filter-empty", text: "No blog posts match the current filters."
    assert_no_selector ".blog-post-card"
    empty_result_gap = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector(".content-filter-panel").getBoundingClientRect();
        const empty = document.querySelector(".content-filter-empty").getBoundingClientRect();

        return Math.round(empty.top - panel.bottom);
      })()
    JS
    assert_in_delta normal_result_gap, empty_result_gap, 1
  end

  test "blog and writeup cards keep full-card navigation" do
    blog_post = first_blog_post
    writeup_post = first_ctf_post

    visit "/blog"

    click_card_link_area(find(".blog-post-card", text: blog_post[:title]))
    assert_current_path blog_post[:link]
    assert_selector ".writeup-title", text: blog_post[:title]

    visit "/ctf/#{writeup_post[:directory]}"
    assert_selector ".blog-post-card .difficulty-badge", minimum: 1
    click_card_link_area(find(".blog-post-card", text: writeup_post[:title]))
    assert_current_path writeup_post[:link]
    assert_selector ".writeup-title", text: writeup_post[:title]
    ctf_event_year = writeup_post[:metadata]["ctf_year"].presence ||
                     writeup_post[:metadata]["year"].presence ||
                     writeup_post[:published].year
    expected_ctf_url = writeup_event_url_for(writeup_post)
    assert_selector ".writeup-year-link[href='#{expected_ctf_url}'][target='_blank'][rel='noopener noreferrer']",
                    text: /#{Regexp.escape(writeup_post[:which].upcase)}-#{ctf_event_year}/
    difficulty = WriteupDifficulty.from_metadata(writeup_post[:metadata])
    assert_selector ".writeup-badges-article .difficulty-badge-#{difficulty[:key]}.difficulty-badge-article", text: difficulty[:label]
    assert_selector ".writeup-badges-article .category-badge", minimum: 1
    article_tag_styles = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".writeup-badges-article .difficulty-badge, .writeup-badges-article .category-badge")].map((tag) => {
        const style = window.getComputedStyle(tag);
        return {
          href: tag.getAttribute("href"),
          className: tag.className,
          cursor: style.cursor,
          transitionDuration: style.transitionDuration,
          transform: style.transform
        };
      })
    JS
    assert article_tag_styles.any?
    assert article_tag_styles.all? { |styles| styles["href"].to_s.start_with?("/timeline?tag=") }
    assert article_tag_styles.all? { |styles| styles["className"].include?("content-tag-timeline-link") }
    assert article_tag_styles.all? { |styles| styles["cursor"] == "pointer" }
    assert article_tag_styles.all? { |styles| styles["transitionDuration"] != "0s" }
    assert article_tag_styles.all? { |styles| styles["transform"] == "none" }
  end

  test "blog CTF event and writeup cards show complete descriptions" do
    blog_post = blog_posts.max_by { |post| post[:description].to_s.length }
    ctf_post = ctf_posts.max_by { |post| post[:description].to_s.length }
    ctf_name, ctf_event = repository.ctf_metadata.max_by { |_name, event| event["description"].to_s.length }
    cases = [
      {
        path: blog_path,
        card_selector: ".blog-post-card",
        title_selector: ".blog-post-title",
        description_selector: ".blog-post-description",
        title: blog_post[:title],
        description: blog_post[:description]
      },
      {
        path: ctf_path,
        card_selector: ".ctf-card",
        title_selector: ".ctf-name",
        description_selector: ".ctf-description",
        title: ctf_name,
        description: ctf_event["description"]
      },
      {
        path: "/ctf/#{ctf_post[:directory]}",
        card_selector: ".writeup-post-card",
        title_selector: ".blog-post-title",
        description_selector: ".blog-post-description",
        title: ctf_post[:title],
        description: ctf_post[:description]
      }
    ]

    cases.each do |test_case|
      visit test_case[:path]

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const card = [...document.querySelectorAll(#{test_case[:card_selector].to_json})]
            .find((candidate) => candidate.querySelector(#{test_case[:title_selector].to_json})?.innerText.trim() === #{test_case[:title].to_json});
          const description = card?.querySelector(#{test_case[:description_selector].to_json});
          if (!description) return null;

          const style = window.getComputedStyle(description);
          return {
            text: description.textContent.replace(/\s+/g, " ").trim(),
            lineClamp: style.webkitLineClamp,
            overflow: style.overflow,
            visibleHeight: Math.ceil(description.getBoundingClientRect().height),
            contentHeight: description.scrollHeight
          };
        })()
      JS

      assert metrics, "expected description for #{test_case[:title]} on #{test_case[:path]}"
      assert_equal test_case[:description].to_s.squish, metrics["text"]
      assert_not_equal "2", metrics["lineClamp"]
      assert_equal "visible", metrics["overflow"]
      assert_operator metrics["visibleHeight"] + 1, :>=, metrics["contentHeight"]
    end
  end

  test "article previous and next navigation stays within its content type" do
    blog_case = adjacent_post_case(blog_posts, "blog posts")
    ctf_case = adjacent_post_case(ctf_posts, "CTF writeups")

    visit blog_case[:post][:link]
    assert_selector ".next-previous-writeups"
    assert_selector ".previous-writeup-btn", text: blog_case[:previous][:title]
    assert_selector ".next-writeup-btn", text: blog_case[:next][:title]
    assert_no_selector ".next-previous-writeups a[href^='/ctf/']", visible: :all

    find(".previous-writeup-btn").click
    assert_current_path blog_case[:previous][:link]

    visit ctf_case[:post][:link]
    assert_selector ".next-previous-writeups"
    assert_selector ".previous-writeup-btn", text: "#{ctf_case[:previous][:which].upcase} - #{ctf_case[:previous][:title]}"
    assert_selector ".next-writeup-btn", text: "#{ctf_case[:next][:which].upcase} - #{ctf_case[:next][:title]}"
    assert_no_selector ".next-previous-writeups a[href^='/blog/']", visible: :all

    find(".next-writeup-btn").click
    assert_current_path ctf_case[:next][:link]
  end

  test "writeup optional hints render as overview counts and article spoilers" do
    page.current_window.resize_to(1440, 1200)
    post = ctf_post_with_hints
    hints = writeup_hints_for(post)
    hint_count_label = "#{hints.length} #{hints.length == 1 ? "hint" : "hints"}"

    visit "/ctf/#{post[:directory]}"

    within find(".blog-post-card", text: post[:title]) do
      assert_selector ".writeup-hints-chip", text: hint_count_label
      assert_no_selector ".writeup-hints-chip[data-filter-tag]", visible: :all
    end

    visit post[:link]

    assert_no_selector "details.writeup-hints", visible: :all
    assert_selector "section.writeup-hints.writeup-hints-spoilers"
    assert_selector ".writeup-hints-summary", text: "Hints"
    assert_selector ".writeup-hints-count", text: hint_count_label
    assert_selector ".writeup-hints-list .writeup-hint-spoiler.is-hidden", count: hints.length
    assert_selector ".writeup-hint-unhide", count: hints.length
    assert_equal true, page.evaluate_script(<<~JS)
      (() => {
        const hints = document.querySelector(".writeup-container > .article-meta-panel > .writeup-hints");
        return hints?.nextElementSibling?.classList.contains("article-description") || false;
      })()
    JS
    assert_no_selector ".writeup-wrapper.toc-collapsed", visible: :all
    assert_selector ".article-progress-percent"
    progress_state = page.evaluate_script(<<~JS)
      (() => {
        return new Promise((resolve) => {
          requestAnimationFrame(() => {
            const progress = document.querySelector(".article-progress");
            const article = document.querySelector(".writeup-container > .markdown-content");
            const firstMarkdown = document.querySelector(".markdown-content");
            const currentText = progress.querySelector("[data-article-progress-current]").innerText;
            const percentText = progress.querySelector("[data-article-progress-percent]").innerText;

            resolve({
              firstMarkdownIsHint: firstMarkdown !== article,
              currentWords: parseInt(currentText.replace(/\\D/g, ""), 10),
              percent: parseInt(percentText, 10),
              totalWords: parseInt(progress.dataset.wordTotal, 10)
            });
          });
        });
      })()
    JS
    assert_equal true, progress_state["firstMarkdownIsHint"]
    assert_operator progress_state["percent"], :<, 100
    assert_operator progress_state["currentWords"], :<, progress_state["totalWords"]

    inline_code = hints.join(" ")[/`([^`]+)`/, 1]
    assert_selector ".writeup-hint-spoiler-content[aria-hidden='true'] code", text: inline_code if inline_code

    spoiler_state = page.evaluate_script(<<~JS)
      (() => {
        const spoiler = document.querySelector(".writeup-hint-spoiler");
        const content = spoiler.querySelector(".writeup-hint-spoiler-content");
        const button = spoiler.querySelector(".writeup-hint-unhide");
        const style = window.getComputedStyle(content);

        return {
          hidden: spoiler.classList.contains("is-hidden"),
          revealed: spoiler.classList.contains("is-revealed"),
          ariaHidden: content.getAttribute("aria-hidden"),
          buttonText: button.innerText.trim(),
          buttonExpanded: button.getAttribute("aria-expanded"),
          filter: style.filter
        };
      })()
    JS
    assert_equal true, spoiler_state["hidden"]
    assert_equal false, spoiler_state["revealed"]
    assert_equal "true", spoiler_state["ariaHidden"]
    assert_equal "expose", spoiler_state["buttonText"].downcase
    assert_equal "false", spoiler_state["buttonExpanded"]
    assert_includes spoiler_state["filter"], "blur"

    find(".writeup-hint-unhide", match: :first).click

    revealed_state = page.evaluate_async_script(<<~JS)
      (() => {
        const done = arguments[0];
        const started = performance.now();
        const readState = () => {
          const spoiler = document.querySelector(".writeup-hint-spoiler");
          const content = spoiler.querySelector(".writeup-hint-spoiler-content");
          const button = spoiler.querySelector(".writeup-hint-unhide");
          const style = window.getComputedStyle(content);

          return {
            hidden: spoiler.classList.contains("is-hidden"),
            revealed: spoiler.classList.contains("is-revealed"),
            ariaHidden: content.getAttribute("aria-hidden"),
            buttonHidden: button.hidden,
            buttonExpanded: button.getAttribute("aria-expanded"),
            filter: style.filter
          };
        };
        const waitForSettledFilter = () => {
          const state = readState();
          if (state.filter === "none" || performance.now() - started > 1500) {
            done(state);
          } else {
            requestAnimationFrame(waitForSettledFilter);
          }
        };

        waitForSettledFilter();
      })()
    JS
    assert_equal false, revealed_state["hidden"]
    assert_equal true, revealed_state["revealed"]
    assert_equal "false", revealed_state["ariaHidden"]
    assert_equal true, revealed_state["buttonHidden"]
    assert_equal "true", revealed_state["buttonExpanded"]
    assert_equal "none", revealed_state["filter"]
  end

  test "winning writeups show proof badges on overview cards and articles" do
    winner_case = winning_writeup_case

    visit "/ctf/#{winner_case[:directory]}"

    winner_case[:winner_posts].each do |post|
      winner = WriteupWinner.from_metadata(post[:metadata])
      within find(".blog-post-card", text: post[:title]) do
        assert_selector ".blog-post-meta-row > button.writeup-winner-badge:first-child[data-filter-tag='Writeup winner']", text: winner[:label]
        assert_no_selector ".blog-post-meta-row > a.writeup-winner-badge"
      end
    end

    filter_tags = all(".content-filter-panel .content-filter-tag-list [data-filter-tag]").map do |chip|
      chip["data-filter-tag"]
    end
    assert_equal "Writeup winner", filter_tags.first
    assert_equal 1, filter_tags.count("Writeup winner")
    winner_case[:winner_posts].map { |post| WriteupWinner.from_metadata(post[:metadata])[:label] }.uniq.each do |label|
      assert_no_selector ".content-filter-panel [data-filter-tag='#{label}']"
    end
    assert_selector ".content-filter-panel .filter-chip.writeup-winner-badge-filter", text: "Writeup winner"
    find(".content-filter-panel .filter-chip.writeup-winner-badge-filter", text: "Writeup winner").click
    assert_selector ".content-filter-panel .filter-chip.writeup-winner-badge-filter.is-active", text: "Writeup winner"
    assert_selector "[data-filter-count='writeups']", text: filter_count_text(winner_case[:winner_posts].length, winner_case[:posts].length)
    assert_equal winner_case[:winner_posts].map { |post| post[:title] }, visible_writeup_titles

    first_winner = winner_case[:winner_posts].first
    first_winner_badge = WriteupWinner.from_metadata(first_winner[:metadata])
    visit first_winner[:link]
    assert_selector ".writeup-winner-article .writeup-winner-badge[href='#{first_winner_badge[:proof_url]}']", text: first_winner_badge[:label]
    assert_selector ".writeup-recognition-badges-article .writeup-winner-badge .content-tag-arrow", text: ">"

    mobile_winner = winner_case[:winner_posts].find { |post| post[:link].include?("A%20Minecraft%20Movie") } || first_winner
    page.current_window.resize_to(320, 900)
    visit mobile_winner[:link]
    mobile_badge_metrics = page.evaluate_script(<<~JS)
      (() => {
        const badge = document.querySelector(".writeup-recognition-badges-article .writeup-winner-badge");
        const badgeRect = badge.getBoundingClientRect();
        const viewportWidth = document.documentElement.clientWidth;
        const scrollWidth = Math.max(document.documentElement.scrollWidth, document.body.scrollWidth);

        return {
          badgeRight: Math.round(badgeRect.right),
          viewportWidth,
          overflowX: scrollWidth - viewportWidth
        };
      })()
    JS
    assert_operator mobile_badge_metrics["badgeRight"], :<=, mobile_badge_metrics["viewportWidth"]
    assert_operator mobile_badge_metrics["overflowX"], :<=, 2

    if (external_winner = first_external_winning_writeup)
      external_badge = WriteupWinner.from_metadata(external_winner[:metadata])
      visit external_winner[:link]
      assert_selector ".writeup-winner-article .writeup-winner-badge[href='#{external_badge[:proof_url]}']", text: external_badge[:label]
    end
  end

  test "authored writeups filter on overview cards and link event badges on articles" do
    post = authored_writeup_with_event_url
    event_url = writeup_event_url_for(post)

    visit "/ctf/#{post[:directory]}"

    within find(".blog-post-card", text: post[:title]) do
      assert_selector ".blog-post-meta-row > button.authored-challenge-badge[data-filter-tag='Authored challenge']", text: /Authored challenge/
      assert_selector ".blog-post-meta-row > .difficulty-badge.difficulty-badge-hard", text: "Hard"
      assert_no_selector ".blog-post-meta-row > a.authored-challenge-badge"
      assert_no_selector ".authored-challenge-icon"
    end

    visit post[:link]
    assert_selector ".writeup-badges-article .difficulty-badge-hard", text: "Hard"
    assert_selector ".writeup-badges-article .authored-challenge-badge[href='#{event_url}'][target='_blank'][rel='noopener noreferrer']", text: /Authored challenge/
    assert_selector ".writeup-recognition-badges-article .authored-challenge-badge .content-tag-arrow", text: ">"
    Array(post[:metadata]["categories"]).each do |category|
      assert_selector ".writeup-badges-article .category-badge.category-badge-#{ContentCategoryTag.css_key(category)}.category-badge-article",
                      text: /^#{Regexp.escape(category)}$/i
    end
    article_badge_order = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".writeup-badges-article > *")].map((badge) => {
        if (badge.classList.contains("writeup-winner-badge") || badge.classList.contains("authored-challenge-badge")) return "shiny";
        if (badge.classList.contains("difficulty-badge")) return "difficulty";
        if (badge.classList.contains("category-badge")) return "category";
        return "other";
      })
    JS
    assert_operator article_badge_order.index("shiny"), :<, article_badge_order.index("difficulty")
    assert_operator article_badge_order.index("difficulty"), :<, article_badge_order.index("category")
  end

  test "terminal stays bounded and padded across viewport sizes" do
    [
      { width: 390, height: 844 },
      { width: 1024, height: 768 },
      { width: 2560, height: 1440 }
    ].each do |viewport|
      page.current_window.resize_to(viewport[:width], viewport[:height])
      visit "/"

      page.execute_script(<<~JS)
        localStorage.setItem('terminal-open', 'false');
        const terminal = document.getElementById('terminal-container');
        terminal.classList.add('terminal-minimized');
        terminal.style.transition = 'none';
        const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
        window.scrollTo(0, Math.min(420, Math.max(0, maxScroll)));
      JS
      page.execute_script("document.getElementById('terminal-taskbar-button').click()")
      assert_selector ".xterm", visible: :all
      assert_selector ".xterm-viewport", visible: :all

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const terminal = document.querySelector("#terminal-container");
          const button = document.querySelector(".terminal-button");
          const xterm = terminal.querySelector(".xterm");
          const viewport = terminal.querySelector(".xterm-viewport");
          const terminalRect = terminal.getBoundingClientRect();
          const buttonRect = button.getBoundingClientRect();
          const viewportRect = viewport.getBoundingClientRect();
          const terminalStyle = window.getComputedStyle(terminal);
          const xtermStyle = window.getComputedStyle(xterm);
          const viewportStyle = window.getComputedStyle(viewport);
          const bodyStyle = window.getComputedStyle(document.body);
          const openingScrollY = window.scrollY;
          const currentScrollY = window.scrollY;

          window.scrollTo(1000, currentScrollY);
          const horizontalScrollAfterAttempt = window.scrollX;
          window.scrollTo(0, currentScrollY + 120);
          const outsideScrollDelta = window.scrollY - currentScrollY;
          window.scrollTo(0, currentScrollY);

          let terminalWheelReachedPage = false;
          let outsideWheelReachedPage = false;
          const terminalWheelPageListener = () => { terminalWheelReachedPage = true; };
          document.body.addEventListener("wheel", terminalWheelPageListener);
          terminal.dispatchEvent(new WheelEvent("wheel", { bubbles: true, deltaY: 120 }));
          document.body.removeEventListener("wheel", terminalWheelPageListener);
          document.body.addEventListener("wheel", () => { outsideWheelReachedPage = true; }, { once: true });
          document.body.dispatchEvent(new WheelEvent("wheel", { bubbles: true, deltaY: 120 }));

          return {
            width: Math.round(terminalRect.width),
            height: Math.round(terminalRect.height),
            maxWidth: terminalStyle.width,
            buttonWidth: Math.round(buttonRect.width),
            fontSize: parseFloat(xtermStyle.fontSize),
            terminalLeft: Math.round(terminalRect.left),
            terminalRight: Math.round(terminalRect.right),
            viewportWidth: Math.round(window.innerWidth),
            contentInsetLeft: Math.round(viewportRect.left - terminalRect.left),
            contentInsetTop: Math.round(viewportRect.top - terminalRect.top),
            horizontalScrollAfterAttempt,
            openingScrollY,
            outsideScrollDelta,
            terminalWheelReachedPage,
            outsideWheelReachedPage,
            bodyScrollLocked: document.body.classList.contains("terminal-scroll-locked"),
            htmlScrollLocked: document.documentElement.classList.contains("terminal-scroll-locked"),
            bodyPosition: bodyStyle.position,
            bodyTop: document.body.style.top,
            viewportOverflowY: viewportStyle.overflowY,
            terminalHorizontalOverflow: terminal.scrollWidth - terminal.clientWidth,
            viewportHorizontalOverflow: viewport.scrollWidth - viewport.clientWidth
          };
        })()
      JS

      assert_operator metrics["width"], :<=, 1320
      assert_operator metrics["height"], :<=, 750
      assert_operator metrics["buttonWidth"], :<=, 48
      assert_operator metrics["fontSize"], :>=, 13
      assert_operator metrics["fontSize"], :<=, 18
      assert_operator metrics["terminalLeft"], :>=, 0
      assert_operator metrics["terminalRight"], :<=, metrics["viewportWidth"]
      assert_operator metrics["contentInsetLeft"], :>=, 12
      assert_operator metrics["contentInsetTop"], :>=, 48
      assert_operator metrics["horizontalScrollAfterAttempt"], :<=, 1
      assert_operator metrics["openingScrollY"], :>=, 0
      assert_operator metrics["outsideScrollDelta"], :>, 0
      assert_equal false, metrics["terminalWheelReachedPage"]
      assert_equal true, metrics["outsideWheelReachedPage"]
      assert_equal false, metrics["bodyScrollLocked"]
      assert_equal false, metrics["htmlScrollLocked"]
      assert_not_equal "fixed", metrics["bodyPosition"]
      assert_equal "", metrics["bodyTop"]
      assert_equal "scroll", metrics["viewportOverflowY"]
      assert_operator metrics["terminalHorizontalOverflow"], :<=, 1
      assert_operator metrics["viewportHorizontalOverflow"], :<=, 1
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

  test "filtered overviews keep spacing tag borders and shrink page height" do
    page.current_window.resize_to(1280, 900)
    writeup_case = writeup_filter_case

    visit "/ctf/#{writeup_case[:directory]}"

    assert_selector ".writeup-overview .blog-post-entry", count: writeup_case[:posts].length

    initial_metrics = page.evaluate_script(<<~JS)
      (() => {
        const entries = [...document.querySelectorAll(".writeup-overview .blog-post-entry")];
        const rects = entries.slice(0, 2).map((entry) => entry.getBoundingClientRect());

        return {
          gap: Math.round(rects[1].top - rects[0].bottom),
          pageHeight: document.documentElement.scrollHeight
        };
      })()
    JS

    assert_operator initial_metrics["gap"], :>=, 15

    select_filter_year("writeups", writeup_case[:year].to_s)
    assert_selector "[data-filter-count='writeups']", text: filter_count_text(writeup_case[:year_posts].length, writeup_case[:posts].length)

    filtered_height = page.evaluate_script(<<~JS)
      (() => {
        return new Promise((resolve) => {
          requestAnimationFrame(() => {
            requestAnimationFrame(() => resolve(document.documentElement.scrollHeight));
          });
        });
      })()
    JS

    assert_operator filtered_height, :<, initial_metrics["pageHeight"] - 100

    visit "/timeline"
    assert_selector ".timeline-tag-pill", minimum: 1

    border_width = page.evaluate_script(<<~JS)
      parseFloat(window.getComputedStyle(document.querySelector(".timeline-tag-pill")).borderTopWidth)
    JS

    assert_operator border_width, :>=, 1
  end

  test "article table of contents toggle collapses the toc column" do
    page.current_window.resize_to(1440, 1200)
    visit ctf_post_with_headings[:link]

    button_metrics_script = <<~JS
      (selector => {
        const element = document.querySelector(selector);
        const rect = element.getBoundingClientRect();
        const style = window.getComputedStyle(element);
        const wrapper = document.querySelector(".writeup-wrapper");
        const wrapperRect = wrapper ? wrapper.getBoundingClientRect() : null;
        const container = document.querySelector(".writeup-container");
        const containerRect = container ? container.getBoundingClientRect() : null;
        const toc = document.getElementById("toc");
        const tocRect = toc ? toc.getBoundingClientRect() : null;

        return {
          position: style.position,
          top: Math.round(rect.top),
          right: Math.round(window.innerWidth - rect.right),
          contentTopInset: wrapperRect ? Math.round(rect.top - wrapperRect.top) : null,
          contentRightInset: wrapperRect ? Math.round(wrapperRect.right - rect.right) : null,
          postTopInset: containerRect ? Math.round(rect.top - containerRect.top) : null,
          postRightInset: containerRect ? Math.round(containerRect.right - rect.right) : null,
          tocTopInset: tocRect ? Math.round(rect.top - tocRect.top) : null,
          tocRightInset: tocRect ? Math.round(tocRect.right - rect.right) : null
        };
      })
    JS

    width_script = "Math.round(document.querySelector('.writeup-container').getBoundingClientRect().width)"
    wrapper_width_script = "Math.round(document.querySelector('.writeup-wrapper').getBoundingClientRect().width)"
    assert_no_selector ".writeup-wrapper.toc-collapsed", visible: :all
    assert_no_selector "#toc[hidden]", visible: :all
    assert_selector "#toc-toggle[aria-expanded='true']"
    original_width = page.evaluate_script(width_script)
    wrapper_width = page.evaluate_script(wrapper_width_script)
    initial_layout_metrics = page.evaluate_script(<<~JS)
      (() => {
        const wrapper = document.querySelector(".writeup-wrapper");
        const container = document.querySelector(".writeup-container");
        const toc = document.getElementById("toc");
        const wrapperChildren = [...wrapper.children];
        const wrapperStyle = window.getComputedStyle(wrapper);
        const containerRect = container.getBoundingClientRect();
        const tocRect = toc.getBoundingClientRect();
        const wrapperRect = wrapper.getBoundingClientRect();

        return {
          tocBeforeArticleInDom: wrapperChildren.indexOf(toc) < wrapperChildren.indexOf(container),
          tocVisuallyRightOfArticle: tocRect.left >= containerRect.right - 1,
          reservedWidth: Math.round(containerRect.width + tocRect.width + parseFloat(wrapperStyle.columnGap || wrapperStyle.gap || 0)),
          wrapperWidth: Math.round(wrapperRect.width)
        };
      })()
    JS
    assert_equal true, initial_layout_metrics["tocBeforeArticleInDom"]
    assert_equal true, initial_layout_metrics["tocVisuallyRightOfArticle"]
    assert_in_delta initial_layout_metrics["wrapperWidth"], initial_layout_metrics["reservedWidth"], 2
    expanded_button_metrics = page.evaluate_script("#{button_metrics_script}('#toc-toggle')")
    assert_equal "absolute", expanded_button_metrics["position"]
    assert_in_delta expanded_button_metrics["tocTopInset"], expanded_button_metrics["tocRightInset"], 1

    page.execute_script("window.scrollTo(0, 700)")
    scrolled_expanded_button_metrics = page.evaluate_script("#{button_metrics_script}('#toc-toggle')")
    assert_equal "absolute", scrolled_expanded_button_metrics["position"]
    assert_in_delta expanded_button_metrics["tocTopInset"], scrolled_expanded_button_metrics["tocTopInset"], 1
    assert_in_delta expanded_button_metrics["tocRightInset"], scrolled_expanded_button_metrics["tocRightInset"], 1
    assert_in_delta scrolled_expanded_button_metrics["tocTopInset"], scrolled_expanded_button_metrics["tocRightInset"], 1

    find("#toc-toggle").click

    assert_selector ".writeup-wrapper.toc-collapsed"
    assert_selector "#toc-toggle[aria-expanded='false']", visible: :all
    assert_selector "#toc[hidden]", visible: :all
    assert_no_selector ".writeup-toc-restore-slot", visible: :all
    assert_selector ".writeup-toc-restore-button", visible: :visible
    expanded_width = page.evaluate_script(width_script)
    assert_operator expanded_width, :>, original_width
    assert_in_delta wrapper_width, expanded_width, 1
    collapsed_button_metrics = page.evaluate_script("#{button_metrics_script}('.writeup-toc-restore-button')")
    assert_equal "sticky", collapsed_button_metrics["position"]
    assert_in_delta scrolled_expanded_button_metrics["top"], collapsed_button_metrics["top"], 2
    assert_in_delta expanded_button_metrics["tocRightInset"], collapsed_button_metrics["postRightInset"], 1

    page.execute_script("window.scrollTo(0, 0)")
    top_collapsed_button_metrics = page.evaluate_script("#{button_metrics_script}('.writeup-toc-restore-button')")
    assert_in_delta top_collapsed_button_metrics["postTopInset"], top_collapsed_button_metrics["postRightInset"], 1
    assert_in_delta collapsed_button_metrics["right"], top_collapsed_button_metrics["right"], 1

    find(".writeup-toc-restore-button").click
    assert_no_selector ".writeup-wrapper.toc-collapsed", visible: :all
    assert_no_selector "#toc[hidden]", visible: :all
  end

  test "article code blocks are centered and shrink to their content" do
    page.current_window.resize_to(1440, 1200)
    visit ctf_post_with_code_block[:link]

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
          overflowWrap: style.overflowWrap,
          codeLineCount: pre.querySelectorAll(".code-line").length,
          firstLineDisplay: window.getComputedStyle(pre.querySelector(".code-line")).display,
          firstLineNumber: window.getComputedStyle(pre.querySelector(".code-line"), "::before").content,
          firstLineUserSelect: window.getComputedStyle(pre.querySelector(".code-line"), "::before").userSelect
        };
      })()
    JS

    assert_operator metrics["blockWidth"], :<, metrics["containerWidth"] * 0.95
    assert_in_delta metrics["containerCenter"], metrics["blockCenter"], 2
    assert_equal "pre-wrap", metrics["whiteSpace"]
    assert_equal "anywhere", metrics["overflowWrap"]
    assert_operator metrics["codeLineCount"], :>, 0
    assert_equal "grid", metrics["firstLineDisplay"]
    assert_equal '"1"', metrics["firstLineNumber"]
    assert_equal "none", metrics["firstLineUserSelect"]

    page.current_window.resize_to(390, 1200)
    mobile_font_sizes = page.evaluate_script(<<~JS)
      (() => {
        const content = document.querySelector(".markdown-content");
        const pre = document.querySelector(".code-block pre.highlight");

        return {
          content: parseFloat(window.getComputedStyle(content).fontSize),
          code: parseFloat(window.getComputedStyle(pre).fontSize)
        };
      })()
    JS

    assert_operator mobile_font_sizes["code"], :<=, mobile_font_sizes["content"]
  end

  test "article markdown keeps readable heading typography" do
    article_heading_cases.each do |path, heading_text|
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

  def repository
    @repository ||= ContentRepository.new
  end

  def content_index
    @content_index ||= ContentIndex.new(repository: repository)
  end

  def blog_posts
    @blog_posts ||= repository.blog_posts
  end

  def ctf_posts
    @ctf_posts ||= repository.ctf_posts
  end

  def timeline_items
    @timeline_items ||= content_index.all_items
  end

  def first_blog_post
    blog_posts.first || flunk("expected at least one blog post")
  end

  def first_ctf_post
    ctf_posts.first || flunk("expected at least one CTF writeup")
  end

  def adjacent_post_case(posts, label)
    skip "expected at least three #{label}" if posts.length < 3

    index = 1
    {
      post: posts[index],
      previous: posts[index + 1],
      next: posts[index - 1]
    }
  end

  def first_ctf_event_with_writeups
    ctf_overview_items.find { |event| event[:writeups].any? } || flunk("expected at least one CTF with writeups")
  end

  def first_ctf_event_with_multiple_writeups
    ctf_overview_items.find { |event| event[:writeups].length >= 2 } || flunk("expected a CTF with multiple writeups")
  end

  def pages_with_expected_text
    ctf_post = first_ctf_post
    blog_post = first_blog_post

    {
      "/" => "Welcome to my bug collection 🐛",
      "/ctf" => "CTF events",
      "/ctf/#{ctf_post[:directory]}" => ctf_event_label(ctf_post[:directory]),
      ctf_post[:link] => ctf_post[:title],
      "/blog" => "Blog",
      blog_post[:link] => blog_post[:title],
      "/timeline" => "Timeline"
    }
  end

  def select_filter_year(scope, year)
    find("[data-year-dropdown-button='#{scope}']").click
    find("[data-year-dropdown-option='#{scope}'][data-year-value='#{year}']").click
  end

  def filter_count_text(visible, total)
    "#{visible} / #{total} #{total == 1 ? "item" : "items"}"
  end

  def assert_selector_count(selector, count)
    if count.zero?
      assert_no_selector selector
    else
      assert_selector selector, count: count
    end
  end

  def about_finding_collapsible?(entry)
    about_visible_detail?(entry["summary"]) ||
      Array(entry["timeline"]).any? { |item| item.is_a?(Hash) && item["event"].present? }
  end

  def about_visible_detail?(value)
    value.present? && value.to_s.strip.casecmp("tba") != 0
  end

  def assert_timeline_year_counts_match_visible_cards
    mismatches = page.evaluate_script(<<~JS)
      (() => {
        return [...document.querySelectorAll('[data-filter-group="timeline"]')]
          .filter((group) => !group.hidden)
          .map((group) => {
            const count = group.querySelector('[data-filter-group-count="timeline"]');
            const year = group.querySelector('.timeline-year-header h2')?.innerText.trim();
            const visibleCards = [...group.querySelectorAll('[data-filter-card="timeline"]')]
              .filter((card) => card.getAttribute('aria-hidden') !== 'true' && !card.hidden)
              .length;
            const expected = `${visibleCards} ${visibleCards === 1 ? 'item' : 'items'}`;

            return count && count.innerText.trim() === expected ? null : `${year}: expected ${expected}, got ${count?.innerText.trim()}`;
          })
          .filter(Boolean);
      })()
    JS

    assert_equal [], mismatches
  end

  def landing_latest_posts
    @landing_latest_posts ||= (ctf_posts + blog_posts).sort_by { |post| -post[:published].to_i }.first(3)
  end

  def landing_post_logo?(post)
    case post[:type]
    when "blog"
      repository.blog_metadata.dig(post[:slug], "logo").present?
    when "ctf"
      post[:logo].present?
    else
      false
    end
  end

  def landing_post_placeholder?(post)
    post[:type] == "blog" && !landing_post_logo?(post)
  end

  def landing_post_inline_svg?(post)
    post[:type] == "ctf" && !landing_post_logo?(post)
  end

  def ctf_event_label(directory)
    match = repository.ctf_metadata.find do |name, metadata|
      ctf_directory(name, metadata) == directory
    end

    match ? match.first : directory.upcase
  end

  def ctf_directory(name, metadata)
    metadata["terminal_path"].presence || name.downcase
  end

  def ctf_overview_items
    @ctf_overview_items ||= repository.ctf_metadata.map do |name, metadata|
      directory = ctf_directory(name, metadata)
      writeups = ctf_posts.select { |post| post[:directory] == directory }
      metadata_values = writeups.map { |post| post[:metadata] || {} }
      tags = sorted_filter_tags(metadata_values.flat_map { |entry| repository.metadata_tags(entry) })
      difficulty_labels = sorted_difficulty_labels(metadata_values.map { |entry| WriteupDifficulty.filter_label_for(entry) })
      years = metadata_values.filter_map { |entry| repository.metadata_year(entry) }.uniq.sort.reverse
      filter_text = [ name, metadata["description"], directory, tags ].flatten.compact.join(" ").downcase

      {
        name: name,
        directory: directory,
        link: "/ctf/#{directory}",
        writeups: writeups,
        tags: tags,
        difficulty_labels: difficulty_labels,
        years: years,
        text: filter_text
      }
    end
  end

  def sorted_filter_tags(values)
    values.map(&:to_s).reject(&:blank?).uniq { |value| value.downcase }.sort_by { |value| ContentRepository.filter_tag_sort_key(value) }
  end

  def sorted_difficulty_labels(values)
    values.map(&:to_s).reject(&:blank?).uniq { |value| value.downcase }.sort_by { |value| WriteupDifficulty.filter_sort_key(value) }
  end

  def ctf_overview_tag_case
    groups = {}
    ctf_overview_items.each do |item|
      item[:tags].reject { |tag| special_filter_tag?(tag) }.each do |tag|
        key = tag.downcase
        groups[key] ||= { tag: tag, items: [] }
        groups[key][:items] << item
      end
    end

    groups.values.find { |group| group[:items].length < ctf_overview_items.length } ||
      groups.values.first ||
      flunk("expected at least one CTF filter tag")
  end

  def ctf_uncombinable_tag_pair
    groups = {}
    ctf_overview_items.each do |item|
      item[:tags].each do |tag|
        key = tag.downcase
        groups[key] ||= { tag: tag, items: [] }
        groups[key][:items] << item
      end
    end

    groups.values.combination(2) do |first, second|
      return { first: first[:tag], second: second[:tag] } if (first[:items] & second[:items]).empty?
    end

    flunk("expected at least two CTF filter tags without a shared result")
  end

  def ctf_overview_difficulty_case
    groups = {}
    ctf_overview_items.each do |item|
      item[:difficulty_labels].each do |label|
        key = label.downcase
        groups[key] ||= { label: label, key: WriteupDifficulty.css_key(label), items: [] }
        groups[key][:items] << item
      end
    end

    groups.values.select { |group| group[:items].length < ctf_overview_items.length }.min_by { |group| group[:items].length } ||
      groups.values.first ||
      flunk("expected at least one CTF difficulty filter")
  end

  def ctf_overview_search_case
    ctf_overview_items.each do |item|
      query = item[:name]
      matches = ctf_overview_items.select { |candidate| ordered_search_match?(query, [ candidate[:text], candidate[:tags] ].flatten.join(" ")) }
      return { query: query, items: matches } if matches.any?
    end

    flunk("expected at least one searchable CTF")
  end

  def ctf_overview_year_case
    groups = {}
    ctf_overview_items.each do |item|
      item[:years].each do |year|
        groups[year] ||= { year: year, items: [] }
        groups[year][:items] << item
      end
    end

    groups.values.find { |group| group[:items].length < ctf_overview_items.length } ||
      groups.values.first ||
      flunk("expected at least one CTF filter year")
  end

  def writeup_filter_case
    ctf_overview_items.each do |event|
      posts = event[:writeups]
      next unless posts.length >= 3

      tag_case = writeup_tag_case_for(posts)
      difficulty_case = writeup_difficulty_case_for(posts)
      year_case = writeup_year_case_for(posts)
      next unless tag_case && difficulty_case && year_case

      return {
        directory: event[:directory],
        posts: posts,
        tag: tag_case[:tag],
        tag_posts: tag_case[:posts],
        difficulty: difficulty_case,
        year: year_case[:year],
        year_posts: year_case[:posts]
      }
    end

    flunk("expected a CTF overview with filterable writeups")
  end

  def writeup_tag_case_for(posts)
    groups = {}
    posts.each do |post|
      repository.metadata_tags(post[:metadata] || {}).reject { |tag| special_filter_tag?(tag) }.each do |tag|
        key = tag.downcase
        groups[key] ||= { tag: tag, posts: [] }
        groups[key][:posts] << post
      end
    end

    groups.values.select { |group| group[:posts].length < posts.length }.min_by { |group| group[:posts].length }
  end

  def writeup_difficulty_case_for(posts)
    groups = {}
    posts.each do |post|
      label = WriteupDifficulty.filter_label_for(post[:metadata] || {})
      next if label.blank?

      key = label.downcase
      groups[key] ||= { label: label, key: WriteupDifficulty.css_key(label), posts: [] }
      groups[key][:posts] << post
    end

    groups.values.select { |group| group[:posts].length < posts.length }.min_by { |group| group[:posts].length }
  end

  def writeup_year_case_for(posts)
    groups = {}
    posts.each do |post|
      year = post[:published].year
      groups[year] ||= { year: year, posts: [] }
      groups[year][:posts] << post
    end

    groups.values.select { |group| group[:posts].length < posts.length }.min_by { |group| group[:posts].length }
  end

  def visible_ctf_names
    all(".ctf-card .ctf-name").map(&:text)
  end

  def visible_writeup_titles
    all(".writeup-overview .blog-post-title").map(&:text)
  end

  def visible_blog_titles
    all(".blog-posts-container .blog-post-title").map(&:text)
  end

  def visible_timeline_titles
    all(".timeline-content .timeline-title").map(&:text)
  end

  def blog_tag_case
    groups = {}
    blog_posts.each do |post|
      ([ post[:which] ] + Array(post[:categories])).compact.uniq { |tag| tag.to_s.downcase }.each do |tag|
        groups[tag.downcase] ||= { tag: tag, posts: [] }
        groups[tag.downcase][:posts] << post
      end
    end

    candidate = groups.values.find { |group| group[:posts].length < blog_posts.length } ||
      groups.values.first ||
      flunk("expected at least one blog tag")

    { tag: candidate[:tag], items: candidate[:posts] }
  end

  def blog_search_case
    blog_posts.each do |post|
      query = post[:title]
      matches = blog_posts.select { |candidate| ordered_search_match?(query, blog_filter_text(candidate)) }
      return { query: query, post: post, items: matches } if matches.any?
    end

    flunk("expected at least one searchable blog post")
  end

  def blog_year_case
    groups = {}
    blog_posts.each do |post|
      year = post[:published].year
      groups[year] ||= { year: year, items: [] }
      groups[year][:items] << post
    end

    groups.values.find { |group| group[:items].length < blog_posts.length } ||
      groups.values.first ||
      flunk("expected at least one blog year")
  end

  def blog_filter_text(post)
    published = post[:published].strftime("%Y-%m-%d")
    ([ post[:title], post[:description], published, post[:published].year, post[:topic], post[:which] ] + Array(post[:categories]))
      .compact
      .join(" ")
      .downcase
  end

  def first_timeline_post_with_tags
    timeline_items.find { |item| item[:link].to_s.match?(%r{\A/(blog|ctf)/}) && visible_timeline_tags(item).any? } ||
      flunk("expected at least one timeline item with visible tags")
  end

  def first_timeline_about_achievement
    timeline_items.find { |item| item[:kind] == "achievement" && item[:link].to_s.start_with?("/about#") } ||
      flunk("expected at least one timeline achievement linking to about")
  end

  def first_visible_timeline_tag
    visible_timeline_tags(first_timeline_post_with_tags).first
  end

  def visible_timeline_tags(item)
    content_type_tags = Array(item[:kind_labels]).map { |kind_label| kind_label[:tag_value].presence || kind_label[:label] }

    Array(item[:tags]).reject do |tag|
      tag == item[:label] || content_type_tags.include?(tag) || special_filter_tag?(tag)
    end
  end

  def special_filter_tag?(tag)
    [ WriteupWinner::FILTER_LABEL, AuthoredChallenge::FILTER_LABEL ].include?(tag) || WriteupDifficulty.filter_label?(tag)
  end

  def timeline_search_case
    timeline_items.each do |item|
      query = item[:title].to_s
      next if query.blank?

      matches = timeline_items.select { |candidate| timeline_search_match?(query, candidate) }
      return { query: query, items: matches } if matches.any?
    end

    flunk("expected at least one searchable timeline item")
  end

  def timeline_tag_search_case
    timeline_tag_case_candidates.each do |candidate|
      matches = timeline_items.select { |item| timeline_tag_search_match?(candidate[:tag], item) }
      next unless matches.any? && matches.length < timeline_items.length

      return candidate.merge(query: candidate[:tag], items: matches)
    end

    flunk("expected at least one searchable timeline tag")
  end

  def timeline_fuzzy_search_case
    timeline_items.each do |item|
      normalized_title = normalized_search_words(item[:title]).find { |word| word.length >= 8 }
      next unless normalized_title

      query = normalized_title.chars.each_with_index.filter_map { |character, index| character if index.even? }.join
      next if query.length < 4 || normalized_title.include?(query)

      matches = timeline_items.select { |candidate| timeline_search_match?(query, candidate) }
      next unless matches.include?(item) && matches.length < timeline_items.length

      return { query: query, items: matches, item: item }
    end

    flunk("expected at least one fuzzy-searchable timeline item")
  end

  def timeline_tag_case_candidates
    groups = {}
    timeline_items.each do |item|
      visible_timeline_tags(item).each do |tag|
        key = tag.downcase
        groups[key] ||= { tag: tag, exact_items: [] }
        groups[key][:exact_items] << item
      end
    end

    groups.values.sort_by { |group| [ group[:exact_items].length, group[:tag] ] }
  end

  def timeline_search_match?(query, item)
    search_terms = normalized_search_words(timeline_filter_text(item))
    Array(item[:tags]).each do |tag|
      tag_words = normalized_search_words(tag)
      search_terms.concat(tag_words)
      search_terms << tag_words.join if tag_words.any?
    end

    normalized_search_words(query).all? do |query_term|
      search_terms.any? { |search_term| ordered_search_term_match?(query_term, search_term) }
    end
  end

  def timeline_tag_search_match?(query, item)
    tag_terms = Array(item[:tags]).flat_map do |tag|
      words = normalized_search_words(tag)
      compact = words.join
      compact.present? ? words + [ compact ] : words
    end.uniq
    query_terms = normalized_search_words(query)
    return true if query_terms.empty?

    query_terms.all? do |query_term|
      tag_terms.any? { |tag_term| ordered_search_term_match?(query_term, tag_term) }
    end
  end

  def timeline_filter_text(item)
    [ item[:title], item[:description], item[:source], item[:label], item[:display_date] ].compact.join(" ")
  end

  def ordered_search_match?(query, value)
    query_terms = normalized_search_words(query)
    return true if query_terms.empty?

    value_terms = normalized_search_words(value)
    query_terms.all? do |query_term|
      value_terms.any? { |value_term| ordered_search_term_match?(query_term, value_term) }
    end
  end

  def ordered_search_term_match?(query_term, value_term)
    query_index = 0
    value_term.each_char do |character|
      query_index += 1 if character == query_term[query_index]
      return true if query_index == query_term.length
    end

    false
  end

  def normalized_search_words(value)
    value.to_s
         .downcase
         .unicode_normalize(:nfkd)
         .gsub(/\p{Mn}/, "")
         .gsub(/[^a-z0-9]+/, " ")
         .split
  end

  def timeline_tag_case
    groups = {}
    timeline_items.each do |item|
      visible_timeline_tags(item).each do |tag|
        key = tag.downcase
        groups[key] ||= { tag: tag, items: [] }
        groups[key][:items] << item
      end
    end

    groups.values.find { |group| group[:items].length < timeline_items.length } ||
      groups.values.first ||
      flunk("expected at least one timeline tag")
  end

  def timeline_difficulty_case
    groups = {}
    timeline_items.each do |item|
      Array(item[:tags]).select { |tag| WriteupDifficulty.filter_label?(tag) }.each do |tag|
        key = tag.downcase
        groups[key] ||= { label: tag, key: WriteupDifficulty.css_key(tag), items: [] }
        groups[key][:items] << item
      end
    end

    groups.values.find { |group| group[:items].length < timeline_items.length } ||
      groups.values.first ||
      flunk("expected at least one timeline difficulty tag")
  end

  def timeline_severity_case
    groups = {}
    timeline_items.each do |item|
      Array(item[:tags]).select { |tag| ContentSeverityTag.recognized?(tag) && !WriteupDifficulty.filter_label?(tag) }.each do |tag|
        key = tag.downcase
        groups[key] ||= { label: tag, key: ContentSeverityTag.css_key(tag), items: [] }
        groups[key][:items] << item
      end
    end

    groups.values.find { |group| group[:items].length < timeline_items.length } ||
      groups.values.first ||
      flunk("expected at least one timeline severity tag")
  end

  def timeline_ctf_competition_case
    ctf_labels = repository.ctf_metadata.keys.map(&:to_s)
    groups = {}
    timeline_items.each do |item|
      Array(item[:tags]).select { |tag| ctf_labels.include?(tag.to_s) }.each do |tag|
        key = tag.downcase
        groups[key] ||= { label: tag, items: [] }
        groups[key][:items] << item
      end
    end

    groups.values.find { |group| group[:items].length < timeline_items.length } ||
      groups.values.first ||
      flunk("expected at least one timeline CTF competition tag")
  end

  def timeline_cve_case
    timeline_vulnerability_case(:cve?)
  end

  def timeline_cwe_case
    timeline_vulnerability_case(:cwe?)
  end

  def timeline_vulnerability_case(predicate)
    groups = {}
    timeline_items.each do |item|
      Array(item[:tags]).select { |tag| ContentVulnerabilityTag.public_send(predicate, tag) }.each do |tag|
        key = tag.downcase
        groups[key] ||= { label: tag, items: [] }
        groups[key][:items] << item
      end
    end

    groups.values.find { |group| group[:items].length < timeline_items.length } ||
      groups.values.first ||
      flunk("expected at least one timeline vulnerability tag")
  end

  def assert_hidden_timeline_item(visible_items)
    hidden = timeline_items.find { |item| visible_items.exclude?(item) }
    return unless hidden

    assert_no_selector ".timeline-card-hitbox[href='#{hidden[:link]}']"
  end

  def timeline_content_card(item)
    assert item, "expected a timeline item"

    find(".timeline-card-hitbox[href='#{item[:link]}']", visible: :all)
      .find(:xpath, "./ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' timeline-content ')]")
  end

  def first_ctf_post_with_author_link
    ctf_posts.each do |post|
      if (author = authors_from_metadata(post[:metadata]).find { |entry| entry[:url].present? })
        return [ post, author ]
      end
    end

    flunk("expected at least one writeup author link")
  end

  def first_ctf_post_with_internal_author_link
    ctf_posts.each do |post|
      if (author = authors_from_metadata(post[:metadata]).find { |entry| entry[:url].to_s.start_with?("/") })
        return [ post, author ]
      end
    end

    first_ctf_post_with_author_link
  end

  def authors_from_metadata(metadata)
    explicit_authors = metadata["authors"].presence
    link_map = metadata["author_urls"].presence || metadata["author_links"].presence || {}

    authors =
      if explicit_authors.is_a?(Array)
        explicit_authors.filter_map { |author| author_from_entry(author, link_map) }
      else
        metadata["author"].to_s.split(",").map(&:strip).reject(&:blank?).map do |name|
          { name: name, url: link_map[name].presence || metadata["author_url"].presence }
        end
      end

    authors.presence || [ { name: "Unknown author", url: nil } ]
  end

  def author_from_entry(author, link_map)
    if author.is_a?(Hash)
      name = author["name"].presence || author[:name].presence
      return nil if name.blank?

      { name: name, url: author["url"].presence || author[:url].presence || link_map[name].presence }
    else
      name = author.to_s.strip
      return nil if name.blank?

      { name: name, url: link_map[name].presence }
    end
  end

  def assert_href_matches(expected, actual)
    if expected.to_s.start_with?("/")
      assert_equal expected, URI.parse(actual).path
    else
      assert_equal expected, actual
    end
  end

  def winning_writeup_case
    grouped = ctf_posts.select { |post| WriteupWinner.from_metadata(post[:metadata]) }.group_by { |post| post[:directory] }
    directory, winner_posts = grouped.find { |_, posts| posts.length >= 2 } || grouped.first
    flunk("expected at least one winning writeup") unless directory

    {
      directory: directory,
      posts: ctf_posts.select { |post| post[:directory] == directory },
      winner_posts: winner_posts
    }
  end

  def first_external_winning_writeup
    ctf_posts.find do |post|
      WriteupWinner.from_metadata(post[:metadata])&.dig(:proof_url).to_s.match?(%r{\Ahttps?://}i)
    end
  end

  def authored_writeup_with_event_url
    ctf_posts.find do |post|
      AuthoredChallenge.from_metadata(post[:metadata]).present? && writeup_event_url_for(post).present?
    end || flunk("expected an authored CTF writeup with an event URL")
  end

  def writeup_event_url_for(post)
    metadata = post[:metadata] || {}
    authored = AuthoredChallenge.from_metadata(metadata)

    AuthoredChallenge.metadata_value(metadata, "event_url", "event-url", "event_link", "event-link").presence ||
      authored&.fetch(:event_url, nil).presence ||
      repository.ctf_metadata.dig(post[:which], "website")
  end

  def ctf_post_with_hints
    ctf_posts.find { |post| writeup_hints_for(post).any? } ||
      flunk("expected a CTF writeup with optional hints")
  end

  def writeup_hints_for(post)
    raw_hints = AuthoredChallenge.metadata_value(post[:metadata] || {}, "hints", "hint")
    hint_entries = raw_hints.is_a?(Array) ? raw_hints : [ raw_hints ]

    hint_entries.filter_map do |hint|
      hint = AuthoredChallenge.raw_value(hint, "text", "hint", "value") if hint.is_a?(Hash)
      hint.to_s.strip.presence
    end
  end

  def ctf_post_with_anchor_external_link_and_image
    ctf_posts.find do |post|
      post[:content].match?(/\]\(#[^)]+\)/) &&
        post[:content].match?(/\]\(https?:\/\//i) &&
        post[:content].match?(/!\[[^\]]*\]\((?!https?:\/\/)[^)]+\)/i)
    end || flunk("expected a CTF post with an anchor link, external link, and local image")
  end

  def ctf_post_with_nested_headings
    ctf_posts.each do |post|
      headings = markdown_headings(post[:content])
      headings.each_with_index do |heading, index|
        next unless heading[:level] > 1

        parent = headings[0...index].reverse.find { |candidate| candidate[:level] < heading[:level] }
        return [ post, parent, heading ] if parent
      end
    end

    flunk("expected a CTF post with nested headings")
  end

  def ctf_post_with_headings
    ctf_posts.find { |post| markdown_headings(post[:content]).any? } || flunk("expected a CTF post with headings")
  end

  def ctf_post_with_code_block
    ctf_posts.find { |post| post[:content].include?("```") } || flunk("expected a CTF post with a code block")
  end

  def article_heading_cases
    [ ctf_post_with_headings, blog_posts.find { |post| markdown_headings(post[:content]).any? } ].compact.map do |post|
      [ post[:link], markdown_headings(post[:content]).first[:rendered_text] ]
    end
  end

  def markdown_headings(markdown)
    headings = []
    heading_counters = []
    in_fence = false

    markdown.to_s.each_line do |line|
      if line.match?(/\A\s*```/)
        in_fence = !in_fence
        next
      end
      next if in_fence

      match = line.match(/\A(\#{1,6})\s+(.+?)\s*\z/)
      next unless match

      text = match[2].sub(/<a\b.*\z/i, "").gsub(/<[^>]+>/, "").strip
      next if text.blank?

      text = text.sub(/\A\d+(?:\.\d+)*\.?\s+/, "")
      depth = match[1].length - 1
      number = nil

      unless text.match?(/\A(?:tl;?dr|tldr)\z/i)
        (0...depth).each do |index|
          heading_counters[index] = 1 if heading_counters[index].to_i.zero?
        end

        heading_counters[depth] = heading_counters[depth].to_i + 1
        heading_counters = heading_counters[0..depth]
        number = "#{heading_counters.join(".")}."
      end

      headings << {
        level: match[1].length,
        text: text,
        rendered_text: [ number, text ].compact.join(" ")
      }
    end

    headings
  end

  def link_hit_target(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector(#{selector.to_json});
        link.scrollIntoView({ block: "center", inline: "nearest" });

        const rect = link.getBoundingClientRect();
        const target = document.elementFromPoint(rect.left + (rect.width / 2), rect.top + (rect.height / 2));
        const targetLink = target.closest("a");

        return {
          nodeName: target.nodeName,
          className: targetLink ? targetLink.className : target.className,
          href: targetLink ? targetLink.href : null
        };
      })()
    JS
  end

  def click_card_link_area(card)
    target = card.first(".blog-post-title, .ctf-name", visible: true)
    page.driver.browser.action.move_to(target.native).click.perform
  end

  def post_card_styles(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector(#{selector.to_json});
        const logo = card.querySelector(".blog-post-card-logo");
        const title = card.querySelector(".blog-post-title");
        const chip = card.querySelector(".filter-chip");
        const cardStyle = window.getComputedStyle(card);
        const logoStyle = window.getComputedStyle(logo);
        const titleStyle = window.getComputedStyle(title);
        const chipStyle = chip ? window.getComputedStyle(chip) : null;

        return {
          borderRadius: cardStyle.borderTopLeftRadius,
          borderColor: cardStyle.borderTopColor,
          backgroundColor: cardStyle.backgroundColor,
          backgroundImage: cardStyle.backgroundImage,
          boxShadow: cardStyle.boxShadow,
          logoBackground: logoStyle.backgroundColor,
          logoBorderRight: logoStyle.borderRightColor,
          titleFontSize: titleStyle.fontSize,
          titleFontWeight: titleStyle.fontWeight,
          chipBorderRadius: chipStyle?.borderTopLeftRadius || null
        };
      })()
    JS
  end

  def card_surface_styles(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector(#{selector.to_json});
        const style = window.getComputedStyle(card);

        return {
          borderRadius: style.borderTopLeftRadius,
          borderColor: style.borderTopColor,
          backgroundColor: style.backgroundColor,
          backgroundImage: style.backgroundImage,
          boxShadow: style.boxShadow
        };
      })()
    JS
  end

  def profile_card_highlight_styles(selector)
    page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1];
      (() => {
        const card = document.querySelector(#{selector.to_json});
        const summary = card.querySelector("summary");
        const wasOpen = card.open;

        card.open = true;

        window.setTimeout(() => {
          const cardStyle = window.getComputedStyle(card);
          const summaryStyle = window.getComputedStyle(summary);
          const summaryHighlightStyle = window.getComputedStyle(summary, "::before");
          const accentStyle = window.getComputedStyle(card, "::after");
          const result = {
            accent: cardStyle.getPropertyValue("--profile-card-accent").trim(),
            accentSoft: cardStyle.getPropertyValue("--profile-card-accent-soft").trim(),
            leftAccent: accentStyle.backgroundImage,
            summaryBackground: summaryHighlightStyle.backgroundColor,
            summaryBorder: summaryStyle.borderBottomColor
          };

          card.open = wasOpen;
          done(result);
        }, 360);
      })()
    JS
  end
end
