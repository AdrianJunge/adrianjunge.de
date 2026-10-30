class BlogCardPresenter < ContentCardPresenter
  def initialize(post:, url:, interactive_tags: true, section_url: nil, title_tag: :h2)
    post_info = post.fetch(:metadata)
    title = post[:title].presence || post_info["title"].presence || post[:slug].humanize
    description = post_info["description"] || "No description available"
    published_raw = post_info["published"].presence || post[:published]&.strftime("%Y-%m-%d") || "Unknown date"
    published = ContentDate.display_label(published_raw) || published_raw
    raw_categories = Array(post_info["categories"]).presence || []
    categories = ContentTagTaxonomy.canonical_values(raw_categories)
    content_type = ContentTagTaxonomy.canonical_label(post_info["category"])
    content_type = nil unless ContentTagTaxonomy.content_type?(content_type)
    display_categories = categories.reject { |category| content_type.present? && category.casecmp?(content_type) }
    logo_url = post_info["logo"]
    published_year = ContentDate.parse(post_info["published"].presence || post_info["year"])&.year
    difficulty = WriteupDifficulty.filter_label_for(post_info) ? WriteupDifficulty.from_metadata(post_info) : nil
    filter_tags = ContentTagTaxonomy.canonical_values([ content_type, difficulty&.fetch(:label, nil) ] + categories)
    filter_text = ([ title, description, published_raw, published, published_year, post_info["topic"], content_type, difficulty&.fetch(:label, nil) ] + raw_categories + categories).compact.join(" ")
    tags = []
    tags << { label: content_type } if content_type.present?
    tags.concat(display_categories.map { |category| { label: category } })
    if difficulty
      tags.unshift({
        label: difficulty[:label],
        difficulty: true,
        difficulty_key: difficulty[:key],
        title: "Post difficulty: #{difficulty[:label]}"
      })
    end

    super(
      variant: :post,
      url: url,
      media: {
        image: logo_url,
        alt: "#{title} Logo",
        image_class: "blog-logo",
        wrapper_class: "blog-post-card-logo",
        placeholder: "📝",
        placeholder_class: "blog-logo-placeholder"
      },
      title: title,
      title_tag: title_tag,
      description: description,
      date: published,
      date_datetime: (published_raw if ContentDate.parse(published_raw)),
      reading_time: post_info["reading_time_label"],
      filter_scope: "blogs",
      interactive_tags: interactive_tags,
      tags: tags,
      data: {
        filter_card: "blogs",
        filter_text: filter_text,
        filter_tags: filter_tags.join("|"),
        filter_years: published_year
      },
      section_link: section_url ? {
        url: section_url,
        icon: "task-bar/blog.svg",
        kind: "blog",
        label: "Browse blog posts"
      } : nil,
      aria_label: "Open #{title} blog post"
    )
  end
end
