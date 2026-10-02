# Public search records retain each page/card and its own sections. Timeline
# presentation merges are deliberately not used as an indexing source.
class SiteSearch
  include MarkdownHelper

  VERSION = "2".freeze
  CACHE_VERSION = "main-pages-v3".freeze
  QUERY_LIMIT = 200
  SNIPPET_LENGTH = 200
  ABOUT_COLLECTIONS = [
    { path: :ABOUTME_CVES_PATH, id: "cves", title: "CVEs", kind: "CVE" },
    { path: :ABOUTME_CHALLENGES_PATH, id: "my-challenges", title: "Created CTF Challenges", kind: "Authored challenge" },
    { path: :ABOUTME_CERTIFICATES_PATH, id: "certificates", title: "Certificates", kind: "Certificate" },
    { path: :ABOUTME_TALKS_PATH, id: "talks", title: "Talks", kind: "Talk" },
    { path: :ABOUTME_ACHIEVEMENTS_PATH, id: "achievements", title: "Relevant achievements", kind: "Achievement" }
  ].map(&:freeze).freeze
  # These are displayed prose/labels, not file locations or arbitrary metadata.
  PUBLIC_TEXT_KEYS = %w[
    title subtitle description reader_summary summary text hint hints value label name
    author authors article_authors category categories tags topic optional
    difficulty challenge_difficulty challenge-difficulty
    authored_challenge authored-challenge challenge_author writeup_winner writeup-winner winner
    event ctf year ctf_year event_year date published updated modified
    solves solve_count solves_count solve-count solves-count
    points point_count points_count challenge_points score links url proof_url proof
  ].freeze

  def initialize(repository: ContentRepository.new)
    @repository = repository
  end

  def documents
    @documents ||= @repository.cached_collection([ :site_search, VERSION, CACHE_VERSION, MarkdownHelper::RENDER_VERSION, profile_revision ]) do
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
    value.to_s.unicode_normalize(:nfkd).gsub(/\p{M}/, "").downcase.gsub(/[^\p{L}\p{N}]+/, " ").strip
  end

  def self.search_documents(documents, value, limit: nil)
    terms = normalize(query(value)).split.uniq
    return [] if terms.empty?

    results = documents.filter_map do |document|
      title = normalize(document[:title])
      tags = normalize(Array(document[:tags]).join(" "))
      sections = document.fetch(:sections).map { |section| [ section, normalize(section[:heading]), normalize(section[:text]) ] }
      # Query words may occur in different sections of this same document.
      next unless terms.all? { |term| title.include?(term) || tags.include?(term) || sections.any? { |_section, heading, text| heading.include?(term) || text.include?(term) } }

      score = terms.sum do |term|
        (title.include?(term) ? 80 : 0) + (tags.include?(term) ? 60 : 0) +
          (sections.any? { |_section, heading, _text| heading.include?(term) } ? 40 : 0) +
          (sections.any? { |_section, _heading, text| text.include?(term) } ? 4 : 0)
      end
      section_terms = terms.reject { |term| title.include?(term) || tags.include?(term) }
      best = sections.max_by do |_section, heading, text|
        section_terms.sum { |term| (heading.include?(term) ? 40 : 0) + (text.include?(term) ? 4 : 0) }
      end&.first || { heading: "", anchor: nil, text: "" }
      url = section_terms.any? && best[:anchor].present? ? "#{document[:url].split('#', 2).first}##{best[:anchor]}" : document[:url]
      { title: document[:title], kind: document[:kind], heading: best[:heading], url: url,
        snippet: snippet(best[:text], terms), score: score }
    end.sort_by { |result| [ -result[:score], result[:title].downcase, result[:url] ] }
    limit ? results.first([ limit.to_i, 0 ].max) : results
  end

  def self.snippet(text, terms)
    text = text.to_s
    match = text.to_enum(:scan, /\S+/).find { |word| terms.any? { |term| normalize(word).include?(term) } }
    position = match ? text.index(match) : 0
    start = [ position.to_i - 60, 0 ].max
    excerpt = text[start, SNIPPET_LENGTH].to_s.strip
    "#{'…' if start.positive?}#{excerpt}#{'…' if start + SNIPPET_LENGTH < text.length}"
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

      details = visible_text(metadata)
      details = [ post[:description], post[:which], details ].compact.join(" ")
      sections = markdown_sections(post[:body], introduction: details)
      document(title: post[:title], url: post[:link], kind: kind, tags: tags, sections: sections)
    end
  end

  def about_documents
    parsed = @repository.parse_markdown(@repository.about_markdown)
    records = [ document(title: "About #{SiteProfile.name}", url: "/about", kind: "Page",
      tags: [ "About me", SiteProfile.name, SiteProfile.handle, "Biography", "Contact", "Email", "PGP key" ],
      sections: markdown_sections(parsed.content, introduction: [ parsed.front_matter["description"], contact_text ].join(" "))) ]

    ABOUT_COLLECTIONS.each do |collection|
      entries = collection[:id] == "my-challenges" ? @repository.authored_challenges : @repository.about_entries(ContentConfiguration.const_get(collection[:path]))
      entries = entries.reject { |entry| @repository.hidden_content?(entry) }
      records << document(title: collection[:title], url: "/about##{collection[:id]}", kind: "About section",
        tags: [ collection[:title], collection[:kind] ], text: "#{entries.length} #{collection[:title]} by #{SiteProfile.name}.")
      entries.each do |entry|
        tags = [ collection[:kind], *tag_labels(entry["tags"]) ]
        sections = [ { heading: "", anchor: nil, text: visible_text(entry) } ]
        Array(entry["timeline"]).each do |event|
          next if @repository.hidden_content?(event) || event["title"].blank?

          # The repository supplies authored/normalized IDs. Derived challenge
          # milestones may have none, so they retain the actual parent anchor.
          sections << { heading: plain_text(event["title"]), anchor: event["id"].presence,
                        text: visible_text(event) }
        end
        records << document(title: [ entry["title"], entry["subtitle"] ].compact_blank.join(": "),
          url: "/about##{entry.fetch('id')}", kind: collection[:kind], tags: tags, sections: sections)
      end
    end
    records
  end

  def event_documents
    @repository.ctf_events.map do |event|
      metadata = event[:metadata]
      posts = @repository.ctf_posts_for_event(event[:slug])
      document(title: "#{event[:name]} CTF writeups", url: metadata.fetch("writeups"), kind: "CTF event",
        tags: [ event[:name], "CTF", "Capture The Flag", *posts.flat_map { |post| Array(post[:categories]) } ],
        text: [ metadata["description"], *posts.map { |post| "#{post[:title]} #{@repository.ctf_event_year(post[:metadata])}" } ].join(" "))
    end
  end

  def main_documents
    [
      document(title: "Home — #{SiteProfile.name} (#{SiteProfile.handle})", url: "/", kind: "Page",
        tags: [ "Home", "Contact", "Email", "PGP key", "Bug bounties" ],
        text: "Welcome to my bug collection. CTF player, vulnerability researcher, and computer science student creating writeups, collecting CVEs, bounties, and notes from real targets and challenges, occasionally algorithmic challenges. I poke things politely and sometimes convince software to confess. Politely asking software uncomfortable questions. #{SiteProfile.description} #{SiteProfile.affiliations.map { |affiliation| affiliation['name'] }.join(' ')} KIT KITCTF. #{contact_text} #{SiteProfile.bug_bounty_count} bug bounties."),
      document(title: "Blog", url: "/blog", kind: "Page", tags: [ "Blog posts", "Writing" ],
        text: "Longer notes on security work, learning, and practical writeups outside the CTF archive."),
      document(title: "CTF", url: "/ctf", kind: "Page", tags: [ "CTF", "Capture The Flag", "Writeups" ],
        text: "Capture The Flag competition events with published challenge writeups and security research notes."),
      document(title: "Timeline", url: "/timeline", kind: "Page", tags: [ "Timeline", "Activity" ],
        text: "Security research, CTF writeups, blog posts, CVEs, bug bounties, authored challenges, certificates, talks, and achievements ordered by date.")
    ]
  end

  def contact_text
    # Keep the address out of public JSON so it does not bypass the footer's obfuscation.
    "#{SiteProfile.name} (#{SiteProfile.handle}). Email contact. Public PGP key. #{SiteProfile.social_links.keys.join(' ')}."
  end

  def profile_revision
    [ SiteProfile.name, SiteProfile.handle, SiteProfile.description,
      SiteProfile.pgp_path, SiteProfile.modified, SiteProfile.social_links, SiteProfile.affiliations, SiteProfile.bug_bounty_count ]
  end

  def document(title:, url:, kind:, tags:, text: nil, sections: nil)
    { title: plain_text(title), url: url, kind: kind,
      tags: tags.flatten.compact.map { |value| plain_text(value) }.reject(&:blank?).uniq,
      sections: sections || [ { heading: "", anchor: nil, text: plain_text(text) } ] }
  end

  def markdown_sections(body, introduction: "")
    html = Nokogiri::HTML.fragment(render_markdown(body, parsed: true))
    html.css("script, style, button, .copy-status, [hidden]").remove
    sections = [ { heading: "", anchor: nil, text: plain_text(introduction) } ]
    html.at_css(".markdown-content").children.each do |node|
      anchor = node.element? && node.name.match?(/\Ah[1-6]\z/) && node.at_css("a[id]")
      if anchor
        heading = node.at_css(".markdown-heading-text")&.text.presence || node.text
        sections << { heading: heading.squish, anchor: anchor["id"], text: "" }
      else
        images = node.css("img[alt]").map { |image| image["alt"] }
        images << node["alt"] if node.element? && node.name == "img"
        sections.last[:text] = [ sections.last[:text], node.text, *images ].join(" ").squish
      end
    end
    sections
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

  def visible_text(value)
    filtered = public_metadata(value)
    flatten_text(filtered).map { |text| plain_text(text) }.reject(&:blank?).join(" ")
  end

  def flatten_text(value)
    case value
    when Hash then value.except("url", "proof_url", "proof").values.flat_map { |item| flatten_text(item) }
    when Array then value.flat_map { |item| flatten_text(item) }
    when String, Numeric then [ value ]
    else []
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
