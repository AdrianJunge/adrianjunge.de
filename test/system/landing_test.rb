require "application_system_test_case"
require_relative "../support/site_page_helpers"

class LandingTest < ApplicationSystemTestCase
  include SitePageHelpers

  test "mobile landing keeps recent post spacing even and shows the scroll affordance" do
    page.current_window.resize_to(390, 700)
    expected_card_count = landing_latest_posts.length
    visit "/"

    assert_selector "#scroll-down-button button"
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
    assert_equal "block", metrics["scrollButtonDisplay"]
    assert_operator metrics["gaps"].length, :>=, 1
    assert_operator metrics["gaps"].min, :>=, 15
    assert_in_delta metrics["gaps"].first, metrics["gaps"].last, 1
  end

  test "short laptops and phones keep a nonoverlapping arrow to Latest notes" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    [ 1440, 390 ].each do |width|
      page.current_window.resize_to(width, 1000)
      chrome_height = page.evaluate_script("window.outerHeight - window.innerHeight")
      page.current_window.resize_to(width, 757 + chrome_height)
      visit "/"
      assert_selector "#scroll-down-button button"
      metrics = page.evaluate_script(<<~JS)
        (() => {
          const arrow = document.getElementById('scroll-down-button');
          const rect = arrow.getBoundingClientRect();
          const overview = document.querySelector('.landing-metrics').getBoundingClientRect();
          return {
            height: innerHeight, position: getComputedStyle(arrow).position,
            gap: rect.top - overview.bottom, left: rect.left, right: rect.right,
            viewportWidth: innerWidth
          };
        })()
      JS
      assert_in_delta 757, metrics["height"], 1
      assert_equal "static", metrics["position"]
      assert_operator metrics["gap"], :>=, 16
      assert_operator metrics["left"], :>=, 0
      assert_operator metrics["right"], :<=, metrics["viewportWidth"]
      find("#scroll-down-button button").click
      heading_top = page.evaluate_script("document.querySelector('#landing-bottom h2').getBoundingClientRect().top")
      assert_operator heading_top, :>=, page.evaluate_script("document.getElementById('top-taskbar').getBoundingClientRect().bottom")
      assert_operator heading_top, :<, 200
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "desktop overview is centered in the first viewport and the arrow reaches Latest notes" do
    page.current_window.resize_to(1440, 1100)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    visit "/"
    assert_selector "#scroll-down-button button"
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const top = document.getElementById('landing-top').getBoundingClientRect();
        const hero = document.querySelector('.landing-hero-shell').getBoundingClientRect();
        const overview = document.querySelector('.landing-metrics').getBoundingClientRect();
        const arrow = document.getElementById('scroll-down-button').getBoundingClientRect();
        const bottom = document.getElementById('landing-bottom').getBoundingClientRect();
        return {
          topBottom: top.bottom, viewportHeight: innerHeight,
          groupCenter: (hero.top + overview.bottom) / 2,
          sectionCenter: (top.top + top.bottom) / 2,
          arrowTop: arrow.top, overviewBottom: overview.bottom,
          notesTop: bottom.top
        };
      })()
    JS
    assert_in_delta metrics["viewportHeight"], metrics["topBottom"], 2
    assert_in_delta metrics["sectionCenter"], metrics["groupCenter"], 16
    assert_operator metrics["arrowTop"], :>, metrics["overviewBottom"]
    assert_operator metrics["notesTop"], :>=, metrics["topBottom"]
    find("#scroll-down-button button").click
    assert_operator page.evaluate_script("window.scrollY"), :>, 300
    heading_top = page.evaluate_script("document.querySelector('#landing-bottom h2').getBoundingClientRect().top")
    assert_operator heading_top, :>=, page.evaluate_script("document.getElementById('top-taskbar').getBoundingClientRect().bottom")
    assert_operator heading_top, :<, 200
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "homepage types deletes and repeats the original shuffled messages" do
    phrases = [
      "Some people collect stamps. I collect stack traces.",
      "My favorite input is the one nobody validated.",
      "Politely asking software uncomfortable questions.",
      "CTF enthusiast",
      "I like puzzles that crash systems.",
      "Turning weird behavior into writeups.",
      "Teaching machines to misbehave.",
      "CTF flags, real bugs, questionable sleep schedule.",
      "Web and PWN player",
      "Your browser knows everything - XSLeaks just politely ask",
      "Source code tells jokes in edge cases.",
      "I love breaking stuff so others can fix it.",
      "Making impossible states feel very possible.",
      "The best exploit starts with: wait, that is weird.",
      "If it runs, I poke it.",
      "If it parses, I probably want to test it."
    ]
    page.current_window.resize_to(1440, 1100)
    preload = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
      // Accelerate only this browser test while exercising the real Typed.js loop.
      const originalSetTimeout = window.setTimeout;
      window.setTimeout = (callback, delay, ...args) => originalSetTimeout.call(window, callback, Math.min(Number(delay) || 0, 1), ...args);
      document.addEventListener('DOMContentLoaded', () => {
        const element = document.getElementById('typing');
        const phrases = #{phrases.to_json};
        const completedPhrases = new Set();
        let previous = element.textContent;
        window.taglineLog = { completed: [], deleting: false, retyping: false, repeated: false };
        new MutationObserver(() => {
          const text = element.textContent;
          if (text.length < previous.length) window.taglineLog.deleting = true;
          if (window.taglineLog.deleting && text.length > previous.length) window.taglineLog.retyping = true;
          if (text !== previous && phrases.includes(text)) {
            window.taglineLog.repeated ||= completedPhrases.has(text);
            completedPhrases.add(text);
            window.taglineLog.completed.push(text);
          }
          if (completedPhrases.size === phrases.length && window.taglineLog.repeated) {
            document.documentElement.dataset.taglineRepeated = 'true';
          }
          previous = text;
        }).observe(element, { subtree: true, childList: true, characterData: true });
      });
    JS
    visit "/"
    assert_selector ".typed-cursor", text: "|", wait: 20
    assert_selector "html[data-tagline-repeated='true']", visible: :all, wait: 30
    log = page.evaluate_script("window.taglineLog")
    assert_equal phrases.sort, log.fetch("completed").uniq.sort
    assert log.fetch("deleting")
    assert log.fetch("retyping")
    assert log.fetch("repeated")
  ensure
    page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: preload["identifier"]) if preload
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
      assert_selector_count ".landing-writeup-cards .writeup-post-card .blog-logo[src*='/ctf/']", ctf_logo_count
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
      assert_selector_count ".landing-writeup-cards .blog-post-card[data-filter-card='blogs'] .blog-logo[src*='/blog/']", blog_logo_count
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
    assert_equal "none", timeline_chip_hover_styles["transform"], "tag links retain stable pointer hitboxes on hover"

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
      assert_equal "none", landing_difficulty_hover_styles["transform"]
    end

    landing_styles = post_card_styles(".landing-writeup-cards .blog-post-card")

    visit "/blog"
    assert_selector ".blog-posts-container .blog-post-card"
    blog_styles = post_card_styles(".blog-posts-container .blog-post-card")

    assert_equal blog_styles, landing_styles
  end

  test "landing page exposes about section counters as direct links" do
    page.current_window.resize_to(1280, 1200)
    visit "/"

    assert_text "I poke things politely and occasionally convince software to confess."
    assert_no_text "Security researcher and computer science student focused on web security"
    assert_no_text "Welcome to my flag collection"
    assert_selector ".landing-action[href='/timeline']", text: "Timeline"
    assert_selector ".landing-action[href='/about']", text: "About me"
    assert_selector ".landing-typed-line #typing"
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
    assert_equal "none", profile_link_styles["profileImageAnimation"]
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
end
