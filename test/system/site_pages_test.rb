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
      "/ctf" => [ ".ctf-rss-feed", ".ctf-atom-feed", ".ctf-rss-icon" ],
      "/blog" => [ ".blog-rss-feed", ".blog-atom-feed", ".blog-rss-icon" ]
    }.each do |path, (button_selector, atom_selector, icon_selector)|
      visit path

      button = find(button_selector)
      atom_button = find(atom_selector)
      find(icon_selector)
      assert_selector ".content-hero-actions #{button_selector}"
      assert_selector ".content-hero-title-row .content-hero-actions #{button_selector}"
      assert_equal "/feed", URI.parse(button[:href]).path
      assert_equal "/feed.atom", URI.parse(atom_button[:href]).path
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

  test "fixed sidebar toggle overlays compact pages without reserving layout space" do
    {
      "/" => "#landing-top",
      "/ctf" => ".content-hero-inner",
      "/timeline" => ".timeline-shell",
      "/about" => ".aboutme-hero-inner"
    }.each do |path, selector|
      [ 320, 390 ].each do |width|
        page.current_window.resize_to(width, 900)
        visit path

        metrics = page.evaluate_script(<<~JS)
          (() => {
            const menu = document.getElementById("menu-icon-right").getBoundingClientRect();
            const content = document.querySelector("#{selector}").getBoundingClientRect();
            const viewportWidth = document.documentElement.clientWidth;

            return {
              menuPosition: window.getComputedStyle(document.getElementById("menu-icon-right")).position,
              menuLeft: Math.round(menu.left),
              contentLeft: Math.round(content.left),
              contentRightGap: Math.round(viewportWidth - content.right)
            };
          })()
        JS

        assert_equal "fixed", metrics["menuPosition"]
        assert_equal 0, metrics["menuLeft"], "sidebar toggle drifted away from the viewport edge on #{path} at #{width}px"
        assert_in_delta metrics["contentLeft"], metrics["contentRightGap"], 2,
                        "content was offset by sidebar toggle on #{path} at #{width}px"
      end
    end
  end

  test "fixed sidebar toggle does not jump while scrolling compact pages" do
    page.current_window.resize_to(390, 900)
    visit "/timeline"

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const menu = document.getElementById("menu-icon-right");
        const before = Math.round(menu.getBoundingClientRect().top);
        window.scrollTo(0, document.documentElement.scrollHeight);
        const bottom = Math.round(menu.getBoundingClientRect().top);
        window.scrollTo(0, 0);
        const top = Math.round(menu.getBoundingClientRect().top);

        return { before, bottom, top };
      })()
    JS

    assert_in_delta metrics["before"], metrics["bottom"], 1
    assert_in_delta metrics["before"], metrics["top"], 1
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
    assert_selector ".landing-writeup-cards .blog-post-static-chip", minimum: 1
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
      assert_selector_count ".landing-writeup-cards .writeup-post-card .blog-logo[src*='/assets/ctf/']", ctf_logo_count
    end
    if expected_card_scopes.include?("blogs")
      blog_logo_count = landing_latest_posts.count { |post| post[:type] == "blog" && landing_post_logo?(post) }
      assert_selector_count ".landing-writeup-cards .blog-post-card[data-filter-card='blogs'] .blog-logo[src*='/assets/blog/']", blog_logo_count
    end
    assert_no_selector ".landing-writeup-cards .filter-chip[data-filter-tag]", visible: :all
    assert_no_selector ".landing-writeup-cards .filter-chip.ui-hover-lift", visible: :all
    assert_selector_count ".landing-writeup-cards .blog-post-card-logo svg", expected_svg_count
    static_chip_styles = page.evaluate_script(<<~JS)
      (() => {
        const chip = document.querySelector(".landing-writeup-cards .blog-post-static-chip");
        const style = window.getComputedStyle(chip);

        return {
          cursor: style.cursor,
          pointerEvents: style.pointerEvents,
          transform: style.transform
        };
      })()
    JS
    assert_equal "default", static_chip_styles["cursor"]
    assert_equal "none", static_chip_styles["pointerEvents"]
    assert_equal "none", static_chip_styles["transform"]

    landing_styles = post_card_styles(".landing-writeup-cards .blog-post-card")

    visit "/blog"
    assert_selector ".blog-posts-container .blog-post-card"
    blog_styles = post_card_styles(".blog-posts-container .blog-post-card")

    assert_equal blog_styles, landing_styles
  end

  test "post pages show reading time in the article header" do
    blog_post = first_blog_post
    ctf_post = first_ctf_post

    visit "/blog"
    assert_selector ".blog-posts-container .blog-post-reading-time", minimum: 1, text: /min read/

    visit "/ctf/#{ctf_post[:directory]}"
    assert_selector ".writeup-overview .blog-post-reading-time", minimum: 1, text: /min read/

    visit blog_post[:link]
    assert_selector ".post-meta-line", text: /min read/
    assert_selector ".article-progress[data-word-total]", text: %r{\d+\s*/\s*[\d,.]+\s+words}
    assert_selector ".article-progress-percent", text: /\d+%/
    assert_equal "sticky", page.evaluate_script("window.getComputedStyle(document.querySelector('.article-progress')).position")
    assert_operator page.evaluate_script("parseInt(document.querySelector('.article-progress').dataset.wordTotal, 10)"), :>, 0
    progress_gradient = page.evaluate_script("window.getComputedStyle(document.querySelector('.article-progress-bar')).backgroundImage")
    assert_includes progress_gradient, "rgb(2, 11, 31)"
    assert_includes progress_gradient, "rgb(125, 211, 252)"

    visit ctf_post[:link]
    assert_selector ".post-meta-line", text: /min read/
    assert_selector ".article-progress[data-word-total]", text: %r{\d+\s*/\s*[\d,.]+\s+words}
    assert_selector ".article-progress-percent", text: /\d+%/
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
  end

  test "main content cards share the blue surface treatment" do
    visit "/"
    assert_selector ".landing-featured-card.ui-card-surface", minimum: 1
    assert_selector ".landing-writeup-cards .blog-post-card.ui-card-surface", count: landing_latest_posts.length
    featured_styles = card_surface_styles(".landing-featured-card")
    latest_styles = card_surface_styles(".landing-writeup-cards .blog-post-card")
    assert_equal featured_styles, latest_styles

    visit "/timeline"
    assert_selector ".timeline-content.ui-card-surface", minimum: 1
    assert_selector ".timeline-content.content-card", minimum: 1
    assert_equal featured_styles, card_surface_styles(".timeline-content")

    visit "/ctf"
    assert_selector ".ctf-card.ui-card-surface", minimum: 1
    assert_selector ".ctf-card.content-card", minimum: 1
    assert_equal featured_styles, card_surface_styles(".ctf-card")

    visit "/ctf/#{first_ctf_event_with_writeups[:directory]}"
    assert_selector ".writeup-overview .blog-post-card.ui-card-surface", minimum: 1
    assert_selector ".writeup-overview .blog-post-card.content-card", minimum: 1
    assert_equal featured_styles, card_surface_styles(".writeup-overview .blog-post-card")

    visit "/blog"
    assert_selector ".blog-posts-container .blog-post-card.ui-card-surface", minimum: 1
    assert_selector ".blog-posts-container .blog-post-card.content-card", minimum: 1
    assert_equal featured_styles, card_surface_styles(".blog-posts-container .blog-post-card")

    visit "/about"
    assert_selector ".aboutme-finding-card.ui-card-surface", minimum: 1
    assert_selector ".aboutme-achievement-card.ui-card-surface", minimum: 1
    assert_equal featured_styles, card_surface_styles(".aboutme-finding-card")
  end

  test "landing page exposes about section counters as direct links" do
    visit "/"

    assert_text "creating writeups, collecting CVEs, bounties"
    assert_text "occasionally convince software to confess"
    assert_no_text "Security researcher and computer science student focused on web security"
    assert_no_text "Welcome to my flag collection"
    assert_selector ".landing-action[href='/timeline']", text: "Timeline"
    assert_selector ".landing-action[href='/about']", text: "About me"
    assert_selector ".landing-affiliation-link[href='https://kitctf.de'] img"
    assert_selector ".landing-affiliation-link[href='https://www.kit.edu'] img"
    affiliation_image_size = page.evaluate_script(<<~JS)
      (() => {
        const image = document.querySelector(".landing-affiliation-link[href='https://kitctf.de'] img");
        const rect = image.getBoundingClientRect();

        return Math.round(rect.width);
      })()
    JS
    assert_operator affiliation_image_size, :>=, 44
    assert_selector ".landing-metrics.aboutme-stats"
    assert_selector ".landing-metric", count: 6
    assert_selector ".landing-metric.aboutme-stat", count: 6
    assert_selector ".landing-metric:first-child[href='/timeline']", text: "Posts"
    assert_equal "center", page.evaluate_script("window.getComputedStyle(document.querySelector('.landing-metric')).justifyContent")
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
    expected_featured_count = content_index.featured_items.length
    assert_selector ".landing-featured-card.aboutme-card", count: expected_featured_count
    assert_equal expected_featured_count, page.evaluate_script("document.querySelectorAll('.landing-featured-card .aboutme-card-header, .landing-featured-card > summary').length")
    assert_selector ".landing-featured-card .aboutme-card-kicker", text: "CVE"
    assert_selector ".landing-featured-card .aboutme-card-kicker", text: "Certificate"
    assert_no_selector ".landing-featured-topline"
    assert_selector ".landing-featured-card", text: "CVE"
    assert_selector ".landing-featured-card", text: /Certificate/i
  end

  test "TBA findings render as static cards while disclosed findings stay collapsible" do
    cves = repository.about_entries(ApplicationController::ABOUTME_CVES_PATH)
    bug_bounties = repository.about_entries(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH)

    visit "/about"

    assert_selector_count "#cves article.aboutme-finding-card-static", cves.count { |entry| !about_finding_collapsible?(entry) }
    assert_selector_count "#cves details.aboutme-finding-card-cve", cves.count { |entry| about_finding_collapsible?(entry) }
    assert_selector_count "#bug-bounties article.aboutme-finding-card-static", bug_bounties.count { |entry| !about_finding_collapsible?(entry) }
    assert_selector_count "#bug-bounties details", bug_bounties.count { |entry| about_finding_collapsible?(entry) }
  end

  test "timeline entries are full-card links" do
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
    empty_tag_row_target = page.evaluate_script(<<~JS)
      (() => {
        const hitbox = document.querySelector(".timeline-card-hitbox[href='#{timeline_post[:link]}']");
        const card = hitbox.closest(".timeline-content");
        const tags = card.querySelector(".timeline-tags");
        card.scrollIntoView({ block: "center", inline: "nearest" });
        const rect = tags.getBoundingClientRect();
        const target = document.elementFromPoint(rect.right - 4, rect.top + (rect.height / 2));

        target.click();

        return {
          className: target.className,
          href: target.getAttribute("href")
        };
      })()
    JS

    assert_includes empty_tag_row_target["className"], "timeline-card-hitbox"
    assert_match %r{#{Regexp.escape(timeline_post[:link])}\z}, empty_tag_row_target["href"]
    assert_current_path timeline_post[:link]

    visit "/timeline"
    find(".timeline-tags .timeline-tag-pill", text: tag_name, match: :first).click
    assert_current_path "/timeline"
    assert_selector ".timeline-tags .timeline-tag-pill.is-active", text: tag_name
    assert_selector ".content-filter-panel .filter-chip.is-active", text: tag_name
  end

  test "timeline filters all indexed content" do
    total_items = timeline_items.length
    search_case = timeline_search_case
    certificate_count = timeline_items.count { |item| item[:tags].include?("Certificate") }
    winner_items = timeline_items.select { |item| item[:tags].include?(WriteupWinner::FILTER_LABEL) }
    first_winner_label = winner_items.first&.dig(:writeup_winner, :label) || "Contest win"
    tag_case = timeline_tag_case

    visit "/timeline"

    assert_selector ".timeline-content", count: total_items
    assert_timeline_year_counts_match_visible_cards
    timeline_tag_positions = page.evaluate_script(<<~JS)
      (() => {
        const card = [...document.querySelectorAll(".timeline-content")].find((entry) => entry.querySelector(".timeline-tags"));
        const title = card.querySelector(".timeline-title").getBoundingClientRect();
        const tags = card.querySelector(".timeline-tags").getBoundingClientRect();
        const nextContent = card.querySelector(".timeline-meta, .timeline-source").getBoundingClientRect();

        return {
          tagsBelowTitle: tags.top >= title.bottom - 1,
          nextContentBelowTags: nextContent.top >= tags.bottom - 1
        };
      })()
    JS
    assert_equal true, timeline_tag_positions["tagsBelowTitle"]
    assert_equal true, timeline_tag_positions["nextContentBelowTags"]
    assert_text "Timeline"
    assert_selector ".content-filter-tag-group-label", text: "CONTENT TYPE"
    assert_selector ".content-filter-tag-group-label", text: "TOPICS, PROJECTS, AND SOURCES"
    assert_selector ".content-filter-panel .filter-chip", text: "CVE"
    assert_selector ".content-filter-panel .filter-chip", text: "CTF writeup"
    assert_selector ".timeline-tags .writeup-winner-badge-timeline[data-filter-tag='Writeup winner']", text: first_winner_label

    fill_in "timeline-search-input", with: search_case[:query]
    assert_selector "[data-filter-count='timeline']", text: filter_count_text(search_case[:items].length, total_items)
    assert_selector ".timeline-content", text: search_case[:items].first[:title]
    assert_hidden_timeline_item search_case[:items]
    assert_timeline_year_counts_match_visible_cards

    find("[data-filter-reset='timeline']").click
    find(".content-filter-panel .filter-chip", text: "Certificate").click
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
    find(".timeline-tags .timeline-tag-pill", text: tag_case[:tag], match: :first).click
    assert_selector ".timeline-tags .timeline-tag-pill.is-active", text: tag_case[:tag]
    assert_selector ".content-filter-panel .filter-chip.is-active", text: tag_case[:tag]
    assert_selector "[data-filter-count='timeline']", text: filter_count_text(tag_case[:items].length, total_items)
    assert_selector ".timeline-content", text: tag_case[:items].first[:title]
    assert_hidden_timeline_item tag_case[:items]
    assert_timeline_year_counts_match_visible_cards
  end

  test "ctf markdown preserves anchors and external links while resolving local images" do
    post = ctf_post_with_anchor_external_link_and_image

    visit post[:link]

    assert_text post[:title]
    assert_selector ".markdown-content a[href^='#']"
    assert_selector ".markdown-content a[href^='http']"
    assert_selector ".markdown-content img[src*='/assets/ctf/writeups/']"
  end

  test "table of contents indents nested headings by depth" do
    page.current_window.resize_to(1440, 1200)
    post, top_heading, nested_heading = ctf_post_with_nested_headings

    visit post[:link]

    assert_selector "#toc-body .toc-depth-#{top_heading[:level] - 1}", text: top_heading[:text]
    assert_selector "#toc-body .toc-depth-#{nested_heading[:level] - 1}", text: nested_heading[:text]

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const links = [...document.querySelectorAll("#toc-body .toc-anchor")];
        const top = links.find((link) => link.innerText.trim() === #{top_heading[:text].to_json});
        const nested = links.find((link) => link.innerText.trim() === #{nested_heading[:text].to_json});

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
    assert_selector ".ctf-card .ctf-reading-time", minimum: 1, text: /min read/
    ctf_reading_time_style = page.evaluate_script(<<~JS)
      (() => {
        const element = document.querySelector(".ctf-card .ctf-reading-time");
        const style = window.getComputedStyle(element);

        return {
          borderTopWidth: style.borderTopWidth,
          backgroundColor: style.backgroundColor
        };
      })()
    JS
    assert_equal "0px", ctf_reading_time_style["borderTopWidth"]
    assert_equal "rgba(0, 0, 0, 0)", ctf_reading_time_style["backgroundColor"]
    target_path = URI.parse(first_card.find(".blog-post-card-hitbox", visible: :all)[:href]).path
    click_card_link_area(first_card)

    assert_current_path target_path
  end

  test "content filters search by text tags and year" do
    ctf_total = ctf_overview_items.length
    ctf_tag_case = ctf_overview_tag_case
    ctf_search_case = ctf_overview_search_case
    ctf_year_case = ctf_overview_year_case
    writeup_case = writeup_filter_case
    internal_author_post, internal_author = first_ctf_post_with_internal_author_link

    visit "/ctf"

    ctf_filter_tags = all(".content-filter-panel .content-filter-tag-list [data-filter-tag]").map do |chip|
      chip["data-filter-tag"]
    end
    assert_equal "Writeup winner", ctf_filter_tags.first
    assert_equal 1, ctf_filter_tags.count("Writeup winner")
    assert_selector ".content-filter-panel .filter-chip.writeup-winner-badge-filter", text: "Writeup winner"
    assert_selector ".content-filter-panel .filter-chip", text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i
    assert_selector ".ctf-card .filter-chip", text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i
    assert_selector ".ctf-card .filter-chip.writeup-winner-badge-filter", text: "Writeup winner"
    find(".content-filter-panel .filter-chip", text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i).click
    assert_selector ".content-filter-panel .filter-chip.is-active", text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i
    assert_selector "[data-filter-count='ctfs']", text: filter_count_text(ctf_tag_case[:items].length, ctf_total)
    assert_equal ctf_tag_case[:items].map { |item| item[:name] }, visible_ctf_names

    find("[data-filter-reset='ctfs']").click
    assert_selector "[data-filter-count='ctfs']", text: filter_count_text(ctf_total, ctf_total)
    fill_in "ctf-search-input", with: ctf_search_case[:query]
    assert_selector "[data-filter-count='ctfs']", text: filter_count_text(ctf_search_case[:items].length, ctf_total)
    assert_equal ctf_search_case[:items].map { |item| item[:name] }, visible_ctf_names

    find("[data-filter-reset='ctfs']").click
    assert_selector "[data-filter-count='ctfs']", text: filter_count_text(ctf_total, ctf_total)
    select_filter_year("ctfs", ctf_year_case[:year].to_s)
    assert_selector "[data-filter-count='ctfs']", text: filter_count_text(ctf_year_case[:items].length, ctf_total)
    assert_equal ctf_year_case[:items].map { |item| item[:name] }, visible_ctf_names

    visit "/ctf/#{writeup_case[:directory]}"
    assert_selector ".blog-post-authors", text: "Challenge by"
    assert_selector ".content-filter-tags-label", text: "TAGS"
    assert_selector ".content-filter-panel .filter-chip", text: writeup_case[:tag]

    within ".content-filter-panel" do
      find(".filter-chip", text: writeup_case[:tag]).click
      assert_selector ".filter-chip.is-active", text: writeup_case[:tag]
    end
    assert_selector "[data-filter-count='writeups']", text: filter_count_text(writeup_case[:tag_posts].length, writeup_case[:posts].length)
    assert_equal writeup_case[:tag_posts].map { |post| post[:title] }, visible_writeup_titles

    find("[data-filter-reset='writeups']").click
    assert_selector "[data-filter-count='writeups']", text: filter_count_text(writeup_case[:posts].length, writeup_case[:posts].length)
    select_filter_year("writeups", writeup_case[:year].to_s)
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

  test "blog filters search text and publish year" do
    blog_total = blog_posts.length
    tag_case = blog_tag_case
    search_case = blog_search_case
    year_case = blog_year_case
    logo_posts = blog_posts.select { |post| repository.blog_metadata.dig(post[:slug], "logo").present? }

    visit "/blog"

    assert_selector ".content-filter-panel .filter-chip", text: tag_case[:tag]
    assert_selector ".blog-post-card", text: search_case[:post][:title]
    assert_selector ".blog-post-card[data-filter-tags*='#{tag_case[:tag]}']"
    assert_selector ".blog-post-card[data-filter-card='blogs'] .blog-logo", minimum: logo_posts.length if logo_posts.any?

    fill_in "blog-search-input", with: search_case[:query]
    assert_selector "[data-filter-count='blogs']", text: filter_count_text(search_case[:items].length, blog_total)
    assert_equal search_case[:items].map { |post| post[:title] }.sort, visible_blog_titles.sort

    find("[data-filter-reset='blogs']").click
    select_filter_year("blogs", year_case[:year].to_s)
    assert_selector "[data-filter-count='blogs']", text: filter_count_text(year_case[:items].length, blog_total)
    assert_equal year_case[:items].map { |post| post[:title] }.sort, visible_blog_titles.sort

    find("[data-filter-reset='blogs']").click
    fill_in "blog-search-input", with: "definitely-not-a-post"
    assert_selector "[data-filter-count='blogs']", text: filter_count_text(0, blog_total)
    assert_selector ".content-filter-empty", text: "No blog posts match the current filters."
    assert_no_selector ".blog-post-card"
  end

  test "blog and writeup cards keep full-card navigation" do
    blog_post = first_blog_post
    writeup_post = first_ctf_post

    visit "/blog"

    click_card_link_area(find(".blog-post-card", text: blog_post[:title]))
    assert_current_path blog_post[:link]
    assert_selector ".writeup-title", text: blog_post[:title]

    visit "/ctf/#{writeup_post[:directory]}"
    click_card_link_area(find(".blog-post-card", text: writeup_post[:title]))
    assert_current_path writeup_post[:link]
    assert_selector ".writeup-title", text: writeup_post[:title]
  end

  test "winning writeups show proof badges on overview cards and articles" do
    winner_case = winning_writeup_case

    visit "/ctf/#{winner_case[:directory]}"

    winner_case[:winner_posts].each do |post|
      winner = WriteupWinner.from_metadata(post[:metadata])
      within find(".blog-post-card", text: post[:title]) do
        assert_selector ".blog-post-meta-row > .writeup-winner-badge:first-child[href='#{winner[:proof_url]}']", text: winner[:label]
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

    if (external_winner = first_external_winning_writeup)
      external_badge = WriteupWinner.from_metadata(external_winner[:metadata])
      visit external_winner[:link]
      assert_selector ".writeup-winner-article .writeup-winner-badge[href='#{external_badge[:proof_url]}']", text: external_badge[:label]
    end
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
      "/ctf" => "CTF writeups",
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
      years = metadata_values.filter_map { |entry| repository.metadata_year(entry) }.uniq.sort.reverse
      filter_text = [ name, metadata["description"], directory, tags ].flatten.compact.join(" ").downcase

      {
        name: name,
        directory: directory,
        link: "/ctf/#{directory}",
        writeups: writeups,
        tags: tags,
        years: years,
        text: filter_text
      }
    end
  end

  def sorted_filter_tags(values)
    values.map(&:to_s).reject(&:blank?).uniq { |value| value.downcase }.sort_by { |value| WriteupWinner.filter_sort_key(value) }
  end

  def ctf_overview_tag_case
    groups = {}
    ctf_overview_items.each do |item|
      item[:tags].reject { |tag| tag == WriteupWinner::FILTER_LABEL }.each do |tag|
        key = tag.downcase
        groups[key] ||= { tag: tag, items: [] }
        groups[key][:items] << item
      end
    end

    groups.values.find { |group| group[:items].length < ctf_overview_items.length } ||
      groups.values.first ||
      flunk("expected at least one CTF filter tag")
  end

  def ctf_overview_search_case
    ctf_overview_items.each do |item|
      query = item[:name]
      matches = ctf_overview_items.select { |candidate| candidate[:text].include?(query.downcase) }
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
      year_case = writeup_year_case_for(posts)
      next unless tag_case && year_case

      return {
        directory: event[:directory],
        posts: posts,
        tag: tag_case[:tag],
        tag_posts: tag_case[:posts],
        year: year_case[:year],
        year_posts: year_case[:posts]
      }
    end

    flunk("expected a CTF overview with filterable writeups")
  end

  def writeup_tag_case_for(posts)
    groups = {}
    posts.each do |post|
      repository.metadata_tags(post[:metadata] || {}).reject { |tag| tag == WriteupWinner::FILTER_LABEL }.each do |tag|
        key = tag.downcase
        groups[key] ||= { tag: tag, posts: [] }
        groups[key][:posts] << post
      end
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

  def blog_tag_case
    groups = {}
    blog_posts.each do |post|
      Array(post[:categories]).each do |tag|
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
      matches = blog_posts.select { |candidate| blog_filter_text(candidate).include?(query.downcase) }
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
    ([ post[:title], post[:description], published, post[:published].year, post[:topic] ] + Array(post[:categories]))
      .compact
      .join(" ")
      .downcase
  end

  def first_timeline_post_with_tags
    timeline_items.find { |item| item[:link].to_s.match?(%r{\A/(blog|ctf)/}) && visible_timeline_tags(item).any? } ||
      flunk("expected at least one timeline item with visible tags")
  end

  def first_visible_timeline_tag
    visible_timeline_tags(first_timeline_post_with_tags).first
  end

  def visible_timeline_tags(item)
    Array(item[:tags]).reject { |tag| [ item[:label], WriteupWinner::FILTER_LABEL ].include?(tag) }
  end

  def timeline_search_case
    timeline_items.each do |item|
      query = item[:title].to_s
      next if query.blank?

      matches = timeline_items.select { |candidate| candidate[:search_text].to_s.include?(query.downcase) }
      return { query: query, items: matches } if matches.any?
    end

    flunk("expected at least one searchable timeline item")
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

  def assert_hidden_timeline_item(visible_items)
    hidden = timeline_items.find { |item| visible_items.exclude?(item) }
    return unless hidden

    assert_no_selector ".timeline-card-hitbox[href='#{hidden[:link]}']"
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
      [ post[:link], markdown_headings(post[:content]).first[:text] ]
    end
  end

  def markdown_headings(markdown)
    headings = []
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
      headings << { level: match[1].length, text: text } if text.present?
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
          chipBorderRadius: chipStyle?.borderTopLeftRadius || null,
          chipBackground: chipStyle?.backgroundColor || null
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
end
