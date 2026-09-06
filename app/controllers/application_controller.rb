class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  # Compatibility aliases for existing views and authoring/test integrations.
  ContentConfiguration.constants(false).each do |name|
    const_set(name, ContentConfiguration.const_get(name))
  end
  helper_method :content_repository
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
end
