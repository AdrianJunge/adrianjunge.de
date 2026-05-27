class SeoController < ApplicationController
  def sitemap
    @urls = sitemap_entries

    render layout: false
  end

  private

  def sitemap_entries
    entries = [
      sitemap_entry(root_path, newest_mtime(site_content_paths)),
      sitemap_entry(about_path, newest_mtime(about_content_paths)),
      sitemap_entry(ctf_path, newest_mtime(ctf_content_paths)),
      sitemap_entry(blog_path, newest_mtime(blog_content_paths)),
      sitemap_entry(posts_path, newest_mtime(site_content_paths))
    ]

    entries.concat(ctf_sitemap_entries)
    entries.concat(blog_sitemap_entries)
    entries.compact.uniq { |entry| entry[:loc] }
  end

  def ctf_sitemap_entries
    read_json(CTF_INFO_PATH).flat_map do |name, metadata|
      directory = metadata["terminal_path"].presence || name.downcase
      directory_path = BASE_PATH.join(directory)
      next [] unless File.directory?(directory_path)

      files = Dir.glob(directory_path.join("*.md").to_s).select { |path| File.file?(path) }
      entries = [ sitemap_entry("/ctf/#{url_segment(directory)}", newest_mtime(files)) ]

      entries.concat(files.map do |file_path|
        slug = File.basename(file_path, ".md")
        metadata = markdown_metadata(file_path)
        sitemap_entry(
          "/ctf/#{url_segment(directory)}/#{url_segment(slug)}",
          metadata_date(metadata, file_path)
        )
      end)

      entries
    end
  end

  def blog_sitemap_entries
    Dir.glob(BLOG_BASE_PATH.join("*.md").to_s).filter_map do |file_path|
      next unless File.file?(file_path)

      slug = File.basename(file_path, ".md")
      metadata = markdown_metadata(file_path)
      sitemap_entry(blog_post_path(slug), metadata_date(metadata, file_path))
    end
  end

  def sitemap_entry(path, lastmod)
    {
      loc: absolute_site_url(path),
      lastmod: sitemap_date(lastmod)
    }
  end

  def absolute_site_url(path)
    return path if path.to_s.match?(%r{\Ahttps?://}i)

    normalized_path = path.to_s.start_with?("/") ? path.to_s : "/#{path}"
    "#{request.base_url}#{normalized_path}"
  end

  def url_segment(value)
    ERB::Util.url_encode(value.to_s)
  end

  def metadata_date(metadata, file_path)
    metadata["updated"].presence ||
      metadata["modified"].presence ||
      metadata["published"].presence ||
      File.mtime(file_path)
  end

  def sitemap_date(value)
    return value.to_date.iso8601 if value.respond_to?(:to_date)

    Time.zone.parse(value.to_s).to_date.iso8601
  rescue StandardError
    nil
  end

  def markdown_metadata(file_path)
    parsed = parse_markdown_content(File.read(file_path))
    parsed&.front_matter || {}
  rescue StandardError
    {}
  end

  def read_json(path)
    JSON.parse(File.read(path))
  rescue StandardError
    {}
  end

  def newest_mtime(paths)
    expanded_paths = Array(paths).flat_map { |path| Dir.glob(path.to_s) }
    times = expanded_paths.select { |path| File.exist?(path) }.map { |path| File.mtime(path) }
    times.max || Time.current
  end

  def site_content_paths
    about_content_paths + ctf_content_paths + blog_content_paths
  end

  def about_content_paths
    [
      ABOUTME_TEXT_PATH,
      ABOUTME_CVES_PATH,
      ABOUTME_BUG_BOUNTIES_PATH,
      ABOUTME_CHALLENGES_PATH,
      ABOUTME_CERTIFICATES_PATH,
      ABOUTME_ACHIEVEMENTS_PATH
    ]
  end

  def ctf_content_paths
    [ CTF_INFO_PATH, BASE_PATH.join("*", "*.md") ]
  end

  def blog_content_paths
    [ BLOG_INFO_PATH, BLOG_BASE_PATH.join("*.md") ]
  end
end
