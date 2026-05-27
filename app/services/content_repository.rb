class ContentRepository
  def about_markdown
    @about_markdown ||= read_file(ApplicationController::ABOUTME_TEXT_PATH)
  end

  def about_entries(path)
    about_entries_cache[path.to_s] ||= read_json_array(path)
  end

  def blog_metadata
    @blog_metadata ||= read_json_object(ApplicationController::BLOG_INFO_PATH)
  end

  def ctf_metadata
    @ctf_metadata ||= read_json_object(ApplicationController::CTF_INFO_PATH)
  end

  def post_metadata(base_path, item)
    cache_key = [ base_path.to_s, item.to_s ]
    return post_metadata_cache[cache_key] if post_metadata_cache.key?(cache_key)

    Dir.glob(base_path.join(item, "*.md")).each_with_object({}) do |file_path, posts_info|
      next unless File.file?(file_path)

      parsed = parse_markdown(read_file(file_path))
      next unless parsed

      posts_info[File.basename(file_path, ".md")] = parsed.front_matter || {}
    end.tap { |posts_info| post_metadata_cache[cache_key] = posts_info }
  end

  def ctf_posts(link_prefix: "/ctf")
    ctf_posts_cache[link_prefix] ||= ctf_metadata.flat_map do |item_key, item_meta|
      dir_name = item_meta["terminal_path"].presence || item_key.downcase

      Dir.glob(ApplicationController::BASE_PATH.join(dir_name, "*.md")).filter_map do |file_path|
        next unless File.file?(file_path)

        content = read_file(file_path)
        parsed = parse_markdown(content)
        next unless parsed

        meta = parsed.front_matter || {}
        title = meta["title"].presence || File.basename(file_path, ".md").humanize
        slug = File.basename(file_path, ".md")
        published = parsed_time(meta["published"], fallback: file_time(file_path, meta["year"]))

        {
          type: "ctf",
          which: item_key,
          item: item_key,
          directory: dir_name,
          slug: slug,
          title: title,
          published: published,
          link: "#{link_prefix}/#{dir_name}/#{slug}",
          description: meta["description"].to_s,
          categories: Array(meta["categories"]),
          logo: item_meta["logo"],
          content: content,
          metadata: meta
        }
      end
    end.sort_by { |item| -item[:published].to_i }
  end

  def blog_posts
    @blog_posts ||= begin
      metadata = blog_metadata

      Dir.glob(ApplicationController::BLOG_BASE_PATH.join("*.md")).filter_map do |file_path|
        next unless File.file?(file_path)

        content = read_file(file_path)
        parsed = parse_markdown(content)
        next unless parsed

        meta = parsed.front_matter || {}
        slug = File.basename(file_path, ".md")
        blog_info = metadata[slug] || {}
        category = blog_info["category"] || "POST"
        title = blog_info["title"].presence || meta["title"].presence || slug.humanize
        published = parsed_time(meta["published"], fallback: file_time(file_path, meta["year"]))

        {
          type: "blog",
          which: category,
          item: slug,
          slug: slug,
          title: title,
          published: published,
          link: "/blog/#{slug}",
          description: meta["description"].to_s,
          topic: meta["topic"].to_s,
          categories: Array(meta["categories"]),
          content: content,
          metadata: meta
        }
      end.sort_by { |item| -item[:published].to_i }
    end
  end

  def post_count
    ctf_posts.length + blog_posts.length
  end

  def metadata_year(metadata)
    published = metadata["published"].presence
    return parsed_time(published, fallback: nil)&.year if published

    metadata["year"].presence&.to_i
  end

  def metadata_tags(metadata)
    (Array(metadata["categories"]) + [ WriteupWinner.filter_label_for(metadata) ])
      .map(&:to_s)
      .reject(&:blank?)
  end

  def achievement_event_count(entries)
    Array(entries).sum do |entry|
      events = Array(entry["events"]).select { |event| event.is_a?(Hash) && event["title"].present? }
      events.any? ? events.length : 1
    end
  end

  def parse_markdown(content)
    FrontMatterParser::Parser.new(:md).call(content)
  rescue StandardError
    nil
  end

  def parsed_time(value, fallback:)
    raw = value.to_s.strip
    return fallback if raw.blank?

    if raw.match?(/\A\d{4}\z/)
      Time.zone.local(raw.to_i, 12, 31)
    elsif (years = raw.scan(/\d{4}/)).any? && !raw.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      Time.zone.local(years.map(&:to_i).max, 12, 31)
    else
      Time.zone.parse(raw)
    end
  rescue StandardError
    fallback
  end

  def file_time(path, year = nil)
    year_value = year.to_s[/\d{4}/]
    return Time.zone.local(year_value.to_i, 12, 31) if year_value

    File.exist?(path) ? File.mtime(path) : Time.zone.now
  end

  def read_json_array(path)
    data = JSON.parse(read_file(path))
    ContentJsonSchemas.validate!(path, data)
    data.is_a?(Array) ? data : []
  rescue JSON::ParserError
    []
  end

  def read_json_object(path)
    data = JSON.parse(read_file(path))
    ContentJsonSchemas.validate!(path, data)
    data.is_a?(Hash) ? data : {}
  rescue JSON::ParserError
    {}
  end

  private

  def read_file(path)
    File.exist?(path) ? File.read(path) : ""
  end

  def about_entries_cache
    @about_entries_cache ||= {}
  end

  def post_metadata_cache
    @post_metadata_cache ||= {}
  end

  def ctf_posts_cache
    @ctf_posts_cache ||= {}
  end
end
