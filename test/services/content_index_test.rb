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

    assert_equal expected_ids.sort, timeline_source_ids.sort

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
    actual_counts = timeline_source_ids.group_by { |id| timeline_source_kind(id) }.transform_values(&:length)

    expected_counts.each do |kind, count|
      assert_equal count, actual_counts.fetch(kind, 0), "Expected #{count} #{kind} timeline sources"
    end
    assert_equal expected_counts.select { |_kind, count| count.positive? }.keys.sort, actual_counts.keys.sort
    assert_empty @items.select { |item| item[:logo].blank? }.map { |item| item[:id] }
  end

  test "timeline groups merge related about and post sources" do
    ids = @items.map { |item| item[:id] }
    item = @items.find { |candidate| candidate[:id] == "blog-htb-cpts" }

    assert item
    assert_not_includes ids, "about-certificate-htb-cpts"
    assert_includes item[:merged_item_ids], "blog-htb-cpts"
    assert_includes item[:merged_item_ids], "about-certificate-htb-cpts"
    assert_equal "/blog/htb-cpts", item[:link]
    assert_equal "blog", item[:kind]
    assert_includes item[:kind_labels], { label: "Blog post", tag_value: "Blog post" }
    assert_includes item[:kind_labels], { label: "Certificate", tag_value: "Certificate" }
    assert_includes item[:tags], "Certificate"
    assert_includes item[:search_text], "hack the box certified penetration testing specialist"
  end

  test "authored challenge timeline entries merge into their writeups" do
    ids = @items.map { |item| item[:id] }

    @repository.authored_challenges.each do |entry|
      about_challenge_id = about_id("challenge", entry)
      item = @items.find { |candidate| Array(candidate[:merged_item_ids]).include?(about_challenge_id) }

      assert_not_includes ids, about_challenge_id
      assert item, "Expected #{about_challenge_id} to be represented by a merged writeup timeline item"
      assert_equal "writeup", item[:kind]
      writeup_url = entry.fetch("tags").find { |tag| tag.is_a?(Hash) && tag["label"] == "Writeup" }.fetch("url")
      assert_equal writeup_url, item[:link]
      assert_includes item[:kind_labels], { label: "CTF writeup", tag_value: "CTF writeup" }
      assert_not_includes item[:kind_labels], { label: "Created CTF challenge", tag_value: AuthoredChallenge::FILTER_LABEL }
      assert_includes item[:tags], AuthoredChallenge::FILTER_LABEL
      assert_not_includes item[:tags], "Created CTF challenges"
      assert_includes item[:search_text], "authored challenge"
    end
  end

  test "timeline side labels are exactly the content type tags" do
    @items.each do |item|
      expected_labels = item[:tags]
        .select { |tag| ContentTagTaxonomy.content_type?(tag) }
        .map { |tag| { label: tag, tag_value: tag } }

      assert_equal expected_labels, item[:kind_labels], "Unexpected side labels for #{item[:id]}"
    end
  end

  test "timeline index excludes hidden entries and includes catalogued blog posts" do
    ids = @items.map { |item| item[:id] }

    hidden_about_ids.each do |id|
      assert_not_includes ids, id
    end
    @repository.blog_posts.each do |post|
      assert_includes ids, "blog-#{post[:slug]}"
    end
  end

  test "talks are indexed with the talk content type and slide tag" do
    item = @items.find { |candidate| candidate[:id] == "about-talk-kitctf-web-intro" }

    assert item
    assert_equal "talk", item[:kind]
    assert_equal "Talk", item[:label]
    assert_equal "KITCTF Web Intro", item[:title]
    assert_equal "/about#kitctf-web-intro", item[:link]
    assert_equal "2026-05-07", item[:display_date]
    assert_includes item[:tags], "Talk"
    assert_includes item[:tags], "Slides"

    joomla_item = @items.find { |candidate| candidate[:id] == "about-talk-joomla-sqli" }
    assert joomla_item
    assert_equal "2026-08-11", joomla_item[:display_date]
    assert_includes joomla_item[:tags], "Slides"
  end

  test "blog source categories are indexed as content type tags" do
    item = @items.find { |candidate| candidate[:id] == "blog-java-strings" }

    assert item
    assert_equal "blog", item[:kind]
    assert_equal "Security Research", item[:source]
    assert_includes item[:tags], "Blog post"
    assert_includes item[:tags], "Security Research"

    algorithm_item = @items.find { |candidate| candidate[:id] == "blog-climbing-stairs" }

    assert algorithm_item
    assert_equal "blog", algorithm_item[:kind]
    assert_equal "Algorithms", algorithm_item[:source]
    assert_includes algorithm_item[:kind_labels], { label: "Algorithms", tag_value: "Algorithms" }
    assert_includes algorithm_item[:tags], "Algorithms"
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

  def timeline_source_ids
    @items.flat_map { |item| [ item[:id], *Array(item[:merged_item_ids]) ] }.uniq
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
