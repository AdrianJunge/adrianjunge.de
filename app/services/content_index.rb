require "cgi"

class ContentIndex
  ABOUT_COLLECTIONS = [
    {
      path: ApplicationController::ABOUTME_CVES_PATH,
      kind: "cve",
      label: "CVE",
      section: "cves",
      featured: true
    },
    {
      path: ApplicationController::ABOUTME_BUG_BOUNTIES_PATH,
      kind: "bug-bounty",
      label: "Bug bounty",
      section: "bug-bounties",
      featured: true
    },
    {
      path: ApplicationController::ABOUTME_CHALLENGES_PATH,
      kind: "challenge",
      label: AuthoredChallenge::FILTER_LABEL,
      section: "my-challenges",
      featured: true
    },
    {
      path: ApplicationController::ABOUTME_CERTIFICATES_PATH,
      kind: "certificate",
      label: "Certificate",
      section: "certificates",
      featured: true
    },
    {
      path: ApplicationController::ABOUTME_TALKS_PATH,
      kind: "talk",
      label: "Talk",
      section: "talks",
      featured: false
    },
    {
      path: ApplicationController::ABOUTME_ACHIEVEMENTS_PATH,
      kind: "achievement",
      label: "Achievement",
      section: "achievements",
      featured: false
    }
  ].freeze

  def initialize(repository: ContentRepository.new)
    @repository = repository
  end

  def all_items
    @all_items ||= merged_timeline_items(post_items + about_items).sort_by { |item| -item[:published].to_i }
  end

  def featured_items(limit = 3)
    featured_about_items(limit)
  end

  def featured_about_items(limit = 3)
    candidates = [
      latest_featured_about_entry("cve") { |item| item[:entry]["cve_id"].present? },
      latest_featured_about_entry("bug-bounty") { |item| meaningful_description?(item) },
      latest_featured_about_entry("certificate") { |item| meaningful_description?(item) },
      latest_featured_about_entry("challenge") { |item| meaningful_description?(item) }
    ].compact

    candidates.uniq { |item| item[:id] }.sort_by { |item| -item[:published].to_i }.first(limit)
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
        if collection[:kind] == "achievement"
          achievement_event_items(entry, collection)
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
    display_date = about_display_date(entry, published)
    title = entry["title"].presence || entry["cve_id"].presence || entry["project"].presence || collection[:label]
    description = about_description(entry)
    tags = about_tags(entry, collection[:label])
    link = about_entry_timeline_link(entry, id, collection)

    [
      content_item(
        id: "about-#{collection[:kind]}-#{id.parameterize}",
        kind: collection[:kind],
        label: collection[:label],
        source: entry["project"].presence || entry["category"].presence || "About",
        title: title,
        description: description,
        published: published,
        display_date: display_date,
        link: link,
        tags: tags,
        search_parts: [ collection[:label], entry ],
        cve_id: entry["cve_id"].presence,
        severity: entry["severity"].presence,
        project: entry["project"].presence,
        featured: collection[:featured]
      )
    ]
  end

  def achievement_event_items(entry, collection)
    parent_id = entry["id"].presence || entry["title"].to_s.parameterize
    return [] if parent_id.blank?

    events = Array(entry["events"]).select { |event| event.is_a?(Hash) && event["title"].present? }
    return about_entry_item(entry, collection) if events.empty?

    events.filter_map do |event|
      event_id = event["id"].presence || "#{parent_id}-#{event["date"]}-#{event["title"]}".parameterize
      next if event_id.blank?

      published = repository.parsed_time(event["date"], fallback: about_published_time(entry, collection[:path]))
      description = event["summary"].presence || about_description(entry)
      title = event["title"].presence || entry["title"].presence || collection[:label]
      tags = about_tags(entry, collection[:label]) + [ entry["title"] ]

      content_item(
        id: "about-#{collection[:kind]}-#{event_id.parameterize}",
        kind: collection[:kind],
        label: collection[:label],
        source: entry["title"].presence || entry["category"].presence || "About",
        title: title,
        description: description,
        published: published,
        display_date: about_display_date(event, published),
        link: "/about##{event_id}",
        tags: tags,
        search_parts: [ collection[:label], entry, event ],
        featured: collection[:featured]
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
      kind_labels: kind_labels,
      tags: tags,
      search_text: search_text,
      merged_item_ids: group.map { |item| item[:id] }
    )
  end

  def timeline_merge_key(item)
    link = item[:link].to_s
    return if link.blank?

    CGI.unescape(link)
  end

  def timeline_content_type_labels(tags)
    ContentTagTaxonomy.canonical_values(tags)
                      .select { |tag| ContentTagTaxonomy.content_type?(tag) }
                      .map { |tag| { label: tag, tag_value: tag } }
  end

  def latest_featured_about_entry(kind)
    featured_about_entry_items.find do |item|
      item[:kind] == kind && yield(item)
    end
  end

  def featured_about_entry_items
    @featured_about_entry_items ||= ABOUT_COLLECTIONS.select { |collection| collection[:featured] }.flat_map do |collection|
      about_collection_entries(collection).filter_map do |entry|
        id = entry["id"].presence || entry["title"].to_s.parameterize
        next if id.blank?

        {
          id: "about-#{collection[:kind]}-#{id.parameterize}",
          kind: collection[:kind],
          label: collection[:label],
          entry: entry,
          published: about_published_time(entry, collection[:path])
        }
      end
    end.sort_by { |item| -item[:published].to_i }
  end

  def meaningful_description?(item)
    if item[:entry].present?
      item[:entry]["summary"].present? && !item[:entry]["title"].to_s.match?(/\bTBA\b/i)
    else
      item[:description].present? && !item[:title].to_s.match?(/\bTBA\b/i)
    end
  end

  def about_description(entry)
    entry["short_summary"].presence ||
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

  def about_tags(entry, label)
    [
      label,
      entry["project"],
      entry["category"],
      entry["severity"],
      entry["cve_id"],
      entry["cwe_id"],
      WriteupDifficulty.filter_label_for(entry)
    ].map(&:to_s).reject(&:blank?).uniq { |tag| tag.downcase }.sort_by { |tag| ContentRepository.filter_tag_sort_key(tag) }
  end

  def about_entry_timeline_link(entry, id, collection)
    if collection[:kind] == "challenge"
      entry["card_url"].presence || entry["title_url"].presence || "/about##{id}"
    else
      "/about##{id}"
    end
  end

  def about_published_time(entry, path)
    latest_timeline_time(entry) ||
      repository.parsed_time(entry["date"], fallback: repository.file_time(path))
  end

  def about_display_date(entry, published)
    latest_timeline = latest_timeline_time(entry)
    return latest_timeline.strftime("%Y-%m-%d") if latest_timeline

    raw_date = entry["date"].to_s.strip
    return raw_date if raw_date.present?
    return "TBA" if entry["title"].to_s.match?(/\bTBA\b/i)

    published.strftime("%Y-%m-%d")
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

  attr_reader :repository
end
