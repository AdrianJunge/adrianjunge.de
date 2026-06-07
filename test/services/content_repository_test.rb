require "test_helper"

class ContentRepositoryTest < ActiveSupport::TestCase
  test "post metadata includes reading time from markdown body" do
    repository = ContentRepository.new
    markdown = <<~MARKDOWN
      ---
      title: Tiny Post
      ---

      #{Array.new(226, "word").join(" ")}
    MARKDOWN

    metadata = repository.post_metadata_from(repository.parse_markdown(markdown))

    assert_equal 226, metadata["word_count"]
    assert_equal "226 words", metadata["word_count_label"]
    assert_equal 2, metadata["reading_time_minutes"]
    assert_equal "2 min read", metadata["reading_time_label"]
  end

  test "repository attaches reading time to blog posts and ctf posts" do
    repository = ContentRepository.new

    assert repository.blog_posts.all? { |post| post[:reading_time_label].present? }
    assert repository.ctf_posts.all? { |post| post[:reading_time_label].present? }
    assert repository.blog_posts.all? { |post| post[:word_count].positive? }
    assert repository.ctf_posts.all? { |post| post[:word_count].positive? }
    assert_operator repository.total_post_reading_time_minutes, :>, 0
    assert_match(/\A\d+ min read\z/, repository.format_reading_time(repository.total_post_reading_time_minutes))
  end

  test "authored challenges are derived from ctf markdown metadata" do
    repository = ContentRepository.new
    challenges = repository.authored_challenges

    assert_equal [ "scanwich-station", "smile-at-me" ], challenges.map { |entry| entry["id"] }
    assert_equal "GPNCTF 2026", challenges.first["category"]
    assert_equal "/ctf/gpnctf/Scanwich%20Station", challenges.first["card_url"]
    assert_equal "https://gpn24.ctf.kitctf.de/", challenges.first["category_url"]
    assert_equal [
      {
        "label" => "Hard",
        "class_name" => "aboutme-difficulty-tag aboutme-difficulty-tag-hard"
      }
    ], challenges.first["tags"]
    assert_includes challenges.first["summary"], "Published for GPNCTF 2026"
    assert_equal "GPNCTF 2025", challenges.second["category"]
    assert_equal "/ctf/gpnctf/Smile%20at%20me", challenges.second["card_url"]
    assert_equal [
      {
        "label" => "Hard",
        "class_name" => "aboutme-difficulty-tag aboutme-difficulty-tag-hard"
      }
    ], challenges.second["tags"]
  end

  test "metadata tags include optional filters and declared difficulties by shared priority" do
    repository = ContentRepository.new
    metadata = {
      "categories" => [ "web" ],
      "difficulty" => "Hard",
      "optional" => {
        "authored_challenge" => true
      }
    }

    assert_equal [ AuthoredChallenge::FILTER_LABEL, "Hard", "web" ], repository.metadata_tags(metadata)
    assert_equal [ AuthoredChallenge::FILTER_LABEL, "web" ], repository.metadata_tags(metadata, include_difficulty: false)
    assert_equal [ "web" ], repository.metadata_tags("categories" => [ "web" ])
  end

  test "ctf event year is separate from published year" do
    repository = ContentRepository.new

    metadata = {
      "ctf_year" => "2025",
      "published" => "2026-01-02"
    }

    assert_equal 2026, repository.metadata_year(metadata)
    assert_equal "2025", repository.ctf_event_year(metadata)
    assert_equal "2024", repository.ctf_event_year("year" => "2024", "published" => "2026-01-02")
  end

  test "generic feed posts merge configured content sources" do
    repository = ContentRepository.new
    items = repository.feed_posts

    assert items.any? { |item| item[:source_key] == "blog" && item[:link].start_with?("/blog/") }
    assert items.any? { |item| item[:source_key] == "ctf" && item[:link].start_with?("/ctf/") }
    assert_equal items.sort_by { |item| -item[:published].to_i }.map { |item| item[:guid] }, items.map { |item| item[:guid] }
  end

  test "hidden and draft content stays out of public collections" do
    repository = ContentRepository.new

    assert_empty repository.about_entries(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH)
    assert_not repository.about_entries(ApplicationController::ABOUTME_CVES_PATH).any? { |entry| entry["id"].include?("suitecrm-tba") }
    assert_not repository.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH).any? { |entry| entry["id"] == "firedancer-v1-audit-competition" }
    assert_not repository.blog_posts.any? { |post| post[:slug] == "frankendancer-net-shred-overrun" }
    assert_not repository.feed_posts.any? { |post| post[:guid] == "/blog/frankendancer-net-shred-overrun" }

    hidden_cves = repository.about_entries(ApplicationController::ABOUTME_CVES_PATH, include_hidden: true)
    assert hidden_cves.any? { |entry| entry["id"] == "suitecrm-tba-1" && entry["hidden"] }
  end
end
