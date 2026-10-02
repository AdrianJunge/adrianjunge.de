require "test_helper"
require "tmpdir"

class SitemapPublicationDatesTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 10, 10)
    @directory = Dir.mktmpdir("sitemap-publication")
    @configuration = ContentConfiguration.new(root: @directory)
    {
      BLOG_BASE_PATH: FixtureContentRepository::ROOT.join("blog", "posts"),
      CTF_INFO_PATH: FixtureContentRepository::ROOT.join("ctf", "ctfs.json"),
      BASE_PATH: FixtureContentRepository::ROOT.join("ctf", "writeups"),
      ABOUTME_BASE_PATH: FixtureContentRepository::ROOT.join("about")
    }.each do |key, source|
      destination = @configuration.path(key)
      FileUtils.mkdir_p(destination.dirname)
      FileUtils.cp_r(source, destination)
    end
    @configuration.path(:ABOUTME_TEXT_PATH).write("---\ntitle: About\n---\nProfile\n")
  end

  teardown do
    FileUtils.remove_entry(@directory)
    travel_back
  end

  test "collection lastmod values describe visible publications and explicit profile updates" do
    fetch_sitemap
    dates = sitemap_dates
    assert_equal SiteProfile.modified, dates.fetch("/about")
    assert_equal SiteProfile.modified, dates.fetch("/")
    assert_equal SiteProfile.modified, dates.fetch("/timeline")
    repository = ContentRepository.new(configuration: @configuration)
    assert_equal repository.blog_posts.map { |post| post[:modified] }.max.to_date.iso8601, dates.fetch("/blog")
    assert_equal repository.ctf_posts.map { |post| post[:modified] }.max.to_date.iso8601, dates.fetch("/ctf")
  end

  test "checkout timestamps and edits to hidden content do not change sitemap output or validators" do
    fetch_sitemap
    original_body = response.body
    original_etag = response.headers.fetch("ETag")

    Dir.glob(File.join(@directory, "**", "*")).select { |path| File.file?(path) }.each do |path|
      File.utime(Time.utc(2040, 1, 1), Time.utc(2040, 1, 1), path)
    end
    hidden_post = @configuration.path(:BASE_PATH).join("democtf", "Hidden.md")
    hidden_post.write(hidden_post.read.sub(/published:.*$/, 'published: "2040-01-01"') + "\nUnpublished revision\n")
    change_talks do |talks|
      talks.first["timeline"].find { |event| event["hidden"] }["date"] = "2040-02-01"
    end

    fetch_sitemap
    assert_equal original_body, response.body
    assert_equal original_etag, response.headers["ETag"]
  end

  test "future scheduled events cannot move public lastmod into the future" do
    fetch_sitemap
    original_dates = sitemap_dates
    change_talks do |talks|
      talks.first["timeline"] << { "id" => "scheduled-talk", "title" => "Upcoming event", "date" => "2040-02-01" }
    end
    fetch_sitemap
    assert_equal original_dates, sitemap_dates

    travel_to Time.zone.local(2041, 1, 1)
    fetch_sitemap
    assert_equal original_dates, sitemap_dates, "event occurrence never becomes an editorial modification"
    travel_to Time.zone.local(2026, 10, 10)

    editorial_date = "2026-10-03"
    change_talks { |talks| talks.first["modified"] = editorial_date }
    fetch_sitemap
    assert_equal editorial_date, sitemap_dates.fetch("/about")
    assert_equal editorial_date, sitemap_dates.fetch("/timeline")
    assert_equal editorial_date, sitemap_dates.fetch("/")
    assert_equal original_dates.fetch("/blog"), sitemap_dates.fetch("/blog")

    travel_to Time.zone.local(2041, 1, 1)
    fetch_sitemap
    assert_equal editorial_date, sitemap_dates.fetch("/about"), "an explicit modification date stays authoritative when the scheduled event passes"
  end

  test "the published About page keeps its date when the scheduled BSides talk arrives" do
    dates = [ Time.zone.local(2026, 11, 8), Time.zone.local(2026, 11, 10) ].map do |date|
      travel_to date
      with_stubbed_content_repository(ContentRepository.new) { get "/sitemap.xml" }
      assert_response :success
      sitemap_dates.fetch("/about")
    end
    assert_equal SiteProfile.modified, dates.first
    assert_equal dates.first, dates.last
  end

  test "article changes update their own and collection dates without rewriting publication" do
    post_path = @configuration.path(:BLOG_BASE_PATH).join("alpha-post.md")
    post_path.write(post_path.read.sub("title: Alpha Research", "title: Alpha Research\nupdated: '2026-10-03'"))
    fetch_sitemap
    assert_equal "2026-10-03", sitemap_dates.fetch("/blog/alpha-post")
    assert_equal "2026-10-03", sitemap_dates.fetch("/blog")
    assert_equal "2026-10-03", sitemap_dates.fetch("/")
    assert_equal "2025-02-02", ContentRepository.new(configuration: @configuration).blog_post("alpha-post")[:published].to_date.iso8601
  end

  private

  def fetch_sitemap
    repository = ContentRepository.new(configuration: @configuration)
    with_stubbed_content_repository(repository) { get "/sitemap.xml" }
    assert_response :success
  end

  def sitemap_dates
    Nokogiri::XML(response.body).xpath("//*[local-name()='url']").to_h do |node|
      [ URI(node.at_xpath("*[local-name()='loc']").text).path, node.at_xpath("*[local-name()='lastmod']").text ]
    end
  end

  def change_talks
    path = @configuration.path(:ABOUTME_TALKS_PATH)
    talks = JSON.parse(path.read)
    yield talks
    path.write(JSON.pretty_generate(talks))
  end
end
