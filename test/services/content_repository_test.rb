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

    researched_values = {
      "Scanwich Station" => { "solves" => 5, "points" => 405, "event_url" => "https://gpn24.ctf.kitctf.de/" },
      "Smile at me" => { "solves" => 1, "points" => 500, "event_url" => "https://gpn23.ctf.kitctf.de/" },
      "Gamedev" => { "solves" => 108, "points" => 331, "event_url" => "https://platform.2025.lac.tf/" },
      "CORS Playground" => { "solves" => 20, "points" => 451, "event_url" => "https://hackropole.fr/fr/challenges/web/fcsc2024-web-cors-playground/" },
      "My Flask App" => { "solves" => 451, "points" => 100, "event_url" => "https://2025.ctf.sekai.team/" },
      "Fancy Web" => { "solves" => 0, "points" => 500, "event_url" => "https://2025.ctf.sekai.team/" },
      "Leaf" => { "solves" => 3, "points" => 469, "event_url" => "https://play.ctf.gg/" },
      "A Minecraft Movie" => { "solves" => 58 },
      "xmalloc" => { "solves" => 4, "points" => 500, "event_url" => "https://2022.ctf.kitctf.de/" }
    }

    researched_values.each do |title, expected_metadata|
      metadata = repository.ctf_posts.find { |post| post[:title] == title }[:metadata]
      expected_metadata.each do |key, expected_value|
        assert_equal expected_value, metadata[key], "expected #{title} #{key}"
      end
    end

    assert_operator repository.total_post_reading_time_minutes, :>, 0
    assert_match(/\A\d+ min read\z/, repository.format_reading_time(repository.total_post_reading_time_minutes))
  end

  test "authored challenges are read from compact about json" do
    repository = ContentRepository.new
    challenges = repository.authored_challenges
    raw_challenges = JSON.parse(File.read(ApplicationController::ABOUTME_CHALLENGES_PATH))
    scanwich = challenges.find { |entry| entry["id"] == "scanwich-station" }
    smile_at_me = challenges.find { |entry| entry["id"] == "smile-at-me" }

    assert_equal raw_challenges, challenges
    assert_equal [ "scanwich-station", "smile-at-me" ], challenges.map { |entry| entry["id"] }
    assert scanwich
    assert smile_at_me
    assert_equal "/ctf/gpnctf/Scanwich%20Station", scanwich["url"]
    assert_equal "https://gpn24.ctf.kitctf.de/", scanwich["tags"].first["url"]
    assert_includes scanwich["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "GPNCTF 2026"
    assert_includes scanwich["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Hard"
    assert_includes scanwich["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Web"
    assert_includes scanwich["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Pwn"
    assert_includes scanwich["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Writeup"
    assert_includes scanwich["summary"], "Published for GPNCTF 2026"
    assert_equal "/ctf/gpnctf/Smile%20at%20me", smile_at_me["url"]
    assert_includes smile_at_me["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "GPNCTF 2025"
    assert_includes smile_at_me["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Hard"
    assert_includes smile_at_me["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Web"
    assert_includes smile_at_me["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Writeup"
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

    assert_equal [ AuthoredChallenge::FILTER_LABEL, "Hard", "Web" ], repository.metadata_tags(metadata)
    assert_equal [ AuthoredChallenge::FILTER_LABEL, "Web" ], repository.metadata_tags(metadata, include_difficulty: false)
    assert_equal [ "Web" ], repository.metadata_tags("categories" => [ "web" ])
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

    assert_not repository.about_entries(ApplicationController::ABOUTME_CVES_PATH).any? { |entry| entry["id"].include?("suitecrm-tba") }
    assert_not repository.blog_posts.any? { |post| post[:slug] == "frankendancer-net-shred-overrun" }
    assert_not repository.feed_posts.any? { |post| post[:guid] == "/blog/frankendancer-net-shred-overrun" }

    hidden_cves = repository.about_entries(ApplicationController::ABOUTME_CVES_PATH, include_hidden: true)
    assert_not hidden_cves.any? { |entry| entry["id"].include?("suitecrm-tba") }
  end
end
