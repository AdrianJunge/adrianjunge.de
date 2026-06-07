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
  CONTENT_FILTER_KIND_LABELS = [
    "CTF writeup",
    "Blog post",
    "CVE",
    "Bug bounty",
    "Created challenge",
    "Certificate",
    "Achievement"
  ].freeze
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
    content_repository.parse_markdown(content)
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

  private

  def content_repository
    @content_repository ||= ContentRepository.new
  end

  def sanitize_path(param)
    param.to_s.match?(/\A[a-zA-Z0-9\s\-_]+\z/)
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

      real_base = File.realpath(base_path)
      folder_path = File.realpath(candidate_path)
      unless folder_path.to_s.start_with?(real_base + File::SEPARATOR)
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

  def safe_markdown_file(base_path, *segments, render_error: true)
    if segments.empty?
      render_error_page(:bad_request) if render_error
      return nil
    end

    unless segments.all? { |segment| sanitize_path(segment) }
      render_error_page(:bad_request) if render_error
      return nil
    end

    directory_segments = segments[0...-1]
    filename = "#{segments.last}.md"
    candidate = base_path.join(*directory_segments, filename)
    real_base = base_path.realpath.to_s
    real_file = candidate.realpath.to_s

    unless real_file.start_with?(real_base + File::SEPARATOR)
      render_error_page(:bad_request) if render_error
      return nil
    end

    return Pathname.new(real_file) if File.file?(real_file)

    render_error_page(:not_found) if render_error
    nil
  rescue Errno::ENOENT
    render_error_page(:not_found) if render_error
    nil
  rescue StandardError
    render_error_page(:bad_request) if render_error
    nil
  end

  def safe_markdown_content(base_path, *segments, render_error: true)
    file_path = safe_markdown_file(base_path, *segments, render_error: render_error)
    return nil unless file_path

    File.read(file_path)
  end

  def sorted_filter_values(values)
    values
      .map(&:to_s)
      .reject(&:blank?)
      .uniq { |value| value.downcase }
      .sort_by { |value| AuthoredChallenge.filter_sort_key(value) }
  end

  def filter_tag_groups(values, content_labels: [], topic_label: "Topics")
    tags = sorted_filter_values(values)
    grouped = []

    recognition_tags, tags = tags.partition { |value| [ WriteupWinner::FILTER_LABEL, AuthoredChallenge::FILTER_LABEL ].include?(value) }
    grouped << { label: "Recognition", tags: recognition_tags } if recognition_tags.any?

    content_lookup = Array(content_labels).index_by(&:downcase)
    if content_lookup.any?
      content_tags, tags = tags.partition { |value| content_lookup.key?(value.downcase) }
      grouped << { label: "Content type", tags: content_tags } if content_tags.any?
    end

    grouped << { label: topic_label, tags: tags } if tags.any?
    grouped
  end

  def sanitize_which(which)
    sanitize_item(which, BASE_PATH, render_error: true)
  end
end
