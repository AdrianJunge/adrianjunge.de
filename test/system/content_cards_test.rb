require "application_system_test_case"
require_relative "../support/site_page_helpers"

class ContentCardsTest < ApplicationSystemTestCase
  include SitePageHelpers

  test "mixed post cards identify and link their blog or CTF section" do
    page.current_window.resize_to(1280, 1000)
    latest_blog_posts = landing_latest_posts.select { |post| post[:type] == "blog" }
    latest_ctf_posts = landing_latest_posts.select { |post| post[:type] == "ctf" }

    visit "/"

    assert_selector_count ".landing-writeup-cards .content-card-section-link-blog[href='/blog'] img[src*='task-bar/blog']", latest_blog_posts.length
    assert_selector_count ".landing-writeup-cards .content-card-section-link-ctf[href='/ctf'] img[src*='task-bar/flag']", latest_ctf_posts.length
    marker_layout = page.evaluate_script(<<~JS)
      (() => {
        const marker = document.querySelector(".landing-writeup-cards .content-card-section-link");
        const card = marker.closest(".content-card");
        const markerRect = marker.getBoundingClientRect();
        const cardRect = card.getBoundingClientRect();

        return {
          topGap: Math.round(markerRect.top - cardRect.top),
          rightGap: Math.round(cardRect.right - markerRect.right),
          width: Math.round(markerRect.width),
          height: Math.round(markerRect.height)
        };
      })()
    JS
    assert_in_delta 12, marker_layout["topGap"], 1
    assert_in_delta 12, marker_layout["rightGap"], 1
    assert_operator marker_layout["width"], :>=, 40
    assert_equal marker_layout["width"], marker_layout["height"]

    if latest_blog_posts.any?
      within find(".landing-writeup-cards .blog-post-card", text: latest_blog_posts.first[:title]) do
        find(".content-card-section-link-blog").click
      end
      assert_current_path "/blog"
    end

    visit "/"
    if latest_ctf_posts.any?
      within find(".landing-writeup-cards .blog-post-card", text: latest_ctf_posts.first[:title]) do
        find(".content-card-section-link-ctf").click
      end
      assert_current_path "/ctf"
    end

    visit "/timeline"
    timeline_blog_count = timeline_items.count { |item| item[:kind] == "blog" }
    timeline_ctf_count = timeline_items.count { |item| item[:kind] == "writeup" }

    assert_selector_count ".timeline-content .content-card-section-link-blog[href='/blog'] img[src*='task-bar/blog']", timeline_blog_count
    assert_selector_count ".timeline-content .content-card-section-link-ctf[href='/ctf'] img[src*='task-bar/flag']", timeline_ctf_count
    assert_selector_count ".timeline-content .content-card-section-link", timeline_blog_count + timeline_ctf_count

    timeline_section_link = find(".timeline-content .content-card-section-link", match: :first)
    expected_section_path = timeline_section_link["data-content-section"] == "blog" ? "/blog" : "/ctf"
    timeline_section_link.click
    assert_current_path expected_section_path
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
    assert_selector ".timeline-item:not(.timeline-item-upcoming) .timeline-content", minimum: 1
    assert_equal latest_styles, card_surface_styles(".timeline-item:not(.timeline-item-upcoming) .timeline-content")

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

  test "timeline entries are full-card links" do
    page.current_window.resize_to(1280, 1200)
    timeline_post = first_timeline_post_with_tags
    tag_name = first_visible_timeline_tag

    visit "/timeline"

    open_more_filters

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

    open_more_filters
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

    open_more_filters
    find(".timeline-tags .timeline-tag-pill", text: tag_name, match: :first).click
    assert_current_path "/timeline?#{Rack::Utils.build_query(tag: tag_name)}"
    assert_selector ".timeline-tags .timeline-tag-pill.is-active", text: tag_name
    assert_selector ".content-filter-panel .filter-chip.is-active", text: tag_name
  end

  test "timeline renders every talk event as its own card" do
    talk_entries = repository.about_entries(ApplicationController::ABOUTME_TALKS_PATH)
    talk_events = talk_entries.flat_map { |entry| Array(entry["timeline"]) }
    talk_items = timeline_items.select { |item| item[:kind] == "talk" }
    expected_links = talk_events.map { |event| "/about##{event.fetch("id")}" }

    assert_equal repository.timeline_event_count(talk_entries), talk_items.length
    assert_equal expected_links.sort, talk_items.map { |item| item[:link] }.sort

    visit "/timeline"

    talk_items.each do |item|
      timeline_entry = timeline_content_card(item).find(
        :xpath,
        "./ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' timeline-item ')]"
      )

      within timeline_entry do
        assert_selector ".timeline-title", exact_text: item[:title]
        assert_selector ".timeline-date time", exact_text: item[:display_date]
        assert_selector ".timeline-kind-pill[data-filter-tag='Talk']", count: 1
      end
    end
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
    multi_category_post = ctf_posts.find do |post|
      ContentTagTaxonomy.canonical_values(post[:metadata]["categories"]).length > 1
    end || flunk("expected a multi-category writeup")
    single_category_post = ctf_posts.find do |post|
      ContentTagTaxonomy.canonical_values(post[:metadata]["categories"]).one?
    end || flunk("expected a single-category writeup")
    categories = ContentTagTaxonomy.canonical_values(multi_category_post[:metadata]["categories"])
    category_keys = categories.map { |category| ContentCategoryTag.css_key(category) }

    visit "/ctf/#{multi_category_post[:directory]}"

    within find(".writeup-post-card", text: multi_category_post[:title]) do
      assert_selector ".writeup-post-card-logo .category-split-icon[data-category-count='#{category_keys.length}'][aria-label='#{categories.to_sentence} categories']"
      category_keys.each_with_index do |category_key, index|
        assert_selector ".category-split-icon-slice[data-category='#{category_key}'][style*='--category-index: #{index}; --category-count: #{category_keys.length}; --category-clip: polygon(50% 50%'] .category-split-icon-image[src*='ctf/categories/']", visible: :all
      end
      assert_selector ".category-split-icon-divider", count: category_keys.length, visible: :all
    end

    visit "/ctf/#{single_category_post[:directory]}"

    category = ContentTagTaxonomy.canonical_values(single_category_post[:metadata]["categories"]).first
    within find(".writeup-post-card", text: single_category_post[:title]) do
      assert_no_selector ".category-split-icon"
      assert_selector ".writeup-post-card-logo img.blog-logo[src*='ctf/categories/'], .writeup-post-card-logo svg"
      assert_selector ".writeup-post-card-logo img.blog-logo[alt='#{category} category']" if page.has_selector?(".writeup-post-card-logo img.blog-logo", wait: 0)
    end
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
end
