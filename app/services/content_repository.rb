require "cgi"
require "digest"

class ContentRepository
  READING_WORDS_PER_MINUTE = 225
  HIDDEN_CONTENT_KEYS = %w[hidden draft wip].freeze
  HIDDEN_CONTENT_VALUES = %w[1 true yes y on].freeze
  BLOG_SLUG_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  CTF_EVENT_SLUG_PATTERN = BLOG_SLUG_PATTERN
  CTF_WRITEUP_SLUG_PATTERN = /\A[A-Za-z0-9]+(?:[ _-][A-Za-z0-9]+)*\z/
  CTF_ASSET_NAME_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/
  CTF_ASSET_ID_PATTERN = /\A[0-9a-f]{64}\z/
  EMPTY_COLLECTION = [].freeze
  CTF_ASSET_KINDS = {
    challenge: {
      root: :ctf_challenge_files_path,
      extension: "zip",
      content_type: "application/zip",
      disposition: "attachment"
    },
    writeup: {
      root: :ctf_pdf_writeups_path,
      extension: "pdf",
      content_type: "application/pdf",
      disposition: "inline"
    }
  }.freeze
  FEED_SOURCES = [
    {
      key: :blog,
      label: "Blog post",
      method: :blog_posts
    },
    {
      key: :ctf,
      label: "CTF writeup",
      method: :ctf_posts
    }
  ].freeze

  class InvalidContentPath < StandardError; end
  class InvalidContent < StandardError; end

  def initialize(
    configuration: ContentConfiguration.new,
    ctf_base_path: configuration.path(:BASE_PATH),
    blog_base_path: configuration.path(:BLOG_BASE_PATH),
    ctf_challenge_files_path: configuration.path(:CTF_CHALLENGE_FILES_PATH),
    ctf_pdf_writeups_path: configuration.path(:CTF_PDF_WRITEUPS_PATH),
    ctf_metadata_data: nil,
    blog_metadata_data: nil
  )
    @configuration = configuration
    @ctf_base_path = Pathname(ctf_base_path)
    @blog_base_path = Pathname(blog_base_path)
    @ctf_challenge_files_path = Pathname(ctf_challenge_files_path)
    @ctf_pdf_writeups_path = Pathname(ctf_pdf_writeups_path)
    @ctf_metadata = ctf_metadata_data.deep_stringify_keys unless ctf_metadata_data.nil?
    @blog_metadata = blog_metadata_data.deep_stringify_keys unless blog_metadata_data.nil?
  end

  def self.filter_tag_sort_key(value)
    ContentTagTaxonomy.sort_key(value)
  end

  def about_markdown
    @about_markdown ||= read_file(configuration.path(:ABOUTME_TEXT_PATH))
  end

  def about_entries(path, include_hidden: false)
    cache_key = [ path.to_s, include_hidden ]
    about_entries_cache[cache_key] ||= begin
      entries = normalize_about_entries(read_json_array(path), path: path)
      include_hidden ? entries : sorted_about_entries(visible_about_entries(entries, path), fallback_path: path)
    end
  end

  def blog_metadata
    @blog_metadata ||= read_json_object(configuration.path(:BLOG_INFO_PATH))
  end

  def ctf_metadata
    @visible_ctf_metadata ||= begin
      metadata = @ctf_metadata ||= read_json_object(configuration.path(:CTF_INFO_PATH))
      metadata.reject { |_name, entry| hidden_content?(entry) }
    end
  end

  def ctf_events
    @ctf_events ||= begin
      events = ctf_metadata.map do |name, metadata|
        slug = metadata["terminal_path"].presence || name.downcase
        validate_identifier!(slug, CTF_EVENT_SLUG_PATTERN, "CTF event slug")

        {
          slug: slug,
          name: name,
          metadata: metadata
        }
      end

      unique_index(events, :slug, "CTF event slug")
      events
    end
  end

  def ctf_event(slug)
    ctf_events_by_slug[slug.to_s]
  end

  def ctf_posts_for_event(slug)
    ctf_posts_by_event.fetch(slug.to_s, EMPTY_COLLECTION)
  end

  def ctf_post(event_slug, slug)
    ctf_posts_by_key[[ event_slug.to_s, slug.to_s ]]
  end

  def blog_post(slug)
    blog_posts_by_slug[slug.to_s]
  end

  def ctf_asset(id)
    asset_id = id.to_s
    return unless asset_id.match?(CTF_ASSET_ID_PATTERN)

    ctf_asset_catalog[:by_id][asset_id]
  end

  def ctf_assets
    ctf_asset_catalog[:by_id].values
  end

  def ctf_asset_for(post, kind)
    return unless post

    ctf_asset_catalog[:by_post][[ post[:directory].to_s, post[:slug].to_s, kind.to_sym ]]
  end

  def ctf_posts(link_prefix: "/ctf")
    ctf_posts_cache[link_prefix] ||= ctf_events.flat_map do |event|
      trusted_files(
        root: ctf_base_path,
        pattern: ctf_base_path.join(event[:slug], "*.md")
      ).filter_map do |discovered_file|
        slug = File.basename(discovered_file[:candidate], ".md")
        validate_identifier!(slug, CTF_WRITEUP_SLUG_PATTERN, "CTF writeup slug")

        document = markdown_document(discovered_file[:canonical])
        meta = document[:metadata].deep_dup
        next if hidden_content?(meta)

        title = meta["title"].presence || slug.humanize
        published = parsed_time(meta["published"], fallback: file_time(discovered_file[:canonical], legacy_year(meta)))

        {
          type: "ctf",
          which: event[:name],
          item: event[:name],
          directory: event[:slug],
          slug: slug,
          title: title,
          published: published,
          modified: modified_time(meta, published),
          link: encoded_local_path("#{link_prefix}/#{event[:slug]}/#{slug}"),
          description: meta["description"].to_s,
          categories: normalized_metadata_categories(meta),
          logo: event[:metadata]["logo"],
          content: document[:content],
          body: document[:body],
          source_path: discovered_file[:canonical],
          word_count: meta["word_count"],
          word_count_label: meta["word_count_label"],
          reading_time_minutes: meta["reading_time_minutes"],
          reading_time_label: meta["reading_time_label"],
          metadata: meta.merge("ctf_event_url" => event[:metadata]["website"])
        }
      end
    end.sort_by { |item| -item[:published].to_i }.tap do |posts|
      unique_index(posts, ->(post) { [ post[:directory], post[:slug] ] }, "CTF writeup path")
    end
  end

  def blog_posts
    @blog_posts ||= begin
      metadata = blog_metadata
      metadata.each_key { |slug| validate_identifier!(slug, BLOG_SLUG_PATTERN, "blog post slug") }

      trusted_files(
        root: blog_base_path,
        pattern: blog_base_path.join("*.md")
      ).filter_map do |discovered_file|
        slug = File.basename(discovered_file[:candidate], ".md")
        next unless metadata.key?(slug)

        validate_identifier!(slug, BLOG_SLUG_PATTERN, "blog post slug")
        document = markdown_document(discovered_file[:canonical])
        meta = document[:metadata].deep_dup
        blog_info = metadata.fetch(slug)
        next if hidden_content?(meta) || hidden_content?(blog_info)

        category = blog_info["category"] || "POST"
        title = blog_info["title"].presence || meta["title"].presence || slug.humanize
        meta = meta.merge("title" => title, "logo" => blog_info["logo"], "category" => category)
        published = parsed_time(meta["published"], fallback: file_time(discovered_file[:canonical], legacy_year(meta)))

        {
          type: "blog",
          which: category,
          item: slug,
          slug: slug,
          title: title,
          published: published,
          modified: modified_time(meta, published),
          link: "/blog/#{slug}",
          description: meta["description"].to_s,
          topic: meta["topic"].to_s,
          categories: normalized_metadata_categories(meta),
          content: document[:content],
          body: document[:body],
          logo: blog_info["logo"],
          source_path: discovered_file[:canonical],
          word_count: meta["word_count"],
          word_count_label: meta["word_count_label"],
          reading_time_minutes: meta["reading_time_minutes"],
          reading_time_label: meta["reading_time_label"],
          metadata: meta
        }
      end.sort_by { |item| -item[:published].to_i }.tap do |posts|
        unique_index(posts, :slug, "blog post slug")
      end
    end
  end

  def post_count
    ctf_posts.length + blog_posts.length
  end

  def authored_challenges(link_prefix: "/ctf")
    authored_challenges_cache[link_prefix] ||= begin
      configured_challenges = about_entries(ContentConfiguration::ABOUTME_CHALLENGES_PATH)
      configured_challenges.presence || authored_challenges_from_ctf_metadata(link_prefix: link_prefix)
    end
  end

  def authored_challenges_from_ctf_metadata(link_prefix: "/ctf")
    ctf_posts(link_prefix: link_prefix).filter_map do |post|
      authored = AuthoredChallenge.from_metadata(post[:metadata] || {})
      next unless authored

      event = authored[:event].presence || authored_challenge_event(post)
      event_url = authored[:event_url].presence ||
                  metadata_event_url(post[:metadata]) ||
                  ctf_metadata.dig(post[:which], "website")
      summary = authored[:summary].presence || authored_challenge_summary(post[:description], event)
      date = authored[:date].presence || post[:published].strftime("%Y-%m-%d")
      link = encoded_local_path(post[:link])
      difficulty = WriteupDifficulty.from_metadata(post[:metadata] || {})

      {
        "id" => authored[:id].presence || post[:slug].parameterize,
        "title" => post[:title],
        "icon" => post[:logo],
        "url" => link,
        "summary" => summary,
        "tags" => [
          { "label" => event, "url" => event_url },
          difficulty[:label],
          { "label" => "Writeup", "url" => link }
        ].filter_map do |tag|
          if tag.is_a?(Hash)
            tag["label"].present? ? tag.compact : nil
          else
            tag.presence
          end
        end,
        "timeline" => [
          {
            "date" => date,
            "title" => event.present? ? "Published at #{event}." : "Published challenge."
          }
        ]
      }
    end
  end

  def total_post_reading_time_minutes
    post_reading_time_minutes(ctf_posts + blog_posts)
  end

  def post_reading_time_minutes(posts)
    Array(posts).sum { |post| post[:reading_time_minutes].to_i }
  end

  def format_reading_time(minutes)
    "#{minutes.to_i} min read"
  end

  def format_word_count(words)
    count = words.to_i
    "#{count} #{count == 1 ? "word" : "words"}"
  end

  def feed_posts(source_keys: nil)
    keys = Array(source_keys).compact.map { |key| key.to_sym }
    sources = keys.empty? ? FEED_SOURCES : FEED_SOURCES.select { |source| keys.include?(source[:key]) }

    sources.flat_map do |source|
      public_send(source[:method]).map { |post| feed_post_from(post, source) }
    end.sort_by { |item| -item[:published].to_i }
  end

  def metadata_year(metadata)
    published = metadata["published"].presence
    return parsed_time(published, fallback: nil)&.year if published

    legacy_year(metadata)&.to_i
  end

  def ctf_event_year(metadata)
    year = metadata["ctf_year"].presence ||
           metadata["event_year"].presence ||
           legacy_year(metadata)
    year.to_s[/\d{4}/] || metadata_year(metadata)
  end

  def metadata_tags(metadata = nil, include_difficulty: true, **metadata_keywords)
    metadata = metadata_keywords if metadata.nil? && metadata_keywords.any?
    metadata ||= {}
    difficulty_label = WriteupDifficulty.filter_label_for(metadata) if include_difficulty

    difficulty_tag = ContentTagTaxonomy.canonical_value(difficulty_label, type: :difficulty) if difficulty_label
    sort_metadata_tags(Array(metadata["categories"]) + [ WriteupWinner.filter_label_for(metadata), AuthoredChallenge.filter_label_for(metadata), difficulty_tag ])
      .map(&:to_s)
      .reject(&:blank?)
  end

  def timeline_event_count(entries)
    Array(entries).sum do |entry|
      next 0 if hidden_content?(entry)

      timeline = Array(entry["timeline"]).select { |event| event.is_a?(Hash) && event["date"].present? }
      visible_timeline = timeline.reject { |event| hidden_content?(event) }
      timeline.any? ? visible_timeline.length : 1
    end
  end

  def sorted_about_entries(entries, fallback_path: nil)
    Array(entries).sort_by do |entry|
      [ -about_entry_time(entry, fallback_path: fallback_path).to_i, entry["id"].to_s, entry["title"].to_s ]
    end
  end

  def about_entry_time(entry, fallback_path: nil)
    parsed_time(entry["date"], fallback: nil) ||
      latest_nested_entry_time(entry, "timeline") ||
      (file_time(fallback_path) if fallback_path.present?)
  end

  def hidden_content?(metadata)
    return false unless metadata.respond_to?(:[])

    HIDDEN_CONTENT_KEYS.any? do |key|
      hidden_content_value?(metadata[key])
    end
  end

  def sort_metadata_tags(values)
    ContentTagTaxonomy.canonical_values(values)
      .uniq { |value| value.downcase }
      .sort_by { |value| self.class.filter_tag_sort_key(value) }
  end

  def parse_markdown(content, path: "Markdown input")
    parsed = FrontMatterParser::Parser.new(:md).call(content)
    unless parsed.front_matter.is_a?(Hash)
      raise InvalidContent, "#{path}: front matter must be a mapping"
    end

    parsed
  rescue Psych::Exception => error
    raise InvalidContent, "#{path}: invalid front matter: #{error.message}"
  end

  def markdown_document(path)
    ContentSnapshot.fetch(path, kind: :markdown) do |content|
      parsed = parse_markdown(content, path: path)
      errors = ContentJsonSchemas.metadata_errors(parsed.front_matter)
      if errors.any?
        raise InvalidContent, "#{path}: #{errors.map { |error| "#{error["data_pointer"]}: #{error["type"]}" }.join(', ')}"
      end
      { content: content, body: parsed.content, metadata: post_metadata_from(parsed) }
    end
  end

  def post_metadata_from(parsed)
    metadata = (parsed&.front_matter || {}).deep_stringify_keys
    metadata["categories"] = normalized_metadata_categories(metadata) if metadata.key?("categories")
    body = parsed&.content.to_s
    word_count = markdown_word_count(body)
    reading_time_minutes = reading_time_minutes_for_word_count(word_count)

    metadata.merge(
      "has_math" => metadata.fetch("has_math", false),
      "word_count" => word_count,
      "word_count_label" => format_word_count(word_count),
      "reading_time_minutes" => reading_time_minutes,
      "reading_time_label" => format_reading_time(reading_time_minutes)
    )
  end

  def reading_time_minutes(markdown)
    reading_time_minutes_for_word_count(markdown_word_count(markdown))
  end

  def reading_time_label(markdown)
    format_reading_time(reading_time_minutes(markdown))
  end

  def parsed_time(value, fallback:)
    ContentDate.parse(value, fallback: fallback)
  end

  def modified_time(metadata, published)
    parsed_time(metadata["updated"].presence || metadata["modified"], fallback: published)
  end

  def file_time(path, year = nil)
    year_value = year.to_s[/\d{4}/]
    return Time.zone.local(year_value.to_i, 12, 31) if year_value

    path = configuration.resolve(path)
    File.exist?(path) ? File.mtime(path) : ContentDate::EPOCH
  end

  def read_json_array(path)
    data = parse_json_content(path)
    data.is_a?(Array) ? data : []
  end

  def read_json_object(path)
    data = parse_json_content(path)
    data.is_a?(Hash) ? data : {}
  end

  def normalize_about_entries(entries, path:)
    ids = {}
    Array(entries).map do |raw_entry|
      entry = raw_entry.deep_stringify_keys
      entry["id"] = entry["id"].presence || entry["title"].to_s.parameterize
      register_fragment!(ids, entry["id"], path)
      if entry.key?("timeline")
        entry["timeline"] = Array(entry["timeline"]).map do |raw_event|
          event = raw_event.dup
          event["id"] = event["id"].presence || "#{entry["id"]}-#{event["date"]}-#{event["title"]}".parameterize
          register_fragment!(ids, event["id"], path)
          event
        end
      end
      entry
    end
  end

  private

  attr_reader :ctf_base_path,
              :blog_base_path,
              :ctf_challenge_files_path,
              :ctf_pdf_writeups_path,
              :configuration

  def ctf_events_by_slug
    @ctf_events_by_slug ||= unique_index(ctf_events, :slug, "CTF event slug")
  end

  def ctf_posts_by_event
    @ctf_posts_by_event ||= ctf_posts.group_by { |post| post[:directory] }
  end

  def ctf_posts_by_key
    @ctf_posts_by_key ||= unique_index(
      ctf_posts,
      ->(post) { [ post[:directory], post[:slug] ] },
      "CTF writeup path"
    )
  end

  def blog_posts_by_slug
    @blog_posts_by_slug ||= unique_index(blog_posts, :slug, "blog post slug")
  end

  def ctf_asset_catalog
    @ctf_asset_catalog ||= begin
      by_id = {}
      by_post = {}

      ctf_posts.each do |post|
        metadata = post[:metadata] || {}
        year = ctf_event_year(metadata).to_s
        asset_name = metadata["challengefiles"].to_s
        next unless year.match?(/\A\d{4}\z/)
        next unless valid_asset_name?(asset_name)

        CTF_ASSET_KINDS.each do |kind, definition|
          asset_root = send(definition[:root])
          candidate = asset_root.join(
            post[:directory],
            year,
            "#{asset_name}.#{definition[:extension]}"
          )
          canonical = TrustedContentPath.file(root: asset_root, candidate: candidate)
          next unless canonical

          id = Digest::SHA256.hexdigest(
            [ kind, post[:directory], year, asset_name ].join("\0")
          )
          asset = {
            id: id,
            kind: kind,
            path: canonical,
            basename: candidate.basename.to_s,
            size: canonical.size,
            content_type: definition[:content_type],
            disposition: definition[:disposition]
          }

          if by_id.key?(id) && by_id[id][:path] != canonical
            raise InvalidContentPath, "Duplicate CTF asset identifier #{id.inspect}"
          end

          by_id[id] = asset
          by_post[[ post[:directory], post[:slug], kind ]] = asset
        end
      end

      { by_id: by_id, by_post: by_post }
    end
  end

  def trusted_files(root:, pattern:)
    Dir.glob(pattern.to_s).sort.filter_map do |candidate|
      canonical = TrustedContentPath.file(root: root, candidate: candidate)
      next unless canonical

      { candidate: candidate, canonical: canonical }
    end
  end

  def validate_identifier!(value, pattern, label)
    return value if value.to_s.match?(pattern)

    raise InvalidContentPath, "Invalid #{label}: #{value.inspect}"
  end

  def valid_asset_name?(value)
    value.match?(CTF_ASSET_NAME_PATTERN) && !%w[. ..].include?(value)
  end

  def unique_index(items, key, label)
    Array(items).each_with_object({}) do |item, index|
      item_key = key.respond_to?(:call) ? key.call(item) : item.fetch(key)
      raise InvalidContentPath, "Duplicate #{label}: #{item_key.inspect}" if index.key?(item_key)

      index[item_key] = item
    end
  end

  def visible_about_entries(entries, path)
    Array(entries).filter_map do |entry|
      next if hidden_content?(entry)

      visible_timeline = Array(entry["timeline"]).reject { |event| hidden_content?(event) }
      if path.to_s == ContentConfiguration::ABOUTME_ACHIEVEMENTS_PATH.to_s
        next if visible_timeline.empty?
      end
      if [ ContentConfiguration::ABOUTME_ACHIEVEMENTS_PATH.to_s, ContentConfiguration::ABOUTME_TALKS_PATH.to_s ].include?(path.to_s)
        visible_timeline = sorted_about_entries(visible_timeline, fallback_path: path)
      end

      entry.key?("timeline") ? entry.merge("timeline" => visible_timeline) : entry
    end
  end

  def hidden_content_value?(value)
    value == true || HIDDEN_CONTENT_VALUES.include?(value.to_s.strip.downcase)
  end

  def read_file(path)
    ContentSnapshot.fetch(path) { |content| content }
  end

  def parse_json_content(path)
    path = configuration.resolve(path)
    ContentSnapshot.fetch(path, kind: :json) do |content|
      data = JSON.parse(content, allow_comments: true)
      ContentJsonSchemas.validate!(configuration.schema_path(path), data)
      data
    end.deep_dup
  rescue JSON::ParserError => error
    raise InvalidContent, "#{path}: invalid JSON: #{error.message}"
  end

  def register_fragment!(ids, id, path)
    raise InvalidContent, "#{path}: missing fragment ID" if id.blank?
    raise InvalidContent, "#{path}: duplicate fragment ID #{id.inspect}" if ids.key?(id)

    ids[id] = true
  end

  def legacy_year(metadata)
    metadata["year"].presence
  end

  def markdown_word_count(markdown)
    text = markdown.to_s
    text = text.gsub(/!\[[^\]]*\]\([^)]+\)/, " ")
    text = text.gsub(/\[([^\]]+)\]\([^)]+\)/, "\\1")
    text = text.gsub(/<[^>]+>/, " ")

    text.scan(/[[:alnum:]][[:alnum:]_-]*/).length
  end

  def reading_time_minutes_for_word_count(word_count)
    [ (word_count / READING_WORDS_PER_MINUTE.to_f).ceil, 1 ].max
  end

  def latest_nested_entry_time(entry, key)
    Array(entry[key]).filter_map do |item|
      next unless item.respond_to?(:[])

      parsed_time(item["date"], fallback: nil)
    end.max
  end

  def authored_challenge_event(post)
    [ post.dig(:metadata, "ctf").presence || post[:which], ctf_event_year(post[:metadata] || {}) ].compact.join(" ")
  end

  def metadata_event_url(metadata)
    AuthoredChallenge.metadata_value(metadata || {}, "event_url", "event-url", "event_link", "event-link").presence
  end

  def authored_challenge_summary(description, event)
    [ description.to_s.presence, ("Published for #{event}." if event.present?) ].compact.join(" ")
  end

  def normalized_metadata_categories(metadata)
    ContentTagTaxonomy.canonical_values(Array(metadata["categories"]))
  end

  def encoded_local_path(path)
    path = path.to_s
    return path unless path.start_with?("/")

    path.split("/").map { |segment| CGI.escape(CGI.unescape(segment)).gsub("+", "%20") }.join("/")
  end

  def feed_post_from(post, source)
    description = post[:description].presence || post[:body].to_s[0, 800]

    {
      source_key: source[:key].to_s,
      source_label: source[:label],
      type: post[:type],
      title: post[:title],
      description: description.to_s,
      link: post[:link],
      published: post[:published],
      modified: post[:modified],
      guid: post[:link],
      reading_time_label: post[:reading_time_label],
      word_count: post[:word_count] || post.dig(:metadata, "word_count")
    }
  end

  def about_entries_cache
    @about_entries_cache ||= {}
  end

  def ctf_posts_cache
    @ctf_posts_cache ||= {}
  end

  def authored_challenges_cache
    @authored_challenges_cache ||= {}
  end
end
