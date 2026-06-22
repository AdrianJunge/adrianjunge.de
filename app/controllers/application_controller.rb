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
  ABOUTME_TALKS_PATH = ABOUTME_BASE_PATH.join("talks.json")
  ABOUTME_ACHIEVEMENTS_PATH = ABOUTME_BASE_PATH.join("achievements.json")
  CONTENT_FILTER_KIND_LABELS = ContentTagTaxonomy::CONTENT_TYPE_LABELS.freeze
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

  def sorted_filter_values(values, ctf_labels: [], repository_labels: [])
    ContentTagTaxonomy.canonical_values(values)
                      .sort_by do |value|
                        ContentTagTaxonomy.sort_key(
                          value,
                          content_labels: CONTENT_FILTER_KIND_LABELS,
                          ctf_labels: ctf_labels,
                          repository_labels: repository_labels
                        )
                      end
  end

  def filter_tag_groups(values, content_labels: CONTENT_FILTER_KIND_LABELS, ctf_labels: [], repository_labels: [], topic_label: "Topics")
    ContentTagTaxonomy.filter_groups(
      values,
      content_labels: content_labels,
      ctf_labels: ctf_labels,
      repository_labels: repository_labels,
      topic_label: topic_label
    )
  end

  def filter_ctf_labels
    achievement_competitions = content_repository.about_entries(ABOUTME_ACHIEVEMENTS_PATH).filter_map do |entry|
      entry["title"] if entry["category"].to_s.casecmp?("CTF Competition")
    end

    content_repository.ctf_metadata.keys + achievement_competitions
  end

  def filter_repository_labels
    [ ABOUTME_CVES_PATH, ABOUTME_BUG_BOUNTIES_PATH ].flat_map do |path|
      content_repository.about_entries(path).filter_map { |entry| entry["title"] }
    end
  end

  def adjacent_content_items(items, slug, directory: nil)
    normalized_slug = slug.to_s.downcase
    normalized_directory = directory.to_s.downcase.presence
    index = items.index do |item|
      item[:slug].to_s.downcase == normalized_slug &&
        (normalized_directory.blank? || item[:directory].to_s.downcase == normalized_directory)
    end
    return [ nil, nil ] if index.nil?

    next_item = index.positive? ? items[index - 1] : nil
    previous_item = index < items.length - 1 ? items[index + 1] : nil

    [ previous_item, next_item ]
  end

  def sanitize_which(which)
    sanitize_item(which, BASE_PATH, render_error: true)
  end
end
