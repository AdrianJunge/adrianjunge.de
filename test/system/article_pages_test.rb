require "application_system_test_case"
require_relative "../support/site_page_helpers"

class ArticlePagesTest < ApplicationSystemTestCase
  include SitePageHelpers

  test "articles keep one progress meter at the bottom of their responsive contents panel" do
    [ first_blog_post[:link], first_ctf_post[:link] ].each do |path|
      [ 320, 390, 768, 1024, 1400, 1440 ].each do |width|
        page.current_window.resize_to(width, 1200)
        visit path
        assert_selector ".post-meta-line", text: /min read/
        assert_selector "#toc > .article-progress[data-word-total][role='meter']", count: 1
        assert_selector "[data-article-progress]", count: 1, visible: :all
        assert_no_selector ".writeup-container [data-article-progress]", visible: :all
        assert_selector ".article-progress-percent", text: /\d+%/
        metrics = page.evaluate_script(<<~JS)
          (() => {
            const wrapper = document.querySelector('.writeup-wrapper').getBoundingClientRect();
            const toc = document.getElementById('toc');
            return {
              left: wrapper.left,
              right: document.documentElement.clientWidth - wrapper.right,
              overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
              progressIsLast: toc.lastElementChild.matches('[data-article-progress]'),
              duplicateIds: [...document.querySelectorAll('[id]')].map(node => node.id).filter((id, index, ids) => ids.indexOf(id) !== index)
            };
          })()
        JS
        assert_in_delta metrics["left"], metrics["right"], 2, "#{path} at #{width}px should center article and TOC together"
        assert_equal false, metrics["overflow"], "#{path} at #{width}px must not overflow horizontally"
        assert_equal true, metrics["progressIsLast"]
        assert_empty metrics["duplicateIds"]
        if width <= 1400
          assert_selector "#toc"
          assert_selector "#toc > .article-back-link", text: "Back to overview"
          assert_no_selector ".back-button-floating"
          assert_no_selector ".article-toc-compact[open]"
          find(".article-toc-compact > summary").click
          assert_selector ".article-toc-compact[open] .toc-anchor", minimum: 1
        else
          assert_selector "#toc"
          assert_no_selector ".article-back-link"
          assert_selector ".back-button-floating.article-back-desktop"
          find("#toc-toggle").click
          assert_selector "#toc[hidden]", visible: :all
          assert_no_selector ".article-progress"
          assert_equal true, page.evaluate_script("document.activeElement.matches('.writeup-toc-restore-button')")
          find(".writeup-toc-restore-button").click
          assert_selector "#toc > .article-progress"
          assert_equal "toc-toggle", page.evaluate_script("document.activeElement.id")
        end
      end
    end
  end

  test "contents links scroll independently while progress remains visible during reading" do
    [ "/blog/java-strings", ctf_post_with_headings[:link] ].each do |path|
      [ 320, 768, 1440 ].each do |width|
        page.current_window.resize_to(width, 800)
        visit path
        assert_selector "#toc > [data-article-progress]"
        page.execute_script("window.scrollTo(0, Math.min(1200, (document.documentElement.scrollHeight - innerHeight) / 2))")
        find(".article-toc-compact > summary").click if width <= 1400
        metrics = page.evaluate_script(<<~JS)
          new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(() => {
            const toc = document.getElementById('toc');
            const links = document.getElementById('toc-body');
            const progress = toc.querySelector('[data-article-progress]');
            const panel = toc.getBoundingClientRect();
            const meter = progress.getBoundingClientRect();
            const summary = toc.querySelector('summary');
            const summaryRect = summary.getBoundingClientRect();
            const back = summaryRect.width ? toc.querySelector('.article-back-link') : document.querySelector('.back-button-floating');
            const backRect = back?.getBoundingClientRect();
            const overlapsBack = backRect && backRect.width > 0 && summaryRect.width > 0 &&
              summaryRect.left < backRect.right && summaryRect.right > backRect.left &&
              summaryRect.top < backRect.bottom && summaryRect.bottom > backRect.top;
            links.scrollTop = links.scrollHeight;
            resolve({
              position: getComputedStyle(toc).position,
              top: panel.top,
              bottom: panel.bottom,
              taskbarBottom: document.getElementById('top-taskbar').getBoundingClientRect().bottom,
              viewportHeight: innerHeight,
              meterTop: meter.top,
              meterBottom: meter.bottom,
              linksBottom: links.getBoundingClientRect().bottom,
              scrollableLinks: getComputedStyle(links).overflowY,
              percent: Number(progress.getAttribute('aria-valuenow')),
              overlapsBack: Boolean(overlapsBack),
              backPosition: getComputedStyle(back).position,
              backInsideToc: back.parentElement === toc,
              backBottom: backRect.bottom,
              summaryTop: summaryRect.top,
              summaryHit: !summaryRect.width || Boolean(document.elementFromPoint(summaryRect.left + summaryRect.width / 2, summaryRect.top + summaryRect.height / 2)?.closest('summary') === summary),
              scrollY
            });
          })))
        JS
        assert_equal "sticky", metrics["position"]
        assert_operator metrics["scrollY"], :>, 100
        assert_operator metrics["top"], :>=, metrics["taskbarBottom"] - 1
        assert_operator metrics["bottom"], :<=, metrics["viewportHeight"] - 8
        assert_operator metrics["meterTop"], :>=, metrics["linksBottom"]
        assert_operator metrics["meterBottom"], :<=, metrics["bottom"]
        assert_equal "auto", metrics["scrollableLinks"]
        assert_equal false, metrics["overlapsBack"], "Back navigation and the TOC disclosure must have separate rows"
        assert_equal true, metrics["summaryHit"], "the TOC summary must remain directly clickable"
        if width <= 1400
          assert_equal "static", metrics["backPosition"], "compact Back navigation must participate in normal layout"
          assert_equal true, metrics["backInsideToc"]
          assert_operator metrics["backBottom"], :<=, metrics["summaryTop"] + 1
        end
        assert_operator metrics["percent"], :>, 0
        assert_operator metrics["percent"], :<=, 100
      end
    end
  end

  test "compact contents close on navigation and escape without losing keyboard focus" do
    page.current_window.resize_to(390, 800)
    visit "/blog/java-strings"
    summary = find(".article-toc-compact > summary")
    summary.click
    find("#toc-body .toc-anchor", match: :first).send_keys(:escape)
    assert_no_selector ".article-toc-compact[open]"
    assert_equal true, page.evaluate_script("document.activeElement.matches('.article-toc-compact > summary')")

    summary.click
    links = all("#toc-body .toc-anchor")
    links[links.length / 2].click
    assert_no_selector ".article-toc-compact[open]"
    assert_selector "#toc > [data-article-progress]"
    assert_equal true, page.evaluate_script("document.activeElement.matches('.markdown-content :is(h1,h2,h3,h4,h5,h6)')")
    assert_compact_anchor_clears_contents
  end

  test "compact article back navigation opens its overview without toggling contents" do
    [ "/blog/java-strings", first_ctf_post[:link] ].each do |path|
      page.current_window.resize_to(320, 800)
      visit path
      assert_no_selector ".back-button-floating"
      back = find("#toc > .article-back-link")
      assert_equal File.dirname(path), URI.parse(back[:href]).path
      assert_no_selector ".article-toc-compact[open]"
      back.send_keys(:return)
      assert_current_path File.dirname(path)
    end
  end

  test "native contents work without JavaScript on narrow and wide screens" do
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
    [ 390, 1440 ].each do |width|
      page.current_window.resize_to(width, 900)
      visit "/blog/java-strings"
      assert_no_selector "#toc[data-toc-enhanced]", visible: :all
      assert_no_selector ".article-toc-compact[open]"
      assert_selector "#toc > [data-article-progress]", count: 1
      assert_no_selector "#toc-toggle"
      if width <= 1400
        assert_selector "#toc > .article-back-link"
        assert_no_selector ".back-button-floating"
      end
      find(".article-toc-compact > summary").click
      assert_selector ".article-toc-compact[open] .toc-anchor", minimum: 1
      link = find("#toc-body .toc-anchor", match: :first)
      anchor = link[:href].split("#", 2).last
      link.click
      assert_equal anchor, URI.parse(page.current_url).fragment
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
  end

  test "compact enhancement does not move the server rendered article" do
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
    page.current_window.resize_to(390, 900)
    visit "/blog/java-strings"
    assert_no_selector ".article-toc-compact[open]"
    before = page.evaluate_script("document.querySelector('.writeup-container').getBoundingClientRect().top")
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
    # Run the unchanged initializer after resuming scripts, independently of
    # browser behavior for module loads attempted while scripts were disabled.
    page.execute_script(File.read(Rails.root.join("app/javascript/blog.js")))
    assert_selector "#toc[data-toc-enhanced]"
    assert_no_selector ".article-toc-compact[open]"
    after = page.evaluate_script("document.querySelector('.writeup-container').getBoundingClientRect().top")
    assert_in_delta before, after, 1, "initial enhancement must not collapse server-rendered space above the article"
  ensure
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
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
    post = ctf_post_with_challenge_stats
    stats_label = challenge_stats_label(post[:metadata])
    event_url = writeup_event_url_for(post)
    event_year = repository.ctf_event_year(post[:metadata])

    visit "/ctf/#{post[:directory]}"

    within find(".writeup-post-card", text: post[:title]) do
      assert_selector ".blog-post-challenge-stats", text: stats_label
      assert_match(/min read\s*·\s*#{Regexp.escape(stats_label)}/, find(".blog-post-date").text.squish)
    end

    visit post[:link]

    assert_selector ".post-meta-line", text: /#{Regexp.escape(stats_label)}/
    assert_match(/min read\s*·\s*#{Regexp.escape(stats_label)}/, find(".post-meta-line").text.squish)
    assert_selector ".writeup-year-link[href='#{event_url}'][target='_blank'][rel='noopener noreferrer']",
                    text: /#{Regexp.escape(post[:which].upcase)}-#{Regexp.escape(event_year.to_s)}/
  end

  test "ctf markdown preserves anchors and external links while resolving local images" do
    post = ctf_post_with_anchor_external_link_and_image

    visit post[:link]

    assert_text post[:title]
    assert_selector ".markdown-content a[href^='#']"
    assert_selector ".markdown-content a[href^='http']"
    assert_selector ".markdown-content img[src*='/ctf/writeups/']"
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

  test "article previous and next navigation stays within its content type" do
    fixture_repository = fixture_content_repository
    blog_case = adjacent_post_case(fixture_repository.blog_posts)
    ctf_case = adjacent_post_case(fixture_repository.ctf_posts)

    with_stubbed_content_repository(fixture_repository) do
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

    open_more_filters

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
    open_more_filters
    assert_selector ".writeup-winner-article .writeup-winner-badge[href='#{first_winner_badge[:proof_url]}']", text: first_winner_badge[:label]
    assert_selector ".writeup-recognition-badges-article .writeup-winner-badge .content-tag-arrow", text: ">"

    page.current_window.resize_to(320, 900)
    visit first_winner[:link]
    open_more_filters
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
      open_more_filters
      assert_selector ".writeup-winner-article .writeup-winner-badge[href='#{external_badge[:proof_url]}']", text: external_badge[:label]
    end
  end

  test "authored writeups filter on overview cards and link event badges on articles" do
    post = authored_writeup_with_event_url
    event_url = writeup_event_url_for(post)
    difficulty = WriteupDifficulty.from_metadata(post[:metadata])

    visit "/ctf/#{post[:directory]}"

    within find(".blog-post-card", text: post[:title]) do
      assert_selector ".blog-post-meta-row > button.authored-challenge-badge[data-filter-tag='Authored challenge']", text: /Authored challenge/
      assert_selector ".blog-post-meta-row > .difficulty-badge.difficulty-badge-#{difficulty[:key]}", text: difficulty[:label]
      assert_no_selector ".blog-post-meta-row > a.authored-challenge-badge"
      assert_no_selector ".authored-challenge-icon"
    end

    visit post[:link]
    assert_selector ".writeup-badges-article .difficulty-badge-#{difficulty[:key]}", text: difficulty[:label]
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
    assert_equal "pre", metrics["whiteSpace"]
    assert_equal "normal", metrics["overflowWrap"]
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
      assert_selector ".markdown-content h2", text: heading_text

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const heading = [...document.querySelectorAll(".markdown-content h2")]
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

  def assert_compact_anchor_clears_contents
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    gap = nil
    loop do
      gap = page.evaluate_script(<<~JS)
        document.activeElement.getBoundingClientRect().top - document.getElementById('toc').getBoundingClientRect().bottom
      JS
      break if gap.between?(8, 32) || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end
    assert_operator gap, :>=, 8
    assert_operator gap, :<=, 32
  end
end
