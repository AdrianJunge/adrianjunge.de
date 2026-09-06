require "application_system_test_case"

require_relative "../support/about_page_helpers"

class AboutmeTest < ApplicationSystemTestCase
  include AboutPageHelpers
  test "future About timeline events receive a dynamic Upcoming treatment" do
    travel_to Time.zone.local(2026, 9, 1, 12) do
      page.current_window.resize_to(1280, 1000)
      visit about_path
      page.execute_script(<<~JS)
        document.getElementById("talks").open = true;
        document.getElementById("joomla-sqli").querySelector(".profile-card-details").open = true;
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

  test "visiting about me page renders accessible profile cards and public sections" do
    repository = ContentRepository.new
    section_cases = about_section_cases(repository)
    page.current_window.resize_to(1440, 1200)
    visit about_path
    assert_selector "main.aboutme-page"
    assert_selector ".aboutme-section", count: 6
    assert_no_selector ".aboutme-section[open]"
    find("#cves > summary").click
    assert_selector ".aboutme-card-header a", minimum: 1
    assert_no_selector ".profile-card-details summary a", visible: :all
    assert_no_selector ".profile-card-details[open]"
    card = find("#cves .aboutme-card", match: :first)
    card.find(".profile-card-details > summary").send_keys(:enter)
    assert_selector "#cves .profile-card-details[open] .aboutme-card-body"
    page.execute_script("document.querySelectorAll('.aboutme-section, .profile-card-details').forEach(details => { details.open = true; })")
    assert_about_catalog_rendered(section_cases)
    assert_about_links_rendered(section_cases)
    assert_selector ".aboutme-card-icon", count: all(".aboutme-section .aboutme-card").length
    section_cases.each do |section|
      count_label = section[:count] == 1 ? section[:singular] : section[:plural]
      assert_selector "##{section[:id]} .aboutme-section-count", text: "#{section[:count]} #{count_label}"
    end
  end

  test "whole About card surfaces and native keyboard summaries toggle details once" do
    visit about_path
    find("#cves > summary").click
    card = find("#cves .profile-card[data-disclosure-bound='true']", match: :first)
    details_selector = "##{card['id']} > .profile-card-details"
    assert_no_selector "#{details_selector}[open]"

    card.find(".aboutme-card-title").click
    assert_selector "#{details_selector}[open]"
    card.find(".aboutme-card-body p", match: :first).click
    assert_no_selector "#{details_selector}[open]"

    summary = card.find(".profile-card-details > summary")
    summary.send_keys(:enter)
    assert_selector "#{details_selector}[open]"
    summary.send_keys(:space)
    assert_no_selector "#{details_selector}[open]"
    assert_selector "#{details_selector} > summary:focus"

    card.click(x: 6, y: 6)
    assert_selector "#{details_selector}[open]"
    card.click(x: 6, y: 6)
    assert_no_selector "#{details_selector}[open]"

    find("#certificates > summary").send_keys(:enter)
    assert_selector "#certificates[open]"
    find("#certificates > summary").send_keys(:space)
    assert_no_selector "#certificates[open]"
  end

  test "About category defaults are restored on a cached page entry, not during the visit" do
    visit about_path
    assert_selector ".profile-card[data-disclosure-bound='true']", minimum: 1, visible: :all
    assert_no_selector ".aboutme-section[open]"
    find("#certificates > summary").click
    assert_selector "#certificates[open]"
    page.execute_script(<<~JS)
      window.location.hash = '#talks';
      document.dispatchEvent(new Event('turbo:load'));
    JS
    assert_selector "#talks[open]"
    assert_selector "#certificates[open]"

    page.execute_script(<<~JS)
      history.replaceState(null, '', location.pathname);
      document.querySelectorAll('.aboutme-page > .aboutme-section').forEach(section => { section.open = true; });
      window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true }));
    JS
    assert_no_selector ".aboutme-page > .aboutme-section[open]"
    assert_no_selector ".profile-card-details[open]", visible: :all
    find("#certificates > summary").click
    assert_selector "#certificates[open]"

    page.execute_script(<<~JS)
      history.replaceState(null, '', '#talks');
      window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true }));
    JS
    assert_selector ".aboutme-page > .aboutme-section[open]", count: 1
    assert_selector "#talks[open]"
  end

  test "returning to About and reloading starts with every category closed" do
    visit about_path
    assert_selector ".profile-card[data-disclosure-bound='true']", minimum: 1, visible: :all
    find("#cves > summary").click
    find("#certificates > summary").click
    assert_selector "#cves[open], #certificates[open]", count: 2

    find(".taskbar-link[href='/blog']").click
    assert_current_path blog_path
    page.go_back
    assert_current_path about_path
    assert_no_selector ".aboutme-page > .aboutme-section[open]"

    find("#certificates > summary").click
    assert_selector "#certificates[open]"
    page.refresh
    assert_no_selector ".aboutme-page > .aboutme-section[open]"
  end

  test "About card secondary links and controls do not toggle their disclosure" do
    visit about_path
    find("#cves > summary").click
    card = find("#cves .profile-card[data-disclosure-bound='true']", match: :first)
    details_selector = "##{card['id']} > .profile-card-details"
    # Stop actual navigation after the card listener has handled the real click.
    page.execute_script(<<~JS)
      document.addEventListener('click', event => {
        const link = event.target.closest('.aboutme-page .profile-card a');
        if (!link) return;
        window.aboutClickedHref = link.href;
        event.preventDefault();
      });
    JS
    card.find(".aboutme-card-header a", match: :first).click
    assert_no_selector "#{details_selector}[open]"
    assert page.evaluate_script("window.aboutClickedHref"), "the secondary link received the click"

    card.find(".aboutme-card-title").click
    card.find(".aboutme-card-body a", match: :first).click
    assert_selector "#{details_selector}[open]"
    page.execute_script(<<~JS)
      const body = document.querySelector(#{details_selector.to_json}).querySelector('.aboutme-card-body');
      body.insertAdjacentHTML('afterbegin', '<button id="about-fixture-action">Example action</button><label>Example input <input id="about-fixture-input"></label>');
      document.getElementById('about-fixture-action').addEventListener('click', () => { window.aboutActionClicked = true; });
    JS
    find("#about-fixture-action").click
    assert_equal true, page.evaluate_script("window.aboutActionClicked")
    find("#about-fixture-input").fill_in(with: "Example value")
    assert_selector "#{details_selector}[open]"
  end

  test "dragging and selecting About detail text keeps the card open" do
    visit about_path
    find("#cves > summary").click
    card = find("#cves .profile-card[data-disclosure-bound='true']", match: :first)
    card.find(".aboutme-card-title").click
    paragraph = card.find(".aboutme-card-body p", match: :first)
    coordinates = page.evaluate_script(<<~JS)
      (() => {
        const paragraph = document.querySelector(#{("##{card['id']} .aboutme-card-body p").to_json});
        paragraph.scrollIntoView({ block: 'center' });
        const rect = paragraph.getBoundingClientRect();
        return { x: rect.left + 4, y: rect.top + parseFloat(getComputedStyle(paragraph).lineHeight) / 2 };
      })()
    JS
    page.driver.browser.execute_cdp("Input.dispatchMouseEvent", type: "mousePressed", x: coordinates["x"], y: coordinates["y"], button: "left", clickCount: 1)
    page.driver.browser.execute_cdp("Input.dispatchMouseEvent", type: "mouseMoved", x: coordinates["x"] + 110, y: coordinates["y"], button: "left", buttons: 1)
    page.driver.browser.execute_cdp("Input.dispatchMouseEvent", type: "mouseReleased", x: coordinates["x"] + 110, y: coordinates["y"], button: "left", clickCount: 1)
    assert_not_empty page.evaluate_script("window.getSelection().toString()")
    assert_selector "##{card['id']} > .profile-card-details[open]"
    page.execute_script("document.querySelector(#{("##{card['id']} .aboutme-card-body p").to_json}).click()")
    assert_selector "##{card['id']} > .profile-card-details[open]"
    page.execute_script("window.getSelection().removeAllRanges()")
    paragraph.click
    assert_no_selector "##{card['id']} > .profile-card-details[open]"
  end

  test "nested About cards and details do not toggle their parent" do
    visit about_path
    find("#cves > summary").click
    card = find("#cves .profile-card[data-disclosure-bound='true']", match: :first)
    card.find(".aboutme-card-title").click
    parent_selector = "##{card['id']} > .profile-card-details"
    page.execute_script(<<~JS)
      const body = document.querySelector(#{parent_selector.to_json}).querySelector('.aboutme-card-body');
      body.insertAdjacentHTML('afterbegin', '<article id="about-child-fixture" class="profile-card" data-card-disclosure><h4>Child card</h4><details class="profile-card-details"><summary>Child details</summary><p>Child body</p></details></article><details id="about-nested-details"><summary>Nested details</summary><p>Nested body</p></details>');
      document.dispatchEvent(new Event('turbo:load'));
      document.dispatchEvent(new Event('turbo:load'));
    JS
    find("#about-child-fixture h4").click
    assert_selector "#about-child-fixture > details[open]"
    assert_selector "#{parent_selector}[open]"
    find("#about-child-fixture p").click
    assert_no_selector "#about-child-fixture > details[open]"
    assert_selector "#{parent_selector}[open]"
    find("#about-nested-details summary").click
    find("#about-nested-details p").click
    assert_selector "#about-nested-details[open]"
    assert_selector "#{parent_selector}[open]"
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
    assert_no_selector "#certificates[open]"
    page.execute_script("window.location.hash = '#certificates'")

    assert_selector "#certificates[open]"
    assert_equal true, page.evaluate_script("document.querySelector('#certificates').open")

    visit about_path(anchor: event.fetch("id"))

    assert_selector "#achievements[open]"
    assert_selector "##{achievement.fetch('id')} > .profile-card-details[open]"
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
            cardOpen: card.querySelector(".profile-card-details").open,
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

  test "my challenges link to their writeups" do
    challenge, writeup_tag, post = authored_challenge_writeup_case

    visit about_path
    page.execute_script(<<~JS)
      document.querySelector("#my-challenges").open = true;
      document.getElementById(#{challenge.fetch("id").to_json}).querySelector(".profile-card-details").open = true;
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
      document.querySelectorAll("#achievements .aboutme-achievement-card").forEach((card) => { card.querySelector(".profile-card-details").open = true; });
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
      document.querySelectorAll("#achievements .aboutme-achievement-card").forEach((card) => { card.querySelector(".profile-card-details").open = true; });
    JS

    first_cve_title = page.evaluate_script(<<~JS)
      document.querySelector("#cves .aboutme-finding-card .aboutme-finding-summary").innerText.trim()
    JS
    achievement_titles = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#achievements .aboutme-achievement-card > .aboutme-card-header h3"))
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
end
