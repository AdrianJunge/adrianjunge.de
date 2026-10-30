require "cgi"

class ContentIndex
  EVENT_BASED_ABOUT_KINDS = %w[talk achievement].freeze

  ABOUT_COLLECTIONS = [
    {
      path: ContentConfiguration::ABOUTME_CVES_PATH,
      kind: "cve",
      label: "CVE",
      section: "cves"
    },
    {
      path: ContentConfiguration::ABOUTME_CHALLENGES_PATH,
      kind: "challenge",
      label: AuthoredChallenge::FILTER_LABEL,
      section: "my-challenges"
    },
    {
      path: ContentConfiguration::ABOUTME_CERTIFICATES_PATH,
      kind: "certificate",
      label: "Certificate",
      section: "certificates"
    },
    {
      path: ContentConfiguration::ABOUTME_TALKS_PATH,
      kind: "talk",
      label: "Talk",
      section: "talks"
    },
    {
      path: ContentConfiguration::ABOUTME_ACHIEVEMENTS_PATH,
      kind: "achievement",
      label: "Achievement",
      section: "achievements"
    }
  ].freeze

  def initialize(repository: ContentRepository.new)
    @repository = repository
  end

  def all_items
    @all_items ||= repository.cached_collection(:timeline) do
      merged_timeline_items(post_items + about_items + timeline_event_items).sort_by { |item| -item[:published].to_i }
    end
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
        display_date: post_display_date(post),
        link: post[:link],
        tags: [ post[:which] ] + repository.metadata_tags(metadata),
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
        display_date: post_display_date(post),
        link: post[:link],
        tags: [ post[:which] ] + repository.metadata_tags(metadata),
        timeline_group: metadata["timeline_group"].presence,
        logo: post[:logo],
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

  def timeline_event_items
    repository.timeline_events.map do |event|
      date = event.fetch("date")
      period_end = ContentDate.bounds(event["end_date"])&.last
      published = period_end ? ContentDate.bounds(date).first : repository.parsed_time(date, fallback: nil)
      content_item(
        id: "timeline-event-#{event.fetch('id')}",
        kind: "timeline_event",
        source: "Timeline",
        title: event.fetch("title"),
        description: event["summary"].to_s,
        published: published,
        filter_years: (published.year..(period_end || published).year).to_a,
        display_date: repository.timeline_event_display_date(event),
        date_datetime: date.match?(ContentDate::MONTH) ? date : published.iso8601,
        link: event["url"].presence,
        url: "/timeline#timeline-event-#{event.fetch('id')}",
        tags: about_tag_labels(event["tags"]),
        logo: event["icon"].presence
      )
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
      tag_source = event.key?("tags") ? entry.merge("tags" => event["tags"]) : entry
      tags = about_tags(tag_source, collection) + [ entry["title"] ]

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
        timeline_group: event["timeline_group"].presence,
        logo: event["icon"].presence || about_entry_icon(entry, collection)
      )
    end
  end

  def content_item(**attrs)
    tags = ContentTagTaxonomy.canonical_values([ attrs[:label] ] + Array(attrs[:tags]))
    kind_labels = timeline_content_type_labels(tags)

    attrs.merge(
      filter_years: attrs[:filter_years] || [ attrs[:published].year ],
      kind_labels: kind_labels,
      tags: tags,
      search_text: search_text_for([ attrs[:title], attrs[:description], attrs[:source], attrs[:display_date], tags.map { |tag| ContentTagTaxonomy.canonical_label(tag) } ])
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
      filter_years: [ published.year ],
      display_date: date_source[:display_date].presence || primary[:display_date],
      logo: primary[:logo].presence || group.find { |item| item[:logo].present? }&.dig(:logo),
      kind_labels: kind_labels,
      tags: tags,
      search_text: search_text,
      merged_item_ids: group.map { |item| item[:id] }
    )
  end

  def timeline_merge_key(item)
    return if item[:kind] == "timeline_event"

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

    tags = about_tag_labels(entry["tags"]).map do |tag|
      if %w[cve bug-bounty].include?(collection[:kind]) && ContentSeverityTag.recognized?(tag)
        ContentTagTaxonomy.canonical_value(tag, type: :severity)
      else
        ContentTagTaxonomy.canonical_value(tag)
      end
    end

    (extra_tags + tags)
      .map(&:to_s)
      .reject(&:blank?)
      .uniq { |tag| tag.downcase }
      .sort_by { |tag| ContentRepository.filter_tag_sort_key(tag) }
  end

  def about_entry_icon(entry, collection)
    entry["icon"].presence || ContentIconRegistry.for(collection[:kind], title: entry["title"])
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

  def post_display_date(post)
    metadata = post[:metadata] || {}
    ContentDate.display_label(metadata["published"]) ||
      ContentDate.display_label(metadata["year"]) ||
      fallback_display_date(post[:published])
  end

  def about_card_display_date(entry, published)
    latest_date = latest_timeline_date(entry)
    return ContentDate.display_label(latest_date) if latest_date
    return "TBA" if entry["title"].to_s.match?(/\bTBA\b/i)

    fallback_display_date(published)
  end

  def about_timeline_event_display_date(event, published)
    ContentDate.display_label(event["date"]) || fallback_display_date(published)
  end

  def latest_timeline_time(entry)
    repository.parsed_time(latest_timeline_date(entry), fallback: nil)
  end

  def latest_timeline_date(entry)
    Array(entry["timeline"]).filter_map do |item|
      parsed = repository.parsed_time(item["date"], fallback: nil)
      [ parsed, item["date"] ] if parsed
    end.max_by(&:first)&.last
  end

  def fallback_display_date(published)
    published == ContentDate::EPOCH ? "TBA" : ContentDate.display_label(published)
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
