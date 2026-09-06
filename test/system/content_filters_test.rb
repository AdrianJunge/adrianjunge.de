require "application_system_test_case"
require_relative "../support/site_page_helpers"

class ContentFiltersTest < ApplicationSystemTestCase
  include SitePageHelpers

  test "additional filters are revealed for linked URLs and remain removable with their original button" do
    [ "/timeline", "/blog", "/ctf", "/ctf/cscg" ].each do |path|
      visit path
      assert_selector ".content-filter-panel[data-initialized='true']"
      assert_no_selector ".content-filter-more[open]"
      tag = find(".content-filter-more [data-filter-tag]", match: :first, visible: :all)["data-filter-tag"]

      visit "#{path}?#{URI.encode_www_form(tag: tag)}"
      assert_selector ".content-filter-more[open]"
      chip = find(".content-filter-more [data-filter-tag][aria-pressed='true']")
      assert_equal tag, chip["data-filter-tag"]
      chip.send_keys(:space)
      assert_equal "false", chip["aria-pressed"]
      assert_nil URI.parse(page.current_url).query
      assert_selector ".content-filter-more[open]", wait: 0
    end
  end

  test "selecting an additional tag on a result opens its filter group without moving focus" do
    [ "/timeline", "/blog", "/ctf", "/ctf/cscg" ].each do |path|
      visit path
      assert_selector ".content-filter-panel[data-initialized='true']"
      tag = page.evaluate_script(<<~JS)
        (() => {
          const more = new Set([...document.querySelectorAll('.content-filter-more [data-filter-tag]')]
            .map(chip => chip.dataset.filterTag.toLowerCase()));
          const chip = [...document.querySelectorAll('[data-filter-card] [data-filter-tag]')]
            .find(chip => more.has(chip.dataset.filterTag.toLowerCase()));
          if (!chip) return null;
          chip.dataset.disclosureTest = 'true';
          return chip.dataset.filterTag;
        })()
      JS
      assert tag, "Expected an additional filter on a result card at #{path}"
      chip = find("[data-disclosure-test='true']")
      page.execute_script("document.querySelector('[data-disclosure-test]').focus()")
      assert_equal "true", page.evaluate_script("document.activeElement.dataset.disclosureTest"), "Expected keyboard focus before filtering at #{path}"
      page.driver.browser.action.send_keys(:enter).perform
      assert_selector ".content-filter-more[open]"
      selected = find(".content-filter-more [data-filter-tag][aria-pressed='true']")
      assert_equal tag.downcase, selected["data-filter-tag"].downcase
      assert_equal "true", page.evaluate_script("document.activeElement.dataset.disclosureTest"), "Expected keyboard focus after filtering at #{path}"
    end
  end

  test "history navigation and cached page entry reveal additional selected filters" do
    visit "/timeline"
    assert_selector ".content-filter-panel[data-initialized='true']"
    find(".content-filter-more > summary").click
    chip = find(".content-filter-more [data-filter-tag]", match: :first)
    tag = chip["data-filter-tag"]
    chip.click
    filtered_url = page.current_url
    find("[data-filter-reset]").click
    find(".content-filter-more > summary").click
    assert_no_selector ".content-filter-more[open]"

    page.go_back
    assert_current_path filtered_url
    assert_selector ".content-filter-more[open]"
    assert_equal tag, find(".content-filter-more [aria-pressed='true']")["data-filter-tag"]
    page.go_forward
    assert_no_selector ".content-filter-more [aria-pressed='true']"
    find(".content-filter-more > summary").click
    page.go_back
    assert_selector ".content-filter-more[open]"

    find(".content-filter-more > summary").click
    page.execute_script("window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true }))")
    assert_selector ".content-filter-more[open]"
    assert_current_path filtered_url
  end

  test "common tags and search leave more filters compact unless manually opened" do
    [ "/timeline", "/blog", "/ctf", "/ctf/cscg" ].each do |path|
      visit path
      assert_selector ".content-filter-panel[data-initialized='true']"
      chip = find(".content-filter-common [data-filter-tag]", match: :first)
      tag = chip["data-filter-tag"]
      chip.click
      assert_no_selector ".content-filter-more[open]"
      visit "#{path}?#{URI.encode_www_form(tag: tag)}"
      assert_selector ".content-filter-common [aria-pressed='true']"
      assert_no_selector ".content-filter-more[open]"
      find("[data-filter-search]").fill_in(with: "no-matching-published-post")
      assert_no_selector ".content-filter-more[open]"
      find("[data-filter-reset]").click
      find(".content-filter-more > summary").click
      find("[data-filter-search]").fill_in(with: "no-matching-published-post")
      assert_selector ".content-filter-more[open]"
    end
  end

  test "filter tags toggle themselves without extra removal buttons and search keeps an accessible name" do
    [ "/timeline", "/blog", "/ctf", "/ctf/cscg" ].each do |path|
      visit path
      assert_selector ".content-filter-panel[data-initialized='true']"
      panel = find(".content-filter-panel")
      search = panel.find("input[type='search']")
      label = panel.find("label[for='#{search[:id]}']", visible: :all)
      assert_equal "Search", label.text(:all)
      assert_includes label[:class], "sr-only"
      assert search[:placeholder].present?
      dimensions = page.evaluate_script("(() => { const label = document.querySelector('label[for=\"#{search[:id]}\"]'); return { width: label.getBoundingClientRect().width, height: label.getBoundingClientRect().height }; })()")
      assert_operator dimensions["width"], :<=, 1
      assert_operator dimensions["height"], :<=, 1

      total = all("[data-filter-card]").length
      chip = panel.find(".filter-chip:not(.is-uncombinable)", match: :first)
      chip.click
      assert_equal "true", chip["aria-pressed"]
      assert_no_selector "[data-filter-selected], .content-filter-selected-chip", visible: :all
      assert_includes page.current_url, "tag="
      chip.send_keys(:space)
      assert_equal "false", chip["aria-pressed"]
      assert_no_selector ".content-filter-panel .filter-chip.is-active"
      assert_selector "[data-filter-card]", count: total
      assert_nil URI.parse(page.current_url).query
    end
  end

  test "year filter uses a labelled native select" do
    [ "/ctf", "/blog" ].each do |path|
      visit path
      select = find(".content-filter-select")
      assert_selector "label[for='#{select[:id]}']", text: /year/i
      assert_no_selector ".content-filter-year-button", visible: :all
      option = select.all("option").find { |item| item[:value].present? }
      select.select(option.text)
      assert_equal option[:value], select.value
      assert_includes page.current_url, "year=#{option[:value]}"
      select.send_keys(:space)
      page.driver.browser.action.send_keys(:home, :enter).perform
      assert_equal "", select.value
    end
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

    open_more_filters

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
    if (authored_item = merged_timeline_item_with_source_prefix("about-challenge-"))
      assert_merged_timeline_item_rendered(authored_item)
    end
    if (certificate_item = merged_timeline_item_with_source_prefix("about-certificate-"))
      assert_merged_timeline_item_rendered(certificate_item)
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
    rendered_types = all(".content-filter-panel [data-filter-tag]").map { |chip| chip["data-filter-tag"] }.select { |tag| ContentTagTaxonomy.content_type?(tag) }.sort
    assert_equal timeline_content_type_tags.sort, rendered_types
    assert_selector ".content-filter-panel .filter-chip.difficulty-badge-filter.difficulty-badge-#{difficulty_case[:key]}",
                    text: /^#{Regexp.escape(difficulty_case[:label])}$/
    assert_selector ".content-filter-panel .filter-chip.severity-badge-filter.severity-badge-#{severity_case[:key]}",
                    text: /^#{Regexp.escape(severity_case[:label])}$/
    assert_selector ".content-filter-panel .filter-chip",
                    text: /^#{Regexp.escape(ctf_competition_case[:label])}$/
    within find(".content-filter-tag-group", text: "REPOSITORIES") do
      rendered_repositories = all("[data-filter-tag]").map { |chip| chip["data-filter-tag"] }.sort
      assert_equal timeline_repository_tags.sort, rendered_repositories
    end
    assert_selector ".content-filter-panel .filter-chip.cve-badge-filter",
                    text: /^#{Regexp.escape(cve_case[:label])}$/
    assert_selector ".content-filter-panel .filter-chip.cwe-badge-filter",
                    text: /^#{Regexp.escape(cwe_case[:label])}$/
    timeline_items.map { |item| item[:label] }.uniq.each do |label|
      assert_selector ".content-filter-panel .filter-chip", text: /^#{Regexp.escape(label)}$/
    end
    assert_selector ".timeline-tags .difficulty-badge-filter.difficulty-badge-#{difficulty_case[:key]}[data-filter-tag='difficulty:#{difficulty_case[:key]}']",
                    text: /^#{Regexp.escape(difficulty_case[:label])}$/
    assert_selector ".timeline-tags .severity-badge-filter.severity-badge-#{severity_case[:key]}[data-filter-tag='severity:#{severity_case[:key]}']",
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
    open_more_filters
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

    open_more_filters

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
    assert_operator filter_panel_after_tag["height"] - filter_panel_initial["height"], :<=, 80
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
    assert_current_path "/ctf?#{Rack::Utils.build_query(tag: ContentTagTaxonomy.canonical_value(ctf_difficulty_case[:label]))}"
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

    open_more_filters
    assert_field "ctf-search-input", with: ctf_search_case[:query]
    assert_equal ctf_year_case[:year].to_s, page.evaluate_script("document.querySelector('[data-filter-year=\"ctfs\"]').value")
    assert_selector ".content-filter-panel .filter-chip.is-active", text: /^#{Regexp.escape(ctf_tag_case[:tag])}$/i

    visit "/ctf/#{writeup_case[:directory]}"

    open_more_filters
    assert_selector ".blog-post-authors", text: "Challenge by"
    writeup_filter_initial_height = page.evaluate_script(<<~JS)
      Math.round(document.querySelector(".content-filter-panel").getBoundingClientRect().height)
    JS
    assert_selector ".content-filter-tag-group-label", text: "COMMON FILTERS"
    assert_selector ".content-filter-panel .filter-chip.difficulty-badge-filter.difficulty-badge-#{writeup_difficulty_case[:key]}",
                    text: /^#{Regexp.escape(writeup_difficulty_case[:label])}$/
    assert_selector ".content-filter-panel .filter-chip.category-badge-filter.category-badge-#{ContentCategoryTag.css_key(writeup_case[:tag])}",
                    text: /^#{Regexp.escape(writeup_case[:tag])}$/i

    within ".content-filter-panel" do
      find(".filter-chip.difficulty-badge-filter", text: /^#{Regexp.escape(writeup_difficulty_case[:label])}$/).click
      assert_selector ".filter-chip.difficulty-badge-filter.is-active", text: writeup_difficulty_case[:label]
    end
    assert_current_path "/ctf/#{writeup_case[:directory]}?#{Rack::Utils.build_query(tag: ContentTagTaxonomy.canonical_value(writeup_difficulty_case[:label]))}"
    writeup_filter_after_tag_height = page.evaluate_script(<<~JS)
      Math.round(document.querySelector(".content-filter-panel").getBoundingClientRect().height)
    JS
    assert_operator writeup_filter_after_tag_height - writeup_filter_initial_height, :<=, 80
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

    open_more_filters
    assert_selector ".blog-post-author-link[href='#{internal_author[:url]}']", text: internal_author[:name]
  end

  test "filter chips clear active state when tapped twice" do
    ctf_tag_case = ctf_overview_tag_case

    visit "/ctf"

    open_more_filters

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

    open_more_filters

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

    open_more_filters

    assert_selector ".content-filter-tag-group-label", text: "CONTENT TYPE"
    within find(".content-filter-tag-group", text: "CONTENT TYPE") do
      assert_selector ".filter-chip", text: /^Security Research$/
    end
    assert_selector ".content-filter-panel .filter-chip", text: tag_case[:tag]
    assert_selector ".blog-post-card", text: search_case[:post][:title]
    assert_selector ".blog-post-card[data-filter-tags*='Security Research']"
    assert_selector ".blog-post-card[data-filter-tags*='#{tag_case[:tag]}']"
    assert_selector ".blog-post-card[data-filter-card='blogs'] .blog-logo", count: logo_posts.length
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

    open_more_filters
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
end
