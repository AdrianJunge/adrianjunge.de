require "test_helper"

class ContentIndexTest < ActiveSupport::TestCase
  setup do
    @repository = fixture_content_repository
    @items = ContentIndex.new(repository: @repository).all_items
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

  test "timeline excludes hidden fixture entries and includes every fixture post" do
    ids = timeline_source_ids(@items)

    assert_not_includes ids, "about-achievement-fixture-result-hidden"
    assert_not_includes ids, "ctf-democtf-hidden"
    @repository.blog_posts.each { |post| assert_includes ids, "blog-#{post[:slug]}" }
    @repository.ctf_posts.each do |post|
      assert_includes ids, "ctf-#{post[:directory].parameterize}-#{post[:slug].parameterize}"
    end
  end

  test "talk index uses the newest visible event and declared tags" do
    item = @items.find { |candidate| candidate[:id] == "about-talk-fixture-talk" }

    assert item
    assert_equal "talk", item[:kind]
    assert_equal "Talk", item[:label]
    assert_equal "Fixture Talk", item[:title]
    assert_equal "/about#fixture-talk", item[:link]
    assert_equal "2025-07-01", item[:display_date]
    assert_includes item[:tags], "Talk"
    assert_includes item[:tags], "Slides"
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
    ids.concat(repository.ctf_posts.map { |post| "ctf-#{post[:directory].parameterize}-#{post[:slug].parameterize}" })
    ids.concat(repository.blog_posts.map { |post| "blog-#{post[:slug].parameterize}" })
    ids.concat(about_entry_ids(repository, "cve", ApplicationController::ABOUTME_CVES_PATH))
    ids.concat(about_entry_ids(repository, "bug-bounty", ApplicationController::ABOUTME_BUG_BOUNTIES_PATH))
    ids.concat(repository.authored_challenges.map { |entry| about_id("challenge", entry) })
    ids.concat(about_entry_ids(repository, "certificate", ApplicationController::ABOUTME_CERTIFICATES_PATH))
    ids.concat(about_entry_ids(repository, "talk", ApplicationController::ABOUTME_TALKS_PATH))
    ids.concat(achievement_event_ids(repository))
    ids
  end

  def timeline_expected_source_counts(repository)
    {
      "writeup" => repository.ctf_posts.length,
      "blog" => repository.blog_posts.length,
      "cve" => repository.about_entries(ApplicationController::ABOUTME_CVES_PATH).length,
      "bug-bounty" => repository.about_entries(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH).length,
      "challenge" => repository.authored_challenges.length,
      "certificate" => repository.about_entries(ApplicationController::ABOUTME_CERTIFICATES_PATH).length,
      "talk" => repository.about_entries(ApplicationController::ABOUTME_TALKS_PATH).length,
      "achievement" => achievement_event_ids(repository).length
    }
  end

  def about_entry_ids(repository, kind, path)
    repository.about_entries(path).map { |entry| about_id(kind, entry) }
  end

  def about_id(kind, entry)
    id = entry["id"].presence || entry["title"].to_s.parameterize
    "about-#{kind}-#{id.parameterize}"
  end

  def achievement_event_ids(repository)
    repository.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH).flat_map do |entry|
      parent_id = entry["id"].presence || entry["title"].to_s.parameterize
      events = Array(entry["timeline"]).select { |event| event.is_a?(Hash) && event["title"].present? }

      if events.empty?
        [ "about-achievement-#{parent_id.parameterize}" ]
      else
        events.map do |event|
          event_id = event["id"].presence || "#{parent_id}-#{event["date"]}-#{event["title"]}".parameterize
          "about-achievement-#{event_id.parameterize}"
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
    when /\Actf-/
      "writeup"
    when /\Ablog-/
      "blog"
    when /\Aabout-(bug-bounty|achievement|certificate|challenge|cve|talk)-/
      Regexp.last_match(1)
    else
      flunk("unexpected timeline source id #{id.inspect}")
    end
  end
end
