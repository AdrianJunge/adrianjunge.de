module SitePageHelpers
  private

  def open_more_filters
    all(".content-filter-more:not([open])").each { |details| details.find("summary").click }
  end

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

  def timeline_content_type_tags
    timeline_items.flat_map do |item|
      Array(item[:kind_labels]).map { |kind_label| kind_label[:tag_value].presence || kind_label[:label] }
    end.uniq
  end

  def timeline_repository_tags
    repository_labels = [
      ApplicationController::ABOUTME_CVES_PATH,
      ApplicationController::ABOUTME_BUG_BOUNTIES_PATH
    ].flat_map do |path|
      repository.about_entries(path).filter_map { |entry| entry["title"].presence }
    end

    ContentTagTaxonomy.canonical_values(timeline_items.flat_map { |item| item[:tags] }).select do |tag|
      repository_labels.any? { |label| label.casecmp?(tag) }
    end
  end

  def first_blog_post
    blog_posts.first || flunk("expected at least one blog post")
  end

  def first_ctf_post
    ctf_posts.first || flunk("expected at least one CTF writeup")
  end

  def adjacent_post_case(posts)
    assert_operator posts.length, :>=, 3, "the synthetic adjacency catalog must contain at least three posts"

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
    find("[data-filter-year='#{scope}']").select(year.to_s.presence || "All years")
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
    item[:search_text]
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
        groups[key] ||= { label: ContentTagTaxonomy.canonical_label(tag), key: WriteupDifficulty.css_key(tag), items: [] }
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
        groups[key] ||= { label: ContentTagTaxonomy.canonical_label(tag), key: ContentSeverityTag.css_key(tag), items: [] }
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

  def merged_timeline_item_with_source_prefix(prefix)
    timeline_items.find do |item|
      Array(item[:merged_item_ids]).any? { |source_id| source_id.start_with?(prefix) }
    end
  end

  def assert_merged_timeline_item_rendered(item)
    hitboxes = all(".timeline-card-hitbox", visible: :all).select do |hitbox|
      URI.parse(hitbox["href"]).path == item[:link]
    end
    assert_equal 1, hitboxes.length

    timeline_entry = hitboxes.first.find(
      :xpath,
      "./ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' timeline-item ')]"
    )
    expected_labels = Array(item[:kind_labels]).map { |kind_label| kind_label[:tag_value].presence || kind_label[:label] }

    within timeline_entry do
      rendered_labels = all(".timeline-date .timeline-kind-pill").map { |chip| chip["data-filter-tag"] }
      assert_equal expected_labels, rendered_labels
      assert_selector ".timeline-content .timeline-card-logo"
    end
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

  def ctf_post_with_challenge_stats
    ctf_posts.find do |post|
      challenge_stats_label(post[:metadata]).present? &&
        writeup_event_url_for(post).present? &&
        repository.ctf_event_year(post[:metadata]).present?
    end || flunk("expected a CTF writeup with challenge statistics")
  end

  def challenge_stats_label(metadata)
    solves = non_negative_metadata_number(
      metadata,
      "solves", "solve_count", "solves_count", "solve-count", "solves-count"
    )
    points = positive_metadata_number(
      metadata,
      "points", "point_count", "points_count", "challenge_points", "score"
    )
    solve_label = "#{solves} #{solves == 1 ? 'solve' : 'solves'}" unless solves.nil?
    points_label = "#{points} #{points == 1 ? 'point' : 'points'}" unless points.nil?

    [ solve_label, points_label ].compact.join(" / ").presence
  end

  def non_negative_metadata_number(metadata, *keys)
    raw = AuthoredChallenge.metadata_value(metadata, *keys).to_s.strip
    raw.match?(/\A\d+\z/) ? raw.to_i : nil
  end

  def positive_metadata_number(metadata, *keys)
    value = non_negative_metadata_number(metadata, *keys)
    value if value&.positive?
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
