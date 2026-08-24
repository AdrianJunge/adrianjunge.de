require "test_helper"
require "tmpdir"

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

  test "repository attaches reading time to every published blog and CTF post" do
    repository = production_content_repository

    assert repository.blog_posts.all? { |post| post[:reading_time_label].present? }
    assert repository.ctf_posts.all? { |post| post[:reading_time_label].present? }
    assert repository.blog_posts.all? { |post| post[:word_count].positive? }
    assert repository.ctf_posts.all? { |post| post[:word_count].positive? }

    assert_operator repository.total_post_reading_time_minutes, :>, 0
    assert_match(/\A\d+ min read\z/, repository.format_reading_time(repository.total_post_reading_time_minutes))

    fixture_posts = fixture_content_repository.blog_posts + fixture_content_repository.ctf_posts
    assert fixture_posts.all? { |post| post[:word_count].positive? }
    assert fixture_posts.all? { |post| post[:reading_time_minutes].positive? }
    fixture_posts.each do |post|
      assert_equal "#{post[:word_count]} #{post[:word_count] == 1 ? 'word' : 'words'}", post[:word_count_label]
      assert_equal "#{post[:reading_time_minutes]} min read", post[:reading_time_label]
    end
  end

  test "authored challenges are read from the complete compact about collection" do
    repository = production_content_repository
    challenges = repository.authored_challenges
    raw_challenges = parse_content_json(ApplicationController::ABOUTME_CHALLENGES_PATH)
    expected_ids = raw_challenges.reject { |entry| repository.hidden_content?(entry) }.map { |entry| entry.fetch("id") }

    assert_equal expected_ids.sort, challenges.map { |entry| entry.fetch("id") }.sort
    assert_equal challenges.map { |entry| entry["id"] }.uniq, challenges.map { |entry| entry["id"] }
    assert challenges.none? { |entry| repository.hidden_content?(entry) }
    assert challenges.all? { |entry| entry["id"].present? && entry["title"].present? }
    assert challenges.all? { |entry| Array(entry["timeline"]).any? { |event| event["date"].present? } }
    assert(challenges.all? do |entry|
      Array(entry["tags"]).any? do |tag|
        tag.is_a?(Hash) && tag["label"].present? && tag["url"].to_s.start_with?("/ctf/")
      end
    end)

    fixture_challenge = fixture_content_repository.authored_challenges.fetch(0)
    assert_equal "space-writeup", fixture_challenge["id"]
    assert_equal "/ctf/democtf/Space%20Writeup", fixture_challenge["tags"].last["url"]
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

  test "timeline event count counts each visible dated event" do
    repository = ContentRepository.new
    entries = [
      {
        "timeline" => [
          { "date" => "2026-01-01", "title" => "First talk" },
          { "date" => "2026-02-01", "title" => "Second talk" },
          { "title" => "Undated note" }
        ]
      },
      { "timeline" => [ { "date" => "2026-03-01", "title" => "Hidden talk", "hidden" => true } ] },
      { "title" => "Entry without a timeline" }
    ]

    assert_equal 3, repository.timeline_event_count(entries)
  end

  test "generic feed posts merge configured content sources" do
    repository = fixture_content_repository
    items = repository.feed_posts

    assert items.any? { |item| item[:source_key] == "blog" && item[:link].start_with?("/blog/") }
    assert items.any? { |item| item[:source_key] == "ctf" && item[:link].start_with?("/ctf/") }
    assert_equal items.sort_by { |item| -item[:published].to_i }.map { |item| item[:guid] }, items.map { |item| item[:guid] }
  end

  test "hidden and draft content stays out of public collections" do
    repository = fixture_content_repository

    assert_equal [ "Space Writeup", "Winner", "Middle" ], repository.ctf_posts.map { |post| post[:slug] }
    assert_nil repository.ctf_post("democtf", "Hidden")
    assert_nil repository.ctf_post("hiddenctf", "Leaked")
    assert_nil repository.ctf_event("hiddenctf")
    assert_equal [ "DEMOCTF" ], repository.ctf_metadata.keys

    visible_events = repository.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH)
      .flat_map { |entry| entry["timeline"] }
      .map { |event| event["id"] }
    all_events = repository.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH, include_hidden: true)
      .flat_map { |entry| entry["timeline"] }
      .map { |event| event["id"] }

    assert_not_includes visible_events, "fixture-result-hidden"
    assert_includes all_events, "fixture-result-hidden"

    talk_events = repository.about_entries(ApplicationController::ABOUTME_TALKS_PATH)
      .flat_map { |entry| entry["timeline"] }
      .map { |event| event["id"] }
    assert_not_includes talk_events, "fixture-talk-hidden"

    production_collections = ContentTestHelpers::ABOUT_COLLECTIONS.map do |spec|
      about_collection_entries(spec, repository: production_content_repository)
    end
    assert production_collections.flatten.none? { |entry| production_content_repository.hidden_content?(entry) }
  end

  test "exact content lookups only return catalogued records" do
    repository = fixture_content_repository
    blog_post = repository.blog_post("alpha-post")
    ctf_post = repository.ctf_post("democtf", "Space Writeup")
    event = repository.ctf_event("democtf")

    assert_equal blog_post, repository.blog_post(blog_post[:slug])
    assert_equal ctf_post, repository.ctf_post(ctf_post[:directory], ctf_post[:slug])
    assert_equal event, repository.ctf_event(event[:slug])
    assert_includes repository.ctf_posts_for_event(event[:slug]), ctf_post

    assert_nil repository.blog_post("../#{blog_post[:slug]}")
    assert_nil repository.blog_post("#{blog_post[:slug]}.md")
    assert_nil repository.ctf_event("../#{event[:slug]}")
    assert_nil repository.ctf_post(ctf_post[:directory], "../#{ctf_post[:slug]}")
    assert_empty repository.ctf_posts_for_event("missing-event")
  end

  test "temporary content roots enforce publication boundaries and reject escaping symlinks" do
    with_content_roots do |paths|
      paths[:ctf].join("declared").mkpath
      paths[:ctf].join("undeclared").mkpath
      write_markdown(paths[:ctf].join("declared", "Published Post.md"), title: "Published Post")
      write_markdown(paths[:ctf].join("declared", "Draft Post.md"), title: "Draft Post", extra: "draft: true")
      write_markdown(paths[:ctf].join("undeclared", "Secret Post.md"), title: "Secret Post")

      outside = paths[:root].join("outside.md")
      write_markdown(outside, title: "Outside Post")
      File.symlink(outside, paths[:ctf].join("declared", "Leaked Post.md"))

      write_markdown(paths[:blog].join("published-post.md"), title: "Published Blog")
      write_markdown(paths[:blog].join("hidden-post.md"), title: "Hidden Blog")
      write_markdown(paths[:blog].join("unlisted-post.md"), title: "Unlisted Blog")

      ctf_metadata = {
        "DECLARED" => {
          "terminal_path" => "declared",
          "website" => "https://example.com/"
        }
      }
      blog_metadata = {
        "published-post" => {
          "title" => "Published Blog",
          "category" => "Test"
        },
        "hidden-post" => {
          "title" => "Hidden Blog",
          "category" => "Test",
          "hidden" => true
        }
      }
      repository = repository_for(
        paths,
        ctf_metadata: ctf_metadata,
        blog_metadata: blog_metadata
      )

      assert_equal [ "Published Post" ], repository.ctf_posts.map { |post| post[:title] }
      assert_nil repository.ctf_post("undeclared", "Secret Post")
      assert_nil repository.ctf_post("declared", "Leaked Post")
      assert_equal [ "published-post" ], repository.blog_posts.map { |post| post[:slug] }
      assert_nil repository.blog_post("hidden-post")
      assert_nil repository.blog_post("unlisted-post")
    end
  end

  test "CTF assets use stable opaque identifiers and canonical private paths" do
    with_content_roots do |paths|
      event_directory = paths[:ctf].join("declared")
      event_directory.mkpath
      write_markdown(
        event_directory.join("Asset Post.md"),
        title: "Asset Post",
        extra: "ctf_year: 2026\nchallengefiles: asset-post"
      )
      write_markdown(
        event_directory.join("Escaped Asset.md"),
        title: "Escaped Asset",
        extra: "ctf_year: 2026\nchallengefiles: escaped-asset"
      )
      challenge_file = paths[:challenge_files].join("declared", "2026", "asset-post.zip")
      pdf_file = paths[:pdf_writeups].join("declared", "2026", "asset-post.pdf")
      outside_file = paths[:root].join("outside.zip")
      escaped_file = paths[:challenge_files].join("declared", "2026", "escaped-asset.zip")
      challenge_file.dirname.mkpath
      pdf_file.dirname.mkpath
      challenge_file.binwrite("ZIP fixture")
      pdf_file.binwrite("PDF fixture")
      outside_file.binwrite("outside fixture")
      File.symlink(outside_file, escaped_file)

      metadata = {
        "DECLARED" => {
          "terminal_path" => "declared",
          "website" => "https://example.com/"
        }
      }
      repository = repository_for(paths, ctf_metadata: metadata)

      post = repository.ctf_post("declared", "Asset Post")
      escaped_post = repository.ctf_post("declared", "Escaped Asset")
      challenge = repository.ctf_asset_for(post, :challenge)
      writeup = repository.ctf_asset_for(post, :writeup)

      assert_match ContentRepository::CTF_ASSET_ID_PATTERN, challenge[:id]
      assert_equal challenge, repository.ctf_asset(challenge[:id])
      assert_equal challenge_file.realpath, challenge[:path]
      assert_equal "attachment", challenge[:disposition]
      assert_equal pdf_file.realpath, writeup[:path]
      assert_equal "inline", writeup[:disposition]
      assert_nil repository.ctf_asset_for(escaped_post, :challenge)
      assert_nil repository.ctf_asset("../#{challenge[:id]}")
      assert_nil repository.ctf_asset(challenge[:id].sub(/\A./, "f" * 2))
    end
  end

  test "public CTF resources use stable opaque catalog entries" do
    repository = ContentRepository.new

    repository.ctf_assets.each do |asset|
      assert_match ContentRepository::CTF_ASSET_ID_PATTERN, asset[:id]
      assert_equal asset, repository.ctf_asset(asset[:id])
      assert_equal asset[:path].basename.to_s, asset[:basename]
      assert asset[:path].file?
    end
  end

  private

  def with_content_roots
    Dir.mktmpdir do |directory|
      root = Pathname(directory)
      paths = {
        root: root,
        ctf: root.join("ctf"),
        blog: root.join("blog"),
        challenge_files: root.join("challenge-files"),
        pdf_writeups: root.join("pdf-writeups")
      }
      paths.values_at(:ctf, :blog, :challenge_files, :pdf_writeups).each(&:mkpath)

      yield paths
    end
  end

  def repository_for(paths, ctf_metadata: nil, blog_metadata: nil)
    ContentRepository.new(
      ctf_base_path: paths[:ctf],
      blog_base_path: paths[:blog],
      ctf_challenge_files_path: paths[:challenge_files],
      ctf_pdf_writeups_path: paths[:pdf_writeups],
      ctf_metadata_data: ctf_metadata,
      blog_metadata_data: blog_metadata
    )
  end

  def write_markdown(path, title:, extra: nil)
    path.write(<<~MARKDOWN)
      ---
      title: #{title}
      published: "2026-01-01"
      #{extra}
      ---

      Published body content.
    MARKDOWN
  end
end
