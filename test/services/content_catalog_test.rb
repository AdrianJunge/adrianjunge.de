require "test_helper"
require "tmpdir"

class ContentCatalogTest < ActiveSupport::TestCase
  setup { ContentCatalog.clear }
  teardown { ContentCatalog.clear }

  test "catalog caches immutable snapshots and returns independent mutable records" do
    source = [ { title: "Original", tags: [ "Web" ] } ]
    first = ContentCatalog.fetch(:posts, revision: "first") { source }
    first.first[:title].replace("Changed")
    first.first[:tags] << "Other"
    second = ContentCatalog.fetch(:posts, revision: "first") { flunk "warm catalog should be reused" }

    assert_equal [ { title: "Original", tags: [ "Web" ] } ], second
    assert_not source.first[:title].frozen?, "building a snapshot must not freeze caller-owned records"
    assert_equal [ { title: "New revision" } ], ContentCatalog.fetch(:posts, revision: "second") { [ { title: "New revision" } ] }
  end

  test "revisions distinguish edits replacements deletions inventories and roots" do
    Dir.mktmpdir("content-catalog") do |directory|
      path = Pathname(directory).join("post.md")
      path.write("first")
      original_time = path.mtime
      first = ContentCatalog.revision([ path ])
      assert_equal first, ContentCatalog.revision([ path ])

      path.write("other")
      File.utime(original_time, original_time, path)
      edited = ContentCatalog.revision([ path ])
      assert_not_equal first, edited, "same-length edits with restored mtime must invalidate"

      replacement = path.dirname.join("replacement.md")
      replacement.write("other")
      File.utime(original_time, original_time, replacement)
      File.rename(replacement, path)
      assert_not_equal edited, ContentCatalog.revision([ path ])

      second = path.dirname.join("second.md")
      second.write("other")
      assert_not_equal ContentCatalog.revision([ path ]), ContentCatalog.revision([ second ])
      assert_not_equal ContentCatalog.revision([ path ]), ContentCatalog.revision([ path, second ])
      previous = ContentCatalog.revision([ path ])
      path.delete
      assert_not_equal previous, ContentCatalog.revision([ path ])
    end
  end

  test "cached dates are isolated from both callers and original records" do
    source = { published: Time.zone.local(2026, 1, 1) }
    first = ContentCatalog.fetch(:dates, revision: "one") { source }
    first[:published].time.localtime("-12:00")
    second = ContentCatalog.fetch(:dates, revision: "one") { flunk "warm cache should be reused" }

    assert_equal [ 2026, 1, 1 ], [ second[:published].year, second[:published].month, second[:published].day ]
    assert_equal [ 2026, 1, 1 ], [ source[:published].year, source[:published].month, source[:published].day ]
  end

  test "catalog records use the current application time zone" do
    Time.use_zone("UTC") do
      assert_equal "UTC", ContentCatalog.fetch(:zone, revision: "one") { Time.zone.local(2026, 1, 1) }.time_zone.name
    end
    Time.use_zone("America/New_York") do
      assert_equal "America/New_York", ContentCatalog.fetch(:zone, revision: "one") { Time.zone.local(2026, 1, 1) }.time_zone.name
    end
  end

  test "catalog date copies preserve fractional instants and daylight saving offsets" do
    Time.use_zone("Europe/Berlin") do
      [ "2026-03-29T00:59:59.123456789Z", "2026-03-29T01:00:00.123456789Z",
        "2026-10-25T00:59:59.123456789Z", "2026-10-25T01:00:00.123456789Z" ].each do |timestamp|
        source = Time.iso8601(timestamp).in_time_zone
        first = ContentCatalog.fetch(:dst, revision: timestamp) { { date: source } }[:date]
        second = ContentCatalog.fetch(:dst, revision: timestamp) { flunk "expected cached timestamp" }[:date]
        [ first, second ].each do |copy|
          assert_equal source.to_r, copy.to_r
          assert_equal source.utc_offset, copy.utc_offset
          assert_equal source.time_zone.name, copy.time_zone.name
          assert_not_same source.utc, copy.utc
          assert_not_same source.time, copy.time
        end
        assert_not_same first.utc, second.utc
        assert_not_same first.time, second.time
      end
    end
  end

  test "required document loaders report missing files by source path" do
    Dir.mktmpdir("missing-content") do |directory|
      configuration = ContentConfiguration.new(root: directory)
      repository = ContentRepository.new(configuration: configuration)
      [ configuration.path(:ABOUTME_TEXT_PATH), configuration.path(:CTF_INFO_PATH) ].each do |path|
        error = assert_raises(ContentRepository::InvalidContent) do
          path.extname == ".md" ? repository.about_markdown : repository.ctf_metadata
        end
        assert_includes error.message, path.to_s
        assert_includes error.message, "required content file is missing"
      end
      assert_raises(ContentRepository::InvalidContent) { repository.markdown_document(Pathname(directory).join("missing.md")) }
    end
  end

  test "repository and timeline caches refresh visibility and additions without restart" do
    with_checkout do |config|
      post_path = config.path(:BLOG_BASE_PATH).join("sample.md")
      write_post(post_path, title: "Original")
      new_repository = -> { ContentRepository.new(configuration: config) }

      first = new_repository.call
      assert_equal "Original", first.blog_post("sample")[:title]
      first_timeline = ContentIndex.new(repository: first).all_items
      assert_equal [ "Original" ], first_timeline.map { |item| item[:title] }
      first_timeline.first[:title].replace("Consumer mutation")
      assert_equal "Original", ContentIndex.new(repository: new_repository.call).all_items.first[:title]

      write_post(post_path, title: "Edited", hidden: true)
      assert_empty new_repository.call.blog_posts
      assert_empty ContentIndex.new(repository: new_repository.call).all_items

      write_post(post_path, title: "Restored")
      write_post(config.path(:BLOG_BASE_PATH).join("second.md"), title: "Second")
      assert_equal [ "Restored", "Second" ].sort, new_repository.call.blog_posts.map { |post| post[:title] }.sort
      assert_equal 2, ContentIndex.new(repository: new_repository.call).all_items.length

      post_path.delete
      assert_equal [ "Second" ], new_repository.call.blog_posts.map { |post| post[:title] }
      assert_equal [ "Second" ], ContentIndex.new(repository: new_repository.call).all_items.map { |item| item[:title] }
    end
  end

  test "front matter controls normalized posts and metadata remains request local" do
    with_checkout do |config|
      write_post(config.path(:BLOG_BASE_PATH).join("sample.md"), title: "Article title")
      repository = ContentRepository.new(configuration: config)
      post = repository.blog_post("sample")

      assert_equal "Article title", post[:title]
      assert_equal "A test article.", post[:description]
      assert_equal "Engineering", post[:which]
      assert_equal "/blog/sample", post[:link]
      assert_equal post[:published], post[:modified]
      assert_equal [ SiteProfile.author ], post[:authors]
      assert_equal post[:word_count], post[:metadata]["word_count"]
      post[:metadata]["title"].replace("Local decoration")
      assert_equal "Article title", ContentRepository.new(configuration: config).blog_post("sample")[:metadata]["title"]

      path = config.path(:BLOG_BASE_PATH).join("sample.md")
      path.write(path.read.sub('published: "2026-01-01"', "published: \"2026-01-01\"\nupdated: \"2026-06-01\""))
      updated = ContentRepository.new(configuration: config).blog_post("sample")
      assert_equal post[:published], updated[:published]
      assert_equal "2026-06-01", updated[:modified].to_date.iso8601

      write_post(config.path(:BLOG_BASE_PATH).join("sample.md"), title: "Article title", hidden: true)
      assert_empty ContentRepository.new(configuration: config).blog_posts
    end
  end

  test "CTF catalog visibility and About edits invalidate normalized timelines" do
    with_checkout do |config|
      directory = config.path(:BASE_PATH).join("demo")
      directory.mkpath
      write_post(directory.join("sample.md"), title: "CTF article")
      event = { "directory" => "demo", "logo" => "demo.svg", "website" => "https://example.com", "description" => "Demo event" }
      config.path(:CTF_INFO_PATH).write({ "DEMO" => event }.to_json)
      repository = -> { ContentRepository.new(configuration: config) }
      assert_equal "/ctf/demo/sample", repository.call.ctf_posts.first[:link]
      assert_equal [ "CTF article" ], ContentIndex.new(repository: repository.call).all_items.map { |item| item[:title] }

      config.path(:CTF_INFO_PATH).write({ "DEMO" => event.merge("hidden" => true) }.to_json)
      assert_empty repository.call.ctf_posts
      assert_empty ContentIndex.new(repository: repository.call).all_items

      config.path(:ABOUTME_TALKS_PATH).write('[{"id":"talk","title":"New talk","timeline":[{"date":"2026-01-01"}]}]')
      assert_equal [ "New talk" ], ContentIndex.new(repository: repository.call).all_items.map { |item| item[:title] }
      config.path(:ABOUTME_TALKS_PATH).write('[{"id":"talk","title":"New talk","timeline":[{"date":"2026-01-01"}],"hidden":true}]')
      assert_empty ContentIndex.new(repository: repository.call).all_items
    end
  end

  test "injected and subclass repositories retain their independent content behavior" do
    with_checkout do |config|
      write_post(config.path(:BLOG_BASE_PATH).join("sample.md"), title: "Shared file")
      assert_equal 1, ContentRepository.new(configuration: config).blog_posts.length
      injected = ContentRepository.new(configuration: config, ctf_metadata_data: { "PRIVATE" => { "hidden" => true } })
      assert_empty injected.ctf_posts
      assert_equal 1, injected.blog_posts.length

      subclass = Class.new(ContentRepository) do
        def hidden_content?(_metadata)
          true
        end
      end
      assert_empty subclass.new(configuration: config).blog_posts
      assert_equal 1, ContentRepository.new(configuration: config).blog_posts.length
    end
  end

  test "missing publication dates have a stable fallback independent of checkout time" do
    with_checkout do |config|
      path = config.path(:BLOG_BASE_PATH).join("sample.md")
      path.write("---\ntitle: Legacy\ndescription: Legacy post\n---\nBody")
      first = ContentRepository.new(configuration: config).blog_posts.first
      assert_equal ContentDate::EPOCH, first[:published]
      File.utime(Time.now, Time.now, path)
      second = ContentRepository.new(configuration: config).blog_posts.first
      assert_equal first[:published], second[:published]
      assert_equal first[:modified], second[:modified]
    end
  end

  private

  def with_checkout
    Dir.mktmpdir("content-checkout") do |directory|
      config = ContentConfiguration.new(root: directory)
      [ :BASE_PATH, :BLOG_BASE_PATH, :ABOUTME_BASE_PATH ].each { |name| config.path(name).mkpath }
      config.path(:CTF_INFO_PATH).write("{}")
      %i[ABOUTME_CVES_PATH ABOUTME_CHALLENGES_PATH ABOUTME_CERTIFICATES_PATH ABOUTME_TALKS_PATH ABOUTME_ACHIEVEMENTS_PATH].each do |name|
        config.path(name).write("[]")
      end
      yield config
    end
  end

  def write_post(path, title:, hidden: false)
    path.write(<<~MARKDOWN)
      ---
      title: #{title}
      description: A test article.
      category: Engineering
      published: "2026-01-01"
      hidden: #{hidden}
      ---
      Test article body.
    MARKDOWN
  end
end
