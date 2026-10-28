# Public search records retain each page/card and its own sections. Timeline
# presentation merges are deliberately not used as an indexing source.
class SiteSearch
  include MarkdownHelper

  VERSION = "2".freeze
  CACHE_VERSION = "visible-passages-v2".freeze
  QUERY_LIMIT = 200
  SNIPPET_LENGTH = 200
  ABOUT_COLLECTIONS = [
    { path: :ABOUTME_CVES_PATH, id: "cves", title: "CVEs", kind: "CVE", icon_kind: "cve" },
    { path: :ABOUTME_CHALLENGES_PATH, id: "my-challenges", title: "Created CTF Challenges", kind: "Authored challenge", icon_kind: "challenge" },
    { path: :ABOUTME_CERTIFICATES_PATH, id: "certificates", title: "Certificates", kind: "Certificate", icon_kind: "certificate" },
    { path: :ABOUTME_TALKS_PATH, id: "talks", title: "Talks", kind: "Talk", icon_kind: "talk" },
    { path: :ABOUTME_ACHIEVEMENTS_PATH, id: "achievements", title: "Relevant achievements", kind: "Achievement", icon_kind: "achievement" }
  ].map(&:freeze).freeze
  # These are displayed prose/labels, not file locations or arbitrary metadata.
  PUBLIC_TEXT_KEYS = %w[
    title subtitle description reader_summary summary text hint hints value label name
    author authors article_authors category categories tags topic optional
    difficulty challenge_difficulty challenge-difficulty
    authored_challenge authored-challenge challenge_author writeup_winner writeup-winner winner
    event ctf year ctf_year event_year date published updated modified reading_time_label
    solves solve_count solves_count solve-count solves-count
    points point_count points_count challenge_points score links url proof_url proof
  ].freeze

  def initialize(repository: ContentRepository.new)
    @repository = repository
  end

  def documents
    @documents ||= @repository.cached_collection([ :site_search, VERSION, CACHE_VERSION, MarkdownHelper::RENDER_VERSION, Date.current, profile_revision ]) do
      records = main_documents + article_documents + about_documents + event_documents
      duplicates = records.group_by { |document| document[:url] }.select { |_url, entries| entries.length > 1 }.keys
      raise ContentRepository::InvalidContent, "Duplicate search destinations: #{duplicates.join(', ')}" if duplicates.any?

      records.sort_by { |document| document[:url] }
    end
  end

  def search(query, limit: nil)
    self.class.search_documents(documents, query, limit: limit)
  end

  def self.query(value)
    value.is_a?(String) ? value.strip.first(QUERY_LIMIT) : ""
  end

  def self.normalize(value)
    fold(value).gsub(/[^\p{L}\p{N}]+/, " ").strip
  end

  def self.fold(value)
    value.to_s.unicode_normalize(:nfkd).gsub(/\p{M}/, "").downcase
  end

  def self.phrase_pattern(value)
    value = query(value)
    return if normalize(value).split.length < 2

    phrase = fold(value).split.map { |word| Regexp.escape(word) }.join('\\s+')
    Regexp.new("(?<![\\p{L}\\p{N}])#{phrase}(?![\\p{L}\\p{N}])")
  end

  def self.phrase_range(text, phrase)
    pattern = phrase_pattern(phrase)
    match = pattern&.match(fold(text))
    return unless match

    offsets = []
    index = 0
    text.each_grapheme_cluster do |segment|
      fold(segment).length.times { offsets << [ index, index + segment.length ] }
      index += segment.length
    end
    [ offsets[match.begin(0)].first, offsets[match.end(0) - 1].last ]
  end

  def self.search_documents(documents, value, limit: nil)
    terms = normalize(query(value)).split.uniq
    return [] if terms.empty?

    phrase = phrase_pattern(value)
    results = documents.filter_map do |document|
      title = normalize(document[:title])
      tags = normalize(Array(document[:tags]).join(" "))
      sections = document.fetch(:sections).map do |section|
        phrase_match = phrase && (phrase.match?(fold(section[:heading])) || phrase.match?(fold(section[:text])))
        [ section, normalize(section[:heading]), normalize(section[:text]), phrase_match ]
      end
      # Query words may occur in different sections of this same document.
      next unless terms.all? { |term| title.include?(term) || tags.include?(term) || sections.any? { |_section, heading, text| heading.include?(term) || text.include?(term) } }

      score = terms.sum do |term|
        (title.include?(term) ? 80 : 0) + (tags.include?(term) ? 60 : 0) +
          (sections.any? { |_section, heading, _text| heading.include?(term) } ? 40 : 0) +
          (sections.any? { |_section, _heading, text| text.include?(term) } ? 4 : 0)
      end
      metadata_phrase = phrase && (phrase.match?(fold(document[:title])) || phrase.match?(fold(Array(document[:tags]).join(" "))))
      section_terms = terms.reject { |term| title.include?(term) || tags.include?(term) }
      best = sections.max_by do |_section, heading, text, phrase_match|
        [ phrase_match ? 1 : 0, section_terms.sum { |term| (heading.include?(term) ? 40 : 0) + (text.include?(term) ? 4 : 0) } ]
      end
      section = best&.first || { heading: "", anchor: nil, text: "" }
      section_match = section_terms.any? || (!metadata_phrase && best&.last)
      url = section_match && section[:anchor].present? ? "#{document[:url].split('#', 2).first}##{section[:anchor]}" : document[:url]
      { title: document[:title], kind: document[:kind], icon: document[:icon], heading: section[:heading], url: url,
        snippet: snippet(section[:text], terms, value), score: score,
        phrase_match: metadata_phrase || sections.any?(&:last) }
    end.sort_by { |result| [ result[:phrase_match] ? 0 : 1, -result[:score], result[:title].downcase, result[:url] ] }
    results.each { |result| result.delete(:phrase_match) }
    limit ? results.first([ limit.to_i, 0 ].max) : results
  end

  def self.snippet(text, terms, phrase = "")
    text = text.to_s
    range = phrase_range(text, phrase)
    unless range
      match = text.to_enum(:scan, /\S+/).find { |word| terms.any? { |term| normalize(word).include?(term) } }
      position = match ? text.index(match) : 0
      range = [ position, position + match.to_s.length ]
    end
    from, to = range
    length = [ SNIPPET_LENGTH, to - from ].max
    context = [ 60, (length - (to - from)) / 2 ].min
    start = [ from - context, 0 ].max
    excerpt = text[start, length].to_s.strip
    "#{'…' if start.positive?}#{excerpt}#{'…' if start + length < text.length}"
  end

  private

  def article_documents
    (@repository.blog_posts + @repository.ctf_posts).map do |post|
      metadata = public_metadata(post[:metadata])
      kind = post[:type] == "ctf" ? "CTF writeup" : "Blog post"
      tags = [ kind, post[:which], post[:topic], *Array(metadata["categories"]), *@repository.metadata_tags(metadata) ]
      tags << WriteupDifficulty.from_metadata(metadata)[:label] if post[:type] == "ctf"
      tags.concat(author_names(metadata["authors"]))
      tags.concat(author_names(metadata["article_authors"]))
      tags.concat(Array(post[:authors]).map { |author| author[:name] })
      tags.concat([ metadata["author"], @repository.ctf_event_year(metadata), metadata["published"] ])

      sections = markdown_sections(post[:body], introduction: article_introduction(post, metadata))
      if post[:type] == "ctf"
        hints = Nokogiri::HTML.fragment(search_view.render_writeup_hints(metadata).to_s)
        sections.insert(1, *hints.css("[data-hint-spoiler]").map do |hint|
          SiteSearchPassages.section(SiteSearchPassages.extract(hint), anchor: hint["id"])
        end)
      end
      icon = post[:logo].presence || (post[:type] == "ctf" ? "task-bar/flag.svg" : ContentIconRegistry.for("blog"))
      document(title: post[:title], url: post[:link], kind: kind, icon: icon, tags: tags, sections: sections)
    end
  end

  def about_documents
    parsed = @repository.parse_markdown(@repository.about_markdown)
    records = [ document(title: "About #{SiteProfile.name}", url: "/about", kind: "Page", icon: "task-bar/about.svg",
      tags: [ "About me", SiteProfile.name, SiteProfile.handle, "Biography", "Contact", "Email", "PGP key" ],
      sections: markdown_sections(parsed.content, introduction: [ "About me" ])) ]

    ABOUT_COLLECTIONS.each do |collection|
      entries = collection[:id] == "my-challenges" ? @repository.authored_challenges : @repository.about_entries(ContentConfiguration.const_get(collection[:path]))
      entries = entries.reject { |entry| @repository.hidden_content?(entry) }
      fallback_icon = ContentIconRegistry.for(collection[:icon_kind])
      section = AboutmeHelper::PROFILE_SECTIONS.find { |item| item[:id] == collection[:id] }
      count = %w[talks achievements].include?(collection[:id]) ? @repository.timeline_event_count(entries) : entries.length
      records << document(title: collection[:title], url: "/about##{collection[:id]}", kind: "About section",
        icon: fallback_icon, tags: [ collection[:title], collection[:kind] ],
        sections: [ SiteSearchPassages.section([ collection[:title], "#{count} #{count == 1 ? section[:singular] : section[:plural]}" ]) ])
      entries.each do |entry|
        tags = [ collection[:kind], *tag_labels(entry["tags"]) ]
        sections = profile_sections(entry, kind: collection[:icon_kind])
        records << document(title: [ entry["title"], entry["subtitle"] ].compact_blank.join(": "),
          url: "/about##{entry.fetch('id')}", kind: collection[:kind], icon: entry["icon"].presence || fallback_icon,
          tags: tags, sections: sections)
      end
    end
    records
  end

  def event_documents
    @repository.ctf_events.map do |event|
      metadata = event[:metadata]
      posts = @repository.ctf_posts_for_event(event[:slug])
      document(title: "#{event[:name]} CTF writeups", url: metadata.fetch("writeups"), kind: "CTF event",
        icon: metadata["logo"].presence || "task-bar/flag.svg",
        tags: [ event[:name], "CTF", "Capture The Flag", *posts.flat_map { |post| Array(post[:categories]) } ],
        sections: [ SiteSearchPassages.section([ event[:slug].upcase, "Writeups for #{event[:slug].upcase} challenges." ]) ] +
          posts.map do |post|
            SiteSearchPassages.section(SiteSearchPassages.extract(search_view.render_writeup_card(post[:slug], post[:link], post[:metadata])))
          end)
    end
  end

  def main_documents
    [
      document(title: "Home — #{SiteProfile.name} (#{SiteProfile.handle})", url: "/", kind: "Page", icon: "task-bar/home.svg",
        tags: [ "Home", "Contact", "Email", "PGP key", "Bug bounties" ],
        sections: [ SiteSearchPassages.section([
          "#{SiteProfile.name} (#{SiteProfile.handle})", "Welcome to my bug collection 🐛",
          "CTF player, vulnerability researcher, and computer science student creating writeups, collecting CVEs, bounties, and notes from real targets and challenges, occasionally algorithmic challenges. I poke things politely and sometimes convince software to confess.",
          "Timeline", "About me", "KITCTF", "KIT", "PGP key", SiteProfile.bug_bounty_count, "Bounties"
        ]), SiteSearchPassages.section([ "Politely asking software uncomfortable questions." ], anchor: "typing") ]),
      document(title: "Blog", url: "/blog", kind: "Page", icon: "task-bar/blog.svg", tags: [ "Blog posts", "Writing" ],
        text: "Longer notes on security work, learning, and practical writeups outside the CTF archive."),
      document(title: "CTF", url: "/ctf", kind: "Page", icon: "task-bar/flag.svg", tags: [ "CTF", "Capture The Flag", "Writeups" ],
        sections: [ SiteSearchPassages.section([ "CTF events", "Capture The Flag competitions grouped by event. Open an event to browse its challenge writeups." ]) ] +
          @repository.ctf_events.map do |event|
            SiteSearchPassages.section([ event[:name], event[:metadata]["description"] ], heading: event[:name], anchor: "ctf-event-#{event[:slug]}")
          end),
      document(title: "Timeline", url: "/timeline", kind: "Page", icon: "task-bar/timeline.svg", tags: [ "Timeline", "Activity" ],
        text: "Security research, CTF writeups, blog posts, CVEs, bug bounties, authored challenges, certificates, talks, and achievements ordered by date.")
    ]
  end

  def profile_revision
    [ SiteProfile.name, SiteProfile.handle, SiteProfile.description,
      SiteProfile.pgp_path, SiteProfile.modified, SiteProfile.social_links, SiteProfile.affiliations, SiteProfile.bug_bounty_count ]
  end

  def document(title:, url:, kind:, icon:, tags:, text: nil, sections: nil)
    { title: plain_text(title), url: url, kind: kind, icon: { src: icon, inverted: icon.start_with?("task-bar/") },
      tags: tags.flatten.compact.map { |value| plain_text(value) }.reject(&:blank?).uniq,
      sections: sections || [ SiteSearchPassages.section([ text ]) ] }
  end

  def markdown_sections(body, introduction: "")
    html = Nokogiri::HTML.fragment(render_markdown(body, parsed: true))
    html.css("script, style, button, .copy-status, [hidden]").remove
    sections = [ SiteSearchPassages.section(Array(introduction)) ]
    html.at_css(".markdown-content").children.each do |node|
      anchor = node.element? && node.name.match?(/\Ah[1-6]\z/) && node.at_css("a[id]")
      if anchor
        heading = node.at_css(".markdown-heading-text")&.text.presence || node.text
        sections << SiteSearchPassages.section([], heading: heading.squish, anchor: anchor["id"])
      else
        sections.last[:passages].concat(SiteSearchPassages.extract(node))
        sections.last[:text] = sections.last[:passages].join(" ")
      end
    end
    sections
  end

  def profile_sections(entry, kind:)
    card = search_view.profile_about_card(entry, kind: kind)
    # Media has no searchable text and need not resolve assets while indexing.
    html = search_view.render(partial: "shared/profile_card", locals: { card: ProfileCardPresenter.new(card.merge(icon: nil)) })
    fragment = Nokogiri::HTML.fragment(html)
    milestones = fragment.css(".aboutme-timeline > li").map do |node|
      label = node.at_css(".aboutme-timeline-title, .aboutme-timeline-link")&.text.to_s.squish
      SiteSearchPassages.section(SiteSearchPassages.extract(node), heading: label, anchor: node["id"].presence)
    end
    fragment.css(".aboutme-timeline").remove
    [ SiteSearchPassages.section(SiteSearchPassages.extract(fragment)), *milestones ]
  end

  def article_introduction(post, metadata)
    ctf = post[:type] == "ctf"
    source = ctf ? [ post[:which].to_s.upcase, @repository.ctf_event_year(metadata) ].compact.join("-") : post[:which]
    passages = [ source, post[:title], metadata["published"], metadata["reading_time_label"] ]
    passages << search_view.writeup_challenge_stats_label(metadata) if ctf
    if metadata["article_authors"].present?
      authors = post[:authors] || ArticleAuthor.normalize(metadata["article_authors"])
      passages.concat([ "Article by", *author_passages(authors) ])
    end
    if ctf
      badges = [ search_view.render_writeup_winner_badge(metadata, context: :article),
                 search_view.render_writeup_authored_badge(metadata, context: :article),
                 search_view.render_writeup_difficulty_badge(metadata, context: :article),
                 *search_view.render_writeup_category_badges(metadata, context: :article) ].compact
      passages.concat([ "Tags", *badges.flat_map { |badge| SiteSearchPassages.extract(badge) } ])
      authors = search_view.send(:writeup_authors, metadata)
      passages.concat([ "Challenge by", *author_passages(authors) ]) if authors.any?
      hints = search_view.render_writeup_hints(metadata)
      passages.concat(SiteSearchPassages.extract(Nokogiri::HTML.fragment(hints).at_css(".writeup-hints-summary"))) if hints
      passages.concat([ "About this writeup", metadata["reader_summary"] ]) if metadata["reader_summary"].present?
    else
      badges = search_view.render_blog_category_badges(metadata)
      passages.concat([ "Tags", *badges.flat_map { |badge| SiteSearchPassages.extract(badge) } ]) if badges.any?
    end
    passages.concat([ "Description", metadata["description"] ]) if metadata["description"].present?
    passages
  end

  def author_passages(authors)
    html = search_view.safe_join(authors.map { |author| search_view.content_author_node(author) }, ", ")
    SiteSearchPassages.extract(html)
  end

  def search_view
    @search_view ||= begin
      controller = ApplicationController.new
      controller.set_request!(ActionDispatch::Request.new(Rack::MockRequest.env_for("/")))
      controller.instance_variable_set(:@content_repository, @repository)
      controller.view_context
    end
  end

  def public_metadata(value)
    case value
    when Hash
      return {} if @repository.hidden_content?(value)

      value.stringify_keys.slice(*PUBLIC_TEXT_KEYS).transform_values { |item| public_metadata(item) }
    when Array then value.map { |item| public_metadata(item) }
    when String, Numeric, TrueClass, FalseClass then value
    else nil
    end
  end

  def tag_labels(tags)
    Array(tags).filter_map do |tag|
      next if tag.is_a?(Hash) && @repository.hidden_content?(tag)

      tag.is_a?(Hash) ? tag["label"] : tag
    end
  end

  def author_names(authors)
    Array.wrap(authors).filter_map { |author| author.is_a?(Hash) ? author["name"] : author }
  end

  def plain_text(value)
    value.to_s.squish
  end
end
