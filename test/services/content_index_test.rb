require "test_helper"

class ContentIndexTest < ActiveSupport::TestCase
  setup do
    @repository = ContentRepository.new
    @items = ContentIndex.new(repository: @repository).all_items
  end

  test "timeline index contains every public content source" do
    expected_ids = []
    expected_ids.concat(@repository.ctf_posts.map { |post| "ctf-#{post[:directory].parameterize}-#{post[:slug].parameterize}" })
    expected_ids.concat(@repository.blog_posts.map { |post| "blog-#{post[:slug].parameterize}" })
    expected_ids.concat(about_entry_ids("cve", ApplicationController::ABOUTME_CVES_PATH))
    expected_ids.concat(about_entry_ids("bug-bounty", ApplicationController::ABOUTME_BUG_BOUNTIES_PATH))
    expected_ids.concat(@repository.authored_challenges.map { |entry| about_id("challenge", entry) })
    expected_ids.concat(about_entry_ids("certificate", ApplicationController::ABOUTME_CERTIFICATES_PATH))
    expected_ids.concat(about_entry_ids("talk", ApplicationController::ABOUTME_TALKS_PATH))
    expected_ids.concat(achievement_event_ids)

    assert_equal expected_ids.sort, @items.map { |item| item[:id] }.sort

    expected_counts = {
      "writeup" => @repository.ctf_posts.length,
      "blog" => @repository.blog_posts.length,
      "cve" => @repository.about_entries(ApplicationController::ABOUTME_CVES_PATH).length,
      "bug-bounty" => @repository.about_entries(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH).length,
      "challenge" => @repository.authored_challenges.length,
      "certificate" => @repository.about_entries(ApplicationController::ABOUTME_CERTIFICATES_PATH).length,
      "talk" => @repository.about_entries(ApplicationController::ABOUTME_TALKS_PATH).length,
      "achievement" => achievement_event_ids.length
    }
    actual_counts = @items.group_by { |item| item[:kind] }.transform_values(&:length)

    expected_counts.each do |kind, count|
      assert_equal count, actual_counts.fetch(kind, 0), "Expected #{count} #{kind} timeline items"
    end
    assert_equal expected_counts.select { |_kind, count| count.positive? }.keys.sort, actual_counts.keys.sort
  end

  test "timeline index excludes hidden and draft source entries" do
    ids = @items.map { |item| item[:id] }

    hidden_about_ids.each do |id|
      assert_not_includes ids, id
    end
    assert_not_includes ids, "blog-frankendancer-net-shred-overrun"
  end

  test "talks are indexed with the talk content type and slide tag" do
    item = @items.find { |candidate| candidate[:id] == "about-talk-kitctf-web-intro-2026" }

    assert item
    assert_equal "talk", item[:kind]
    assert_equal "Talk", item[:label]
    assert_equal "KITCTF Web Intro", item[:title]
    assert_equal "/about#kitctf-web-intro-2026", item[:link]
    assert_includes item[:tags], "Talk"
    assert_includes item[:tags], "Slides"
  end

  test "blog source categories are indexed as content type tags" do
    item = @items.find { |candidate| candidate[:id] == "blog-java-strings" }

    assert item
    assert_equal "blog", item[:kind]
    assert_equal "Security Research", item[:source]
    assert_includes item[:tags], "Blog post"
    assert_includes item[:tags], "Security Research"
  end

  private

  def about_entry_ids(kind, path)
    @repository.about_entries(path).map { |entry| about_id(kind, entry) }
  end

  def about_id(kind, entry)
    id = entry["id"].presence || entry["title"].to_s.parameterize
    "about-#{kind}-#{id.parameterize}"
  end

  def achievement_event_ids(entries = @repository.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH))
    entries.flat_map do |entry|
      parent_id = entry["id"].presence || entry["title"].to_s.parameterize
      events = Array(entry["events"]).select { |event| event.is_a?(Hash) && event["title"].present? }

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

  def hidden_about_ids
    hidden_ids = []
    hidden_ids.concat(hidden_entry_ids("cve", ApplicationController::ABOUTME_CVES_PATH))
    hidden_ids.concat(hidden_entry_ids("bug-bounty", ApplicationController::ABOUTME_BUG_BOUNTIES_PATH))
    hidden_ids.concat(hidden_entry_ids("certificate", ApplicationController::ABOUTME_CERTIFICATES_PATH))
    hidden_ids.concat(hidden_entry_ids("talk", ApplicationController::ABOUTME_TALKS_PATH))
    hidden_ids.concat(hidden_achievement_event_ids)
    hidden_ids
  end

  def hidden_entry_ids(kind, path)
    visible_ids = about_entry_ids(kind, path)

    @repository.about_entries(path, include_hidden: true)
      .map { |entry| about_id(kind, entry) }
      .reject { |id| visible_ids.include?(id) }
  end

  def hidden_achievement_event_ids
    visible_ids = achievement_event_ids

    achievement_event_ids(@repository.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH, include_hidden: true))
      .reject { |id| visible_ids.include?(id) }
  end
end
