class SeoController < ApplicationController
  self.requires_modern_browser = false

  def sitemap
    @urls = sitemap_entries
    return unless stale?(etag: [ "sitemap-v6", @urls ], public: true)

    render layout: false
  end

  private

  def sitemap_entries
    blog_modified = newest_public_date(content_repository.blog_posts.map { |post| post_modified(post) })
    ctf_modified = newest_public_date(content_repository.ctf_posts.map { |post| post_modified(post) })
    about_modified = newest_public_date([ SiteProfile.modified, *about_content_dates ])
    site_modified = newest_public_date([ blog_modified, ctf_modified, about_modified ])
    entries = [
      sitemap_entry(root_path, site_modified),
      sitemap_entry(about_path, about_modified),
      sitemap_entry(ctf_path, ctf_modified),
      sitemap_entry(blog_path, blog_modified),
      sitemap_entry(timeline_path, site_modified)
    ]

    entries.concat(ctf_sitemap_entries)
    entries.concat(blog_sitemap_entries)
    entries.compact.uniq { |entry| entry[:loc] }
  end

  def ctf_sitemap_entries
    visible_posts_by_directory = content_repository.ctf_posts.group_by { |post| post[:directory] }

    content_repository.ctf_events.flat_map do |event|
      posts = Array(visible_posts_by_directory[event[:slug]])
      next [] if posts.empty?

      entries = [ sitemap_entry(event[:metadata].fetch("writeups"), newest_public_date(posts.map { |post| post_modified(post) })) ]

      entries.concat(posts.map do |post|
        sitemap_entry(post[:link], post_modified(post))
      end)

      entries
    end
  end

  def blog_sitemap_entries
    content_repository.blog_posts.map do |post|
      sitemap_entry(post[:link], post_modified(post))
    end
  end

  def sitemap_entry(path, lastmod)
    {
      loc: SiteProfile.absolute_url(path),
      lastmod: newest_public_date([ lastmod ]).to_date.iso8601
    }
  end

  def post_modified(post)
    newest_public_date([ post[:modified], post[:published] ])
  end

  def newest_public_date(values)
    # A scheduled event does not mean this page was edited in the future.
    dates = values.filter_map { |value| ContentDate.parse(value) }.select { |value| value <= Time.current }
    dates.max || ContentDate::EPOCH
  end

  def about_content_dates
    paths = [
      ABOUTME_CVES_PATH,
      ABOUTME_CHALLENGES_PATH,
      ABOUTME_CERTIFICATES_PATH,
      ABOUTME_TALKS_PATH,
      ABOUTME_ACHIEVEMENTS_PATH
    ]
    paths.flat_map do |path|
      entries = path == ABOUTME_CHALLENGES_PATH ? content_repository.authored_challenges : content_repository.about_entries(path)
      entries.flat_map { |entry| authored_dates(entry) }
    end
  end

  def authored_dates(entry)
    explicit_modified = entry["updated"].presence || entry["modified"].presence
    return [ explicit_modified ] if explicit_modified

    # Event dates describe when a talk/disclosure happened, not when its listing
    # changed. Undated editorial changes use SiteProfile.modified instead.
    [ entry["published"] ].compact +
      Array(entry["timeline"]).flat_map { |event| authored_dates(event) }
  end
end
