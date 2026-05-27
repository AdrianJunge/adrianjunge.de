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
      label: "Created challenge",
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
      path: ApplicationController::ABOUTME_ACHIEVEMENTS_PATH,
      kind: "achievement",
      label: "Achievement",
      section: "achievements",
      featured: false
    }
  ].freeze

  def all_items
    @all_items ||= (post_items + about_items).sort_by { |item| -item[:published].to_i }
  end

  def timeline_groups
    grouped = all_items.group_by { |item| item[:published].year }
    grouped.keys.sort.reverse.map do |year|
      [ year, grouped[year].sort_by { |item| -item[:published].to_i } ]
    end
  end

  def featured_items(limit = 3)
    candidates = [
      latest_featured_about("cve") { |item| item[:cve_id].present? },
      latest_featured_about("bug-bounty") { |item| meaningful_description?(item) },
      latest_post { |item| item[:writeup_winner].present? },
      latest_featured_about("certificate") { |item| meaningful_description?(item) },
      latest_featured_about("challenge") { |item| meaningful_description?(item) }
    ].compact

    candidates.uniq { |item| item[:id] }.sort_by { |item| -item[:published].to_i }.first(limit)
  end

  private

  def post_items
    @post_items ||= ctf_items + blog_items
  end

  def ctf_items
    ctf_metadata = read_json_object(ApplicationController::CTF_INFO_PATH)

    ctf_metadata.flat_map do |ctf_key, ctf_info|
      directory = ctf_info["terminal_path"].presence || ctf_key.downcase

      Dir.glob(ApplicationController::BASE_PATH.join(directory, "*.md")).filter_map do |file_path|
        parsed = parse_markdown(File.read(file_path))
        next unless parsed

        metadata = parsed.front_matter || {}
        slug = File.basename(file_path, ".md")
        title = metadata["title"].presence || slug.humanize
        published = parsed_time(metadata["published"], fallback: file_time(file_path, metadata["year"]))
        categories = Array(metadata["categories"]).map(&:to_s).reject(&:blank?)
        winner = WriteupWinner.from_metadata(metadata)
        filter_tags = categories
        filter_tags << WriteupWinner::FILTER_LABEL if winner

        content_item(
          id: "ctf-#{directory.parameterize}-#{slug.parameterize}",
          kind: "writeup",
          label: "CTF writeup",
          source: ctf_key,
          title: title,
          description: metadata["description"].to_s,
          published: published,
          display_date: published.strftime("%Y-%m-%d"),
          link: "/ctf/#{directory}/#{slug}",
          tags: filter_tags,
          search_parts: [ ctf_key, title, metadata, parsed.content ],
          logo: ctf_info["logo"],
          writeup_winner: winner
        )
      end
    end
  end

  def blog_items
    blog_metadata = read_json_object(ApplicationController::BLOG_INFO_PATH)

    Dir.glob(ApplicationController::BLOG_BASE_PATH.join("*.md")).filter_map do |file_path|
      parsed = parse_markdown(File.read(file_path))
      next unless parsed

      metadata = parsed.front_matter || {}
      slug = File.basename(file_path, ".md")
      blog_info = blog_metadata[slug] || {}
      title = blog_info["title"].presence || metadata["title"].presence || slug.humanize
      category = blog_info["category"].presence || "Post"
      published = parsed_time(metadata["published"], fallback: file_time(file_path, metadata["year"]))
      categories = Array(metadata["categories"]).map(&:to_s).reject(&:blank?)

      content_item(
        id: "blog-#{slug.parameterize}",
        kind: "blog",
        label: "Blog post",
        source: category,
        title: title,
        description: metadata["description"].to_s,
        published: published,
        display_date: published.strftime("%Y-%m-%d"),
        link: "/blog/#{slug}",
        tags: categories,
        search_parts: [ category, title, metadata, parsed.content ],
        logo: blog_info["logo"]
      )
    end
  end

  def about_items
    ABOUT_COLLECTIONS.flat_map do |collection|
      entries = read_json_array(collection[:path])

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
        link: "/about##{id}",
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

      published = parsed_time(event["date"], fallback: about_published_time(entry, collection[:path]))
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
    tags = ([ attrs[:label] ] + Array(attrs[:tags])).map(&:to_s).reject(&:blank?).uniq { |tag| tag.downcase }

    attrs.merge(
      tags: tags,
      search_text: search_text_for(attrs.values + tags)
    )
  end

  def latest_featured_about(kind)
    all_items.find do |item|
      item[:kind] == kind && item[:featured] && yield(item)
    end
  end

  def latest_post
    all_items.find do |item|
      %w[writeup blog].include?(item[:kind]) && yield(item)
    end
  end

  def meaningful_description?(item)
    item[:description].present? && !item[:title].to_s.match?(/\bTBA\b/i)
  end

  def about_description(entry)
    entry["short_summary"].presence ||
      entry["summary"].presence ||
      entry["impact"].presence ||
      Array(entry["details"]).map(&:to_s).find(&:present?) ||
      ""
  end

  def about_tags(entry, label)
    [
      label,
      entry["project"],
      entry["category"],
      entry["severity"],
      entry["cve_id"]
    ].map(&:to_s).reject(&:blank?).uniq { |tag| tag.downcase }
  end

  def about_published_time(entry, path)
    latest_timeline_time(entry) ||
      parsed_time(entry["date"], fallback: file_time(path))
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
      parsed_time(item["date"], fallback: nil)
    end.max
  end

  def file_time(path, year = nil)
    year_value = year.to_s[/\d{4}/]
    return Time.zone.local(year_value.to_i, 12, 31) if year_value

    File.exist?(path) ? File.mtime(path) : Time.zone.now
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

  def parse_markdown(content)
    FrontMatterParser::Parser.new(:md).call(content)
  rescue StandardError
    nil
  end

  def read_json_array(path)
    data = JSON.parse(File.read(path))
    data.is_a?(Array) ? data : []
  rescue StandardError
    []
  end

  def read_json_object(path)
    data = JSON.parse(File.read(path))
    data.is_a?(Hash) ? data : {}
  rescue StandardError
    {}
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
end
