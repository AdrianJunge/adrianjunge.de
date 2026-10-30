require "test_helper"

class ContentIndexTest < ActiveSupport::TestCase
  setup do
    @repository = fixture_content_repository
    @items = ContentIndex.new(repository: @repository).all_items
  end

  test "CVE severity remains independent from challenge difficulty" do
    cve = @items.find { |item| item[:kind] == "cve" }
    assert_includes cve[:tags], "severity:high"
    assert_not_includes cve[:tags], "difficulty:high"
    assert @items.any? { |item| item[:tags].include?("difficulty:medium") }
  end

  test "search indexes visible metadata without copying article bodies" do
    @repository.blog_posts.each do |post|
      item = @items.find { |entry| entry[:id] == "blog-#{post[:slug]}" }
      next unless item

      assert_includes item[:search_text], post[:title].downcase
      assert_nil item[:search_parts]
      assert_operator item[:search_text].bytesize, :<, 2_000
    end
  end

  test "production timeline contains every public content source" do
    repository = production_content_repository
    items = ContentIndex.new(repository: repository).all_items
    expected_ids = timeline_expected_source_ids(repository)
    actual_ids = timeline_source_ids(items)

    assert_equal expected_ids.sort, actual_ids.sort
    assert_equal expected_ids.uniq.length, actual_ids.length
    assert_equal items.map { |item| item[:id] }.uniq.length, items.length

    expected_counts = timeline_expected_source_counts(repository)
    actual_counts = actual_ids.group_by { |id| timeline_source_kind(id) }.transform_values(&:length)

    expected_counts.each do |kind, count|
      assert_equal count, actual_counts.fetch(kind, 0), "Expected #{count} #{kind} timeline sources"
    end
    assert_equal expected_counts.select { |_kind, count| count.positive? }.keys.sort, actual_counts.keys.sort
  end

  test "timeline groups merge related about and post sources" do
    ids = @items.map { |item| item[:id] }
    item = @items.find { |candidate| candidate[:id] == "blog-alpha-post" }

    assert item
    assert_not_includes ids, "about-certificate-fixture-certificate"
    assert_equal [ "blog-alpha-post", "about-certificate-fixture-certificate" ], item[:merged_item_ids]
    assert_equal "/blog/alpha-post", item[:link]
    assert_equal "blog", item[:kind]
    assert_includes item[:kind_labels], { label: "Blog post", tag_value: "Blog post" }
    assert_includes item[:kind_labels], { label: "Certificate", tag_value: "Certificate" }
    assert_includes item[:tags], "Certificate"
    assert_includes item[:search_text], "fixture certificate"
    assert_equal Time.zone.local(2025, 2, 3), item[:published]
    assert_equal "3 Feb 2025", item[:display_date]
  end

  test "authored challenge timeline entries merge into their writeups" do
    ids = @items.map { |item| item[:id] }
    about_challenge_id = "about-challenge-space-writeup"
    item = @items.find { |candidate| Array(candidate[:merged_item_ids]).include?(about_challenge_id) }

    assert_not_includes ids, about_challenge_id
    assert item
    assert_equal "writeup", item[:kind]
    assert_equal "/ctf/democtf/Space%20Writeup", item[:link]
    assert_includes item[:kind_labels], { label: "CTF writeup", tag_value: "CTF writeup" }
    assert_not_includes item[:kind_labels], { label: "Created CTF challenge", tag_value: AuthoredChallenge::FILTER_LABEL }
    assert_includes item[:tags], AuthoredChallenge::FILTER_LABEL
    assert_includes item[:search_text], "authored challenge"
  end

  test "timeline side labels are exactly the content type tags" do
    @items.each do |item|
      expected_labels = item[:tags]
        .select { |tag| ContentTagTaxonomy.content_type?(tag) }
        .map { |tag| { label: tag, tag_value: tag } }

      assert_equal expected_labels, item[:kind_labels], "Unexpected side labels for #{item[:id]}"
    end
  end

  test "event tags replace parent classifications only when explicitly supplied" do
    entries = [ {
      "id" => "platform", "title" => "Platform", "tags" => [ "Bug bounty", "Web" ],
      "timeline" => [
        { "id" => "inherited", "title" => "Bounty", "date" => "2026-01-01" },
        { "id" => "overridden", "title" => "Audit", "date" => "2026-02-01", "tags" => [ "Audit Competition" ] },
        { "id" => "cleared", "title" => "Other activity", "date" => "2026-03-01", "tags" => [] }
      ]
    } ]
    original = @repository.method(:about_entries)
    @repository.define_singleton_method(:about_entries) do |path|
      path == ApplicationController::ABOUTME_ACHIEVEMENTS_PATH ? entries : original.call(path)
    end
    items = ContentIndex.new(repository: @repository).all_items.index_by { |item| item[:id] }

    assert_includes items.fetch("about-achievement-inherited")[:tags], "Bug bounty"
    assert_equal [ "Achievement", "Audit Competition", "Platform" ], items.fetch("about-achievement-overridden")[:tags]
    assert_equal [ "Achievement", "Platform" ], items.fetch("about-achievement-cleared")[:tags]
    assert_equal [ "Bug bounty", "Web" ], entries.first["tags"]
  end

  test "Firedancer audit is classified without the parent platform bounty references" do
    item = ContentIndex.new(repository: production_content_repository).all_items.find { |entry| entry[:id] == "about-achievement-firedancer-v1-audit-competition" }

    assert_equal [ "Achievement", "Audit Competition", "Immunefi" ], item[:tags]
    assert_not_includes item[:search_text], "bug bounty"
  end

  test "timeline excludes hidden fixture entries and includes every fixture post" do
    ids = timeline_source_ids(@items)

    assert_not_includes ids, "about-achievement-fixture-result-hidden"
    assert_not_includes ids, "timeline-event-fixture-timeline-hidden"
    assert_not_includes ids, "ctf-democtf-hidden"
    @repository.blog_posts.each { |post| assert_includes ids, "blog-#{post[:slug]}" }
    @repository.ctf_posts.each do |post|
      assert_includes ids, "ctf-#{post[:directory].parameterize}-#{post[:slug].parameterize}"
    end
  end

  test "standalone events appear only in the timeline index and support static cards" do
    item = @items.find { |candidate| candidate[:id] == "timeline-event-fixture-timeline-only" }

    assert item
    assert_equal "timeline_event", item[:kind]
    assert_nil item[:label]
    assert_empty item[:kind_labels]
    assert_not_includes item[:tags], "Milestone"
    assert_equal "Timeline Only Milestone", item[:title]
    assert_equal "1 Sep 2025", item[:display_date]
    assert_nil item[:link]
    assert_includes item[:tags], "Fixture Timeline"
    assert_includes item[:search_text], "uniquetimelineword"
  end

  test "standalone event side labels retain their explicitly authored content types" do
    events = [
      { "id" => "practice", "title" => "Practice", "date" => "2023", "tags" => [ "Beginnings", "Algorithms", "CTF Competition" ] }
    ]
    @repository.define_singleton_method(:timeline_events) { events }
    item = ContentIndex.new(repository: @repository).all_items.find { |entry| entry[:id] == "timeline-event-practice" }

    assert_equal [ "Beginnings", "Algorithms", "CTF Competition" ], item[:tags]
    assert_equal [
      { label: "Algorithms", tag_value: "Algorithms" },
      { label: "CTF Competition", tag_value: "CTF Competition" }
    ], item[:kind_labels]
    assert_equal "2023", item[:display_date]
  end

  test "every global timeline source uses the same exact date format" do
    expected_dates = {
      "ctf-democtf-space-writeup" => "3 Mar 2025",
      "blog-beta-post" => "2 Jan 2023",
      "about-cve-fixture-cve" => "1 Jun 2025",
      "blog-alpha-post" => "3 Feb 2025",
      "about-talk-fixture-talk-first" => "1 Jan 2025",
      "about-achievement-fixture-result-new" => "1 Aug 2025",
      "timeline-event-fixture-timeline-only" => "1 Sep 2025"
    }
    items = @items.index_by { |item| item[:id] }

    expected_dates.each do |id, expected_date|
      assert_equal expected_date, items.fetch(id)[:display_date], id
      assert_includes items.fetch(id)[:search_text], expected_date.downcase
    end
    assert_equal "2023-01-02", @repository.blog_posts.find { |post| post[:slug] == "beta-post" }[:metadata]["published"]
    assert_equal "2025-06-01", @repository.about_entries(ApplicationController::ABOUTME_CVES_PATH).first.dig("timeline", 0, "date")
  end

  test "global timeline uses source precision instead of generated sorting dates" do
    posts = @repository.blog_posts.deep_dup
    year_post = posts.find { |post| post[:slug] == "beta-post" }
    year_post[:metadata].delete("published")
    year_post[:metadata]["year"] = "2023"
    year_post[:published] = ContentDate.parse("2023")
    month_post = posts.find { |post| post[:slug] == "gamma-post" }
    month_post[:metadata]["published"] = "2024-02"
    month_post[:published] = ContentDate.parse("2024-02")
    @repository.define_singleton_method(:blog_posts) { posts }

    entries = ContentIndex::ABOUT_COLLECTIONS.to_h do |collection|
      [ collection[:path], @repository.about_entries(collection[:path]).deep_dup ]
    end
    entries.fetch(ApplicationController::ABOUTME_CVES_PATH).first["timeline"] = [
      { "date" => "2024-06-01", "title" => "Earlier disclosure" },
      { "date" => "2025", "title" => "Year of disclosure" }
    ]
    entries.fetch(ApplicationController::ABOUTME_CERTIFICATES_PATH).first["timeline"] = [
      { "date" => "2026-02", "title" => "Month of certification" }
    ]
    entries.fetch(ApplicationController::ABOUTME_TALKS_PATH).first["timeline"].first["date"] = "2023–2024"
    @repository.define_singleton_method(:about_entries) { |path| entries.fetch(path) }
    items = ContentIndex.new(repository: @repository).all_items.index_by { |item| item[:id] }

    assert_equal "2023", items.fetch("blog-beta-post")[:display_date]
    assert_equal "Feb 2024", items.fetch("blog-gamma-post")[:display_date]
    assert_equal "2025", items.fetch("about-cve-fixture-cve")[:display_date]
    assert_equal "Feb 2026", items.fetch("blog-alpha-post")[:display_date]
    assert_equal "2023–2024", items.fetch("about-talk-fixture-talk-first")[:display_date]
    assert_equal Time.zone.local(2026, 2, 28), items.fetch("blog-alpha-post")[:published]
  end

  test "missing publication dates do not display the epoch sorting fallback" do
    posts = @repository.blog_posts.deep_dup
    post = posts.find { |entry| entry[:slug] == "beta-post" }
    post[:metadata].delete("published")
    post[:published] = ContentDate::EPOCH
    @repository.define_singleton_method(:blog_posts) { posts }
    item = ContentIndex.new(repository: @repository).all_items.find { |entry| entry[:id] == "blog-beta-post" }

    assert_equal "TBA", item[:display_date]
    assert_equal ContentDate::EPOCH, item[:published]
  end

  test "milestone periods filter across covered years while sorting by their start" do
    events = [
      { "id" => "practice", "title" => "Practice", "date" => "2023-10", "end_date" => "2025" },
      { "id" => "later-event", "title" => "Later event", "date" => "2024-02-29" }
    ]
    @repository.define_singleton_method(:timeline_events) { events }
    items = ContentIndex.new(repository: @repository).all_items
    milestones = items.select { |item| item[:kind] == "timeline_event" }
    assert_equal %w[timeline-event-later-event timeline-event-practice], milestones.pluck(:id)

    period = milestones.last
    assert_equal [ 2023, 2024, 2025 ], period[:filter_years]
    assert_equal Time.zone.local(2023, 10, 1), period[:published]
    assert_equal "2023-10", period[:date_datetime]
    assert_equal "Oct 2023–2025", period[:display_date]
    assert_includes period[:search_text], "oct 2023–2025"
    assert_equal [ 2024 ], milestones.first[:filter_years]
    items.reject { |item| item[:kind] == "timeline_event" }.each do |item|
      assert_equal [ item[:published].year ], item[:filter_years]
    end
  end

  test "talk index creates one item for every visible event" do
    talk_items = @items.select { |candidate| candidate[:kind] == "talk" }.index_by { |item| item[:id] }

    assert_equal %w[about-talk-fixture-talk-first about-talk-fixture-talk-latest], talk_items.keys.sort
    assert_not talk_items.key?("about-talk-fixture-talk-hidden")

    first_item = talk_items.fetch("about-talk-fixture-talk-first")
    latest_item = talk_items.fetch("about-talk-fixture-talk-latest")

    assert_equal "Talk", first_item[:label]
    assert_equal "First fixture talk.", first_item[:title]
    assert_equal "/about#fixture-talk-first", first_item[:link]
    assert_equal "1 Jan 2025", first_item[:display_date]
    assert_equal "Latest fixture talk.", latest_item[:title]
    assert_equal "/about#fixture-talk-latest", latest_item[:link]
    assert_equal "1 Jul 2025", latest_item[:display_date]

    talk_items.each_value do |item|
      assert_includes item[:tags], "Talk"
      assert_includes item[:tags], "Slides"
      assert_includes item[:tags], "Fixture Talk"
    end
  end

  test "blog source categories are indexed as content type tags" do
    research_item = @items.find { |candidate| candidate[:id] == "blog-alpha-post" }
    algorithm_item = @items.find { |candidate| candidate[:id] == "blog-beta-post" }

    assert_equal "blog", research_item[:kind]
    assert_equal "Security Research", research_item[:source]
    assert_includes research_item[:tags], "Blog post"
    assert_includes research_item[:tags], "Security Research"

    assert_equal "blog", algorithm_item[:kind]
    assert_equal "Algorithms", algorithm_item[:source]
    assert_includes algorithm_item[:kind_labels], { label: "Algorithms", tag_value: "Algorithms" }
    assert_includes algorithm_item[:tags], "Algorithms"
  end

  private

  def timeline_expected_source_ids(repository)
    ids = []
    ids.concat(repository.timeline_events.map { |event| "timeline-event-#{event.fetch('id')}" })
    ids.concat(repository.ctf_posts.map { |post| "ctf-#{post[:directory].parameterize}-#{post[:slug].parameterize}" })
    ids.concat(repository.blog_posts.map { |post| "blog-#{post[:slug].parameterize}" })
    ids.concat(about_entry_ids(repository, "cve", ApplicationController::ABOUTME_CVES_PATH))
    ids.concat(repository.authored_challenges.map { |entry| about_id("challenge", entry) })
    ids.concat(about_entry_ids(repository, "certificate", ApplicationController::ABOUTME_CERTIFICATES_PATH))
    ids.concat(about_timeline_event_ids(repository, "talk", ApplicationController::ABOUTME_TALKS_PATH))
    ids.concat(about_timeline_event_ids(repository, "achievement", ApplicationController::ABOUTME_ACHIEVEMENTS_PATH))
    ids
  end

  def timeline_expected_source_counts(repository)
    {
      "timeline_event" => repository.timeline_events.length,
      "writeup" => repository.ctf_posts.length,
      "blog" => repository.blog_posts.length,
      "cve" => repository.about_entries(ApplicationController::ABOUTME_CVES_PATH).length,
      "challenge" => repository.authored_challenges.length,
      "certificate" => repository.about_entries(ApplicationController::ABOUTME_CERTIFICATES_PATH).length,
      "talk" => about_timeline_event_ids(repository, "talk", ApplicationController::ABOUTME_TALKS_PATH).length,
      "achievement" => about_timeline_event_ids(repository, "achievement", ApplicationController::ABOUTME_ACHIEVEMENTS_PATH).length
    }
  end

  def about_entry_ids(repository, kind, path)
    repository.about_entries(path).map { |entry| about_id(kind, entry) }
  end

  def about_id(kind, entry)
    id = entry["id"].presence || entry["title"].to_s.parameterize
    "about-#{kind}-#{id.parameterize}"
  end

  def about_timeline_event_ids(repository, kind, path)
    repository.about_entries(path).flat_map do |entry|
      parent_id = entry["id"].presence || entry["title"].to_s.parameterize
      events = Array(entry["timeline"]).select { |event| event.is_a?(Hash) && event["title"].present? }

      if events.empty?
        [ "about-#{kind}-#{parent_id.parameterize}" ]
      else
        events.map do |event|
          event_id = event["id"].presence || "#{parent_id}-#{event["date"]}-#{event["title"]}".parameterize
          "about-#{kind}-#{event_id.parameterize}"
        end
      end
    end
  end

  def timeline_source_ids(items)
    items.flat_map do |item|
      merged_ids = Array(item[:merged_item_ids])
      merged_ids.presence || [ item[:id] ]
    end
  end

  def timeline_source_kind(id)
    case id
    when /\Atimeline-event-/
      "timeline_event"
    when /\Actf-/
      "writeup"
    when /\Ablog-/
      "blog"
    when /\Aabout-(achievement|certificate|challenge|cve|talk)-/
      Regexp.last_match(1)
    else
      flunk("unexpected timeline source id #{id.inspect}")
    end
  end
end
