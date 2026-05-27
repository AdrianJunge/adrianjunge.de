class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  BASE_PATH = Rails.root.join("app", "assets", "ctf", "writeups")
  CTF_INFO_PATH = Rails.root.join("app", "assets", "ctf", "ctfs.json")
  BLOG_BASE_PATH = Rails.root.join("app", "assets", "blog", "posts")
  BLOG_INFO_PATH = Rails.root.join("app", "assets", "blog", "blogs.json")
  ABOUTME_BASE_PATH = Rails.root.join("app", "assets", "aboutme")
  ABOUTME_TEXT_PATH = ABOUTME_BASE_PATH.join("about.md")
  ABOUTME_CVES_PATH = ABOUTME_BASE_PATH.join("cves.json")
  ABOUTME_BUG_BOUNTIES_PATH = ABOUTME_BASE_PATH.join("bug_bounties.json")
  ABOUTME_CHALLENGES_PATH = ABOUTME_BASE_PATH.join("challenges.json")
  ABOUTME_CERTIFICATES_PATH = ABOUTME_BASE_PATH.join("certificates.json")
  ABOUTME_ACHIEVEMENTS_PATH = ABOUTME_BASE_PATH.join("achievements.json")
  ERROR_CONTENT = {
    bad_request: {
      status: :bad_request,
      title: "Bad request",
      summary: "That request arrived wearing a fake moustache, and the router noticed.",
      detail: "Double-check the URL; only well-behaved paths get past this particular bouncer."
    },
    not_found: {
      status: :not_found,
      title: "Page not found",
      summary: "This page went looking for bugs and forgot to come back.",
      detail: "Either the content moved, or this route is an urban legend with suspiciously good SEO."
    },
    unprocessable_entity: {
      status: :unprocessable_content,
      title: "Unprocessable request",
      summary: "The server understood the assignment and still handed it back.",
      detail: "Try a cleaner request; this one is doing interpretive dance in the parser."
    },
    internal_server_error: {
      status: :internal_server_error,
      title: "Internal server error",
      summary: "The server tripped over its own stack trace and is pretending that was planned.",
      detail: "Head home while it recovers, stretches, and denies everything."
    }
  }.freeze

  def render_error_page(key)
    @error_content = ERROR_CONTENT.fetch(key)
    @status_code = Rack::Utils.status_code(@error_content[:status])

    render "errors/show", formats: [ :html ], content_type: "text/html", status: @error_content[:status]
  end

  def parse_markdown_content(content)
    begin
      FrontMatterParser::Parser.new(:md).call(content)
    rescue StandardError
      nil
    end
  end

  def get_headings_from_content(content)
    headings = []
    content.scan(/^(#+)\s*(.+?)\s*<a id="(.+)"><\/a>/) do |heading_marks, heading_text, anchor_name|
      markdown_depth = heading_marks.length - 1
      numbered_depth = heading_text.strip[/\A\d+(?:\.\d+)+\./].to_s.count(".") - 1

      headings << {
        text: heading_text.strip,
        anchor: anchor_name.strip,
        depth: [ markdown_depth, numbered_depth, 0 ].max
      }
    end
    headings
  end

  def sanitize_path(param)
    param.match?(/^[a-zA-Z0-9\s\-_]+$/)
  end

  def sanitize_item(item_name, base_path, render_error = true)
    unless sanitize_path(item_name)
      render_error_page(:bad_request) if render_error
      return false
    end

    begin
      candidate_path = File.join(base_path, item_name)
      unless File.directory?(candidate_path)
        render_error_page(:not_found) if render_error
        return false
      end

      folder_path = File.realpath(File.join(base_path, item_name))
      unless folder_path.to_s.start_with?(base_path.to_s)
        render_error_page(:bad_request) if render_error
        return false
      end
      available_items = Dir.entries(base_path).select { |entry| File.directory?(File.join(base_path, entry)) && !entry.start_with?(".") }
      item_exists = available_items.include?(item_name)
      render_error_page(:not_found) if render_error && !item_exists
      item_exists
    rescue StandardError
      render_error_page(:bad_request) if render_error
      false
    end
  end

  def sanitize_post(item_name, post_name, base_path, render_error = true)
    unless sanitize_path(post_name)
      render_error_page(:bad_request) if render_error
      return false
    end

    directory = File.join(base_path, item_name)

    begin
      file_path = File.realpath(base_path.join(item_name, "#{post_name}.md"))
      unless file_path.to_s.start_with?(directory.to_s)
        render_error_page(:bad_request) if render_error
        return false
      end
    rescue StandardError
      render_error_page(:not_found) if render_error
      return false
    end

    if File.exist?(file_path)
      true
    else
      render_error_page(:not_found) if render_error
      false
    end
  end

  # Generic methods for getting content metadata
  def get_posts_metadata(base_path, item)
    posts_info = {}

    Dir.glob(base_path.join(item, "*.md")).each do |file_path|
      next unless File.file?(file_path)

      post_header = File.read(file_path)
      parsed = parse_markdown_content(post_header)
      next unless parsed

      post_name = File.basename(file_path, ".md")
      posts_info[post_name] = parsed.front_matter || {}
    end

    posts_info
  end

  def metadata_year(metadata)
    published = metadata["published"].presence
    return Time.parse(published.to_s).year if published

    metadata["year"].presence&.to_i
  rescue StandardError
    metadata["year"].presence&.to_i
  end

  def metadata_tags(metadata)
    (Array(metadata["categories"]) + [ metadata_writeup_winner_label(metadata) ])
      .map(&:to_s)
      .reject(&:blank?)
  end

  def metadata_writeup_winner_label(metadata)
    WriteupWinner.filter_label_for(metadata)
  end

  def sorted_filter_values(values)
    values
      .map(&:to_s)
      .reject(&:blank?)
      .uniq { |value| value.downcase }
      .sort_by { |value| WriteupWinner.filter_sort_key(value) }
  end

  def get_all_posts_for_feed(base_path, info_path, link_prefix)
    items = []

    begin
      file = File.read(info_path)
      metadata = JSON.parse(file)
    rescue StandardError
      return items
    end

    metadata.each do |item_key, item_meta|
      dir_name = item_meta["terminal_path"] || item_key.downcase
      Dir.glob(base_path.join(dir_name, "*.md")).each do |file_path|
        next unless File.file?(file_path)

        content = File.read(file_path)
        parsed = parse_markdown_content(content)
        next unless parsed

        meta = parsed.front_matter || {}
        title = meta["title"].presence || File.basename(file_path, ".md").humanize
        published = begin
                      Time.parse(meta["published"].to_s)
                    rescue StandardError
                      File.ctime(file_path)
                    end

        slug = File.basename(file_path, ".md")
        link = "#{link_prefix}/#{dir_name}/#{slug}"

        items << {
          type: "ctf",
          which: item_key,
          item: item_key,
          slug: slug,
          title: title,
          published: published,
          link: link,
          description: meta["description"].to_s,
          categories: Array(meta["categories"]),
          logo: item_meta["logo"],
          content: content
        }
      end
    end

    items.sort_by { |i| -i[:published].to_i }
  end

  # CTF-specific methods (wrappers for backward compatibility)
  def sanitize_which(which)
    sanitize_item(which, BASE_PATH, render_error: true)
  end

  def sanitize_writeup(which, writeup)
    sanitize_post(which, writeup, BASE_PATH, render_error: true)
  end

  def get_all_ctf_infos
    file = File.read(CTF_INFO_PATH)
    ctfs = JSON.parse(file)
    ctf_infos = []
    ctfs.each_key do |which|
      writeups_info = get_posts_metadata(BASE_PATH, which.downcase)
      ctf_infos << writeups_info
    end
    ctf_infos
  end

  def get_ctf_infos(which)
    get_posts_metadata(BASE_PATH, which)
  end

  def get_ctf_info(writeup_content)
    parse_markdown_content(writeup_content)
  end

  def get_writeup_headings(which, writeup)
    file_path = BASE_PATH.join(which, "#{writeup}.md")
    return [] unless File.exist?(file_path)

    content = File.read(file_path)
    get_headings_from_content(content)
  end

  def get_timeline
    get_all_posts_for_feed(BASE_PATH, CTF_INFO_PATH, "/ctf")
      .group_by { |i| i[:published].year }
      .tap { |grouped|
        return grouped.keys.sort.reverse.map { |year|
          [ year, grouped[year].sort_by { |i| -i[:published].to_i } ]
        }
      }
  end

  # Blog-specific methods
  def get_blog_posts_for_feed
    items = []

    begin
      blog_metadata = JSON.parse(File.read(BLOG_INFO_PATH))
    rescue StandardError
      blog_metadata = {}
    end

    Dir.glob(BLOG_BASE_PATH.join("*.md")).each do |file_path|
      next unless File.file?(file_path)

      content = File.read(file_path)
      parsed = parse_markdown_content(content)
      next unless parsed

      meta = parsed.front_matter || {}
      slug = File.basename(file_path, ".md")

      # Get category from blogs.json
      blog_info = blog_metadata[slug] || {}
      category = blog_info["category"] || "POST"
      title = blog_info["title"].presence || meta["title"].presence || slug.humanize

      published = begin
                    Time.parse(meta["published"].to_s)
                  rescue StandardError
                    File.ctime(file_path)
                  end

      link = "/blog/#{slug}"

      items << {
        type: "blog",
        which: category,
        item: slug,
        slug: slug,
        title: title,
        published: published,
        link: link,
        description: meta["description"].to_s,
        topic: meta["topic"].to_s,
        categories: Array(meta["categories"]),
        content: content,
        metadata: meta
      }
    end

    items.sort_by { |i| -i[:published].to_i }
  end

  # Mixed timeline for CTF + Blog posts
  def get_mixed_timeline
    ctf_items = get_all_posts_for_feed(BASE_PATH, CTF_INFO_PATH, "/ctf")
    blog_items = get_blog_posts_for_feed

    combined = ctf_items + blog_items

    grouped = combined.group_by { |i| i[:published].year }
    timeline = grouped.keys.sort.reverse.map { |year|
      [ year, grouped[year].sort_by { |i| i[:published] }.reverse ]
    }
    timeline
  end

  def get_blog_post_headings(post_slug)
    file_path = BLOG_BASE_PATH.join("#{post_slug}.md")
    return [] unless File.exist?(file_path)

    content = File.read(file_path)
    get_headings_from_content(content)
  end
end
