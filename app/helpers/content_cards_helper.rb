module ContentCardsHelper
  def landing_blog_metadata(post)
    config = (@blogs || content_repository.blog_metadata).fetch(post[:slug], {})
    config.merge(post.fetch(:metadata, {})).merge(
      "title" => post[:title],
      "description" => post[:description],
      "topic" => post[:topic],
      "categories" => post[:categories],
      "published" => post[:published].strftime("%Y-%m-%d"),
      "reading_time_label" => post[:reading_time_label],
      "reading_time_minutes" => post[:reading_time_minutes],
      "logo" => post[:logo].presence || config["logo"]
    )
  end

  def timeline_card_options(item, visible_tags: nil)
    visible_tags ||= Array(item[:tags]).reject { |tag| ContentTagTaxonomy.recognition?(tag) || ContentTagTaxonomy.content_type?(tag) }
    tags = []
    if item[:writeup_winner].present?
      tags << { label: item[:writeup_winner][:label], tag_value: WriteupWinner::FILTER_LABEL, winner: true, class_name: "writeup-winner-badge-timeline" }
    end
    if item[:authored_challenge].present?
      tags << { label: item[:authored_challenge][:label], tag_value: AuthoredChallenge::FILTER_LABEL, authored: true, class_name: "authored-challenge-badge-timeline" }
    end
    tags.concat(visible_tags.first(6).map do |value|
      group = ContentTagTaxonomy.group_for(value)
      {
        label: ContentTagTaxonomy.canonical_label(value),
        tag_value: ContentTagTaxonomy.canonical_value(value),
        class_name: "timeline-tag-pill",
        difficulty_filter: group == :difficulty,
        difficulty_key: (value if group == :difficulty),
        severity: group == :severity,
        severity_key: (value if group == :severity),
        category: group == :category,
        category_key: (value if group == :category)
      }
    end)

    media = { wrapper_class: [ "blog-post-card-logo", ("writeup-post-card-logo" if item[:kind] == "writeup"), "timeline-card-logo" ].compact.join(" ") }
    if item[:kind] == "writeup" && item[:logo].blank?
      categories = Array(item[:tags]).select { |tag| ContentCategoryTag.recognized?(tag) }
      media_html = get_category_icon(categories).html_safe
    else
      icon = item[:logo].presence || {
        "blog" => "task-bar/blog.svg", "cve" => "other/cve.svg", "bug-bounty" => "other/bug-bounty.svg",
        "certificate" => "other/certificate.svg", "talk" => "other/talk-slides.png"
      }.fetch(item[:kind], "other/achievement.svg")
      media.merge!(image: icon, alt: "#{item[:title]} icon", image_class: "blog-logo")
    end

    section_link = case item[:kind]
    when "blog" then { url: blog_path, icon: "task-bar/blog.svg", kind: "blog", label: "Browse blog posts" }
    when "writeup" then { url: ctf_path, icon: "task-bar/flag.svg", kind: "ctf", label: "Browse CTF writeups" }
    end

    {
      url: item[:link], class_name: "timeline-content timeline-content-with-media",
      content_class: "blog-post-card-content timeline-card-content", body_class: "blog-post-card-details timeline-card-details",
      media_html: media_html, media: media, wrap_content: true, wrap_body: true, hitbox_class: "timeline-card-hitbox",
      title: item[:title], title_tag: :span, title_class: "timeline-title", tags: tags, tags_class: "timeline-tags", filter_scope: "timeline",
      description: item[:description], description_class: "timeline-meta", reading_time: item[:reading_time_label],
      reading_time_class: "timeline-reading-time", section_link: section_link, aria_label: "Open #{item[:title]}"
    }
  end
end
