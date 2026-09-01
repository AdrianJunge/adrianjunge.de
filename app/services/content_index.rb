require "cgi"

class ContentIndex
  EVENT_BASED_ABOUT_KINDS = %w[talk achievement].freeze

  ABOUT_COLLECTIONS = [
    {
      path: ApplicationController::ABOUTME_CVES_PATH,
      kind: "cve",
      label: "CVE",
      section: "cves"
    },
    {
      path: ApplicationController::ABOUTME_BUG_BOUNTIES_PATH,
      kind: "bug-bounty",
      label: "Bug bounty",
      section: "bug-bounties"
    },
    {
      path: ApplicationController::ABOUTME_CHALLENGES_PATH,
      kind: "challenge",
      label: AuthoredChallenge::FILTER_LABEL,
      section: "my-challenges"
    },
    {
      path: ApplicationController::ABOUTME_CERTIFICATES_PATH,
      kind: "certificate",
      label: "Certificate",
      section: "certificates"
    },
    {
      path: ApplicationController::ABOUTME_TALKS_PATH,
      kind: "talk",
      label: "Talk",
      section: "talks"
    },
    {
      path: ApplicationController::ABOUTME_ACHIEVEMENTS_PATH,
      kind: "achievement",
      label: "Achievement",
      section: "achievements"
    }
  ].freeze

  def initialize(repository: ContentRepository.new)
    @repository = repository
  end

  def all_items
    @all_items ||= merged_timeline_items(post_items + about_items).sort_by { |item| -item[:published].to_i }
  end

  private

  def post_items
    @post_items ||= ctf_items + blog_items
  end

  def ctf_items
    repository.ctf_posts.map do |post|
      metadata = post[:metadata] || {}
      winner = WriteupWinner.from_metadata(metadata)
      authored_challenge = AuthoredChallenge.from_metadata(metadata)

      content_item(
        id: "ctf-#{post[:directory].parameterize}-#{post[:slug].parameterize}",
        kind: "writeup",
        label: "CTF writeup",
        source: post[:which],
        title: post[:title],
        description: post[:description],
        published: post[:published],
        display_date: post[:published].strftime("%Y-%m-%d"),
        link: post[:link],
        tags: [ post[:which] ] + repository.metadata_tags(metadata),
        search_parts: [ post[:which], post[:title], metadata, post[:content] ],
        timeline_group: metadata["timeline_group"].presence,
        logo: post[:logo],
        reading_time_minutes: post[:reading_time_minutes],
        reading_time_label: post[:reading_time_label],
        writeup_winner: winner,
        authored_challenge: authored_challenge
      )
    end
  end

  def blog_items
    blog_metadata = repository.blog_metadata

    repository.blog_posts.map do |post|
      metadata = post[:metadata] || {}

      content_item(
        id: "blog-#{post[:slug].parameterize}",
        kind: "blog",
        label: "Blog post",
        source: post[:which],
        title: post[:title],
        description: post[:description],
        published: post[:published],
        display_date: post[:published].strftime("%Y-%m-%d"),
        link: post[:link],
        tags: [ post[:which] ] + repository.metadata_tags(metadata),
        search_parts: [ post[:which], post[:title], metadata, post[:content] ],
        timeline_group: metadata["timeline_group"].presence || blog_metadata.dig(post[:slug], "timeline_group").presence,
        logo: blog_metadata.dig(post[:slug], "logo"),
        reading_time_minutes: post[:reading_time_minutes],
        reading_time_label: post[:reading_time_label]
      )
    end
  end

  def about_items
    ABOUT_COLLECTIONS.flat_map do |collection|
      entries = about_collection_entries(collection)

      entries.flat_map do |entry|
        if EVENT_BASED_ABOUT_KINDS.include?(collection[:kind])
          about_timeline_items(entry, collection)
        else
          about_entry_item(entry, collection)
        end
      end
    end
  end

  def about_entry_item(entry, collection)
    id = entry["id"].presence || entry["title"].to_s.parameterize
    return [] if id.blank?

    published = about_published_time(entry, collection[:path])
    display_date = about_card_display_date(entry, published)
    title = entry["title"].presence || collection[:label]
    description = about_description(entry)
    tags = about_tags(entry, collection)
    link = about_entry_timeline_link(entry, id, collection)

    [
      content_item(
        id: "about-#{collection[:kind]}-#{id.parameterize}",
        kind: collection[:kind],
        label: collection[:label],
        title: title,
        description: description,
        published: published,
        display_date: display_date,
        link: link,
        tags: tags,
        search_parts: [ collection[:label], entry ],
        timeline_group: entry["timeline_group"].presence,
        logo: about_entry_icon(entry, collection),
        source: entry["title"].presence || "About"
      )
    ]
  end

  def about_timeline_items(entry, collection)
    parent_id = entry["id"].presence || entry["title"].to_s.parameterize
    return [] if parent_id.blank?

    events = Array(entry["timeline"]).select { |event| event.is_a?(Hash) && event["title"].present? }
    return about_entry_item(entry, collection) if events.empty?

    events.filter_map do |event|
      event_id = event["id"].presence || "#{parent_id}-#{event["date"]}-#{event["title"]}".parameterize
      next if event_id.blank?

      published = repository.parsed_time(event["date"], fallback: about_published_time(entry, collection[:path]))
      description = event["summary"].presence || about_description(entry)
      title = event["title"].presence || entry["title"].presence || collection[:label]
      tags = about_tags(entry, collection) + [ entry["title"] ]

      content_item(
        id: "about-#{collection[:kind]}-#{event_id.parameterize}",
        kind: collection[:kind],
        label: collection[:label],
        source: entry["title"].presence || "About",
        title: title,
        description: description,
        published: published,
        display_date: about_timeline_event_display_date(event, published),
        link: "/about##{event_id}",
        tags: tags,
        search_parts: [ collection[:label], entry, event ],
        timeline_group: event["timeline_group"].presence,
        logo: event["icon"].presence || about_entry_icon(entry, collection)
      )
    end
  end

  def content_item(**attrs)
    tags = ContentTagTaxonomy.canonical_values([ attrs[:label] ] + Array(attrs[:tags]))
    kind_labels = timeline_content_type_labels(tags)

    attrs.merge(
      kind_labels: kind_labels,
      tags: tags,
      search_text: search_text_for(attrs.values + kind_labels + tags)
    )
  end

  def merged_timeline_items(items)
    grouped = {}
    unmergeable = []

    items.each do |item|
      key = timeline_merge_key(item)
      if key.present?
        grouped[key] ||= []
        grouped[key] << item
      else
        unmergeable << item
      end
    end

    unmergeable + grouped.values.map { |group| merge_timeline_item_group(group) }
  end

  def merge_timeline_item_group(group)
    return group.first if group.one?

    primary = group.first
    published = group.filter_map { |item| item[:published] }.max || primary[:published]
    date_source = group.find { |item| item[:published] == published } || primary
    tags = ContentTagTaxonomy.canonical_values(group.flat_map { |item| [ item[:label], *Array(item[:tags]) ] })
    kind_labels = timeline_content_type_labels(tags)
    search_text = search_text_for(group.flat_map do |item|
      [ item[:search_text], item[:title], item[:description], item[:source], item[:label], item[:tags], item[:kind_labels] ]
    end + kind_labels + tags)

    primary.merge(
      published: published,
      display_date: date_source[:display_date].presence || primary[:display_date],
      logo: primary[:logo].presence || group.find { |item| item[:logo].present? }&.dig(:logo),
      kind_labels: kind_labels,
      tags: tags,
      search_text: search_text,
      merged_item_ids: group.map { |item| item[:id] }
    )
  end

  def timeline_merge_key(item)
    explicit_group = item[:timeline_group].to_s.parameterize
    return "timeline-group:#{explicit_group}" if explicit_group.present?

    link = item[:link].to_s
    return if link.blank?

    "link:#{CGI.unescape(link)}"
  end

  def timeline_content_type_labels(tags)
    ContentTagTaxonomy.canonical_values(tags)
                      .select { |tag| ContentTagTaxonomy.content_type?(tag) }
                      .map { |tag| { label: tag, tag_value: tag } }
  end

  def about_description(entry)
    entry["subtitle"].presence ||
      entry["summary"].presence ||
      ""
  end

  def about_collection_entries(collection)
    if collection[:kind] == "challenge"
      repository.authored_challenges
    else
      repository.about_entries(collection[:path])
    end
  end

  def about_tags(entry, collection)
    extra_tags = [ collection[:label] ]
    extra_tags << entry["title"] if %w[cve bug-bounty].include?(collection[:kind])

    (extra_tags + about_tag_labels(entry["tags"]))
      .map(&:to_s)
      .reject(&:blank?)
      .uniq { |tag| tag.downcase }
      .sort_by { |tag| ContentRepository.filter_tag_sort_key(tag) }
  end

  def about_entry_icon(entry, collection)
    entry["icon"].presence || about_collection_default_icon(collection[:kind], entry)
  end

  def about_collection_default_icon(kind, entry)
    title = entry["title"].to_s.downcase

    case kind
    when "cve"
      "other/cve.svg"
    when "bug-bounty"
      "other/bug-bounty.svg"
    when "certificate"
      "other/certificate.svg"
    when "talk"
      "other/talk-slides.png"
    when "achievement"
      "other/achievement.svg"
    when "challenge"
      "ctf/kitctf.png"
    else
      return "other/talk-slides.png" if title.match?(/\btalk\b|intro/)
      return "other/certificate.svg" if title.match?(/certif|cpts/)

      "other/achievement.svg"
    end
  end

  def about_entry_timeline_link(entry, id, collection)
    if collection[:kind] == "challenge"
      entry["url"].presence || about_first_local_tag_url(entry["tags"]) || "/about##{id}"
    else
      "/about##{id}"
    end
  end

  def about_first_local_tag_url(tags)
    Array(tags).filter_map do |tag|
      next unless tag.respond_to?(:to_h)

      url = tag.to_h["url"].presence || tag.to_h[:url].presence
      url if url.to_s.start_with?("/")
    end.first
  end

  def about_published_time(entry, path)
    latest_timeline_time(entry) ||
      repository.file_time(path)
  end

  def about_card_display_date(entry, published)
    latest_timeline = latest_timeline_time(entry)
    return latest_timeline.strftime("%Y-%m-%d") if latest_timeline
    return "TBA" if entry["title"].to_s.match?(/\bTBA\b/i)

    published.strftime("%Y-%m-%d")
  end

  def about_timeline_event_display_date(event, published)
    event["date"].presence || published.strftime("%Y-%m-%d")
  end

  def latest_timeline_time(entry)
    Array(entry["timeline"]).filter_map do |item|
      repository.parsed_time(item["date"], fallback: nil)
    end.max
  end

  def search_text_for(values)
    values.flatten.filter_map { |value| flatten_text(value) }.join(" ").squish.downcase
  end

  def flatten_text(value)
    case value
    when Hash
      value.values.filter_map { |entry| flatten_text(entry) }.join(" ")
    when Array
      value.filter_map { |entry| flatten_text(entry) }.join(" ")
    when Time
      value.strftime("%Y-%m-%d")
    else
      value.to_s
    end
  end

  def about_tag_labels(tags)
    Array(tags).filter_map do |tag|
      if tag.respond_to?(:to_h)
        tag.to_h["label"].presence || tag.to_h[:label].presence
      else
        tag.to_s.presence
      end
    end
  end

  attr_reader :repository
end
