module BlogHelper
  def render_blog_post_card(post_slug, post_info, interactive_tags: true)
    title = post_info["title"].presence || post_slug.humanize
    description = post_info["description"] || "No description available"
    published = post_info["published"] || "Unknown date"
    categories = Array(post_info["categories"]).presence || []
    logo_url = post_info["logo"]
    published_year = blog_post_year(post_info)
    difficulty = WriteupDifficulty.filter_label_for(post_info) ? WriteupDifficulty.from_metadata(post_info) : nil
    filter_tags = ([ difficulty&.fetch(:label, nil) ] + categories).compact
    filter_text = ([ title, description, published, published_year, post_info["topic"], difficulty&.fetch(:label, nil) ] + categories).compact.join(" ")
    tags = categories.map { |category| { label: category } }
    if difficulty
      tags.unshift({
        label: difficulty[:label],
        difficulty: true,
        difficulty_key: difficulty[:key],
        title: "Post difficulty: #{difficulty[:label]}"
      })
    end

    render_content_card(
      url: blog_post_path(post_slug),
      class_name: "blog-post-card",
      hitbox_class: "blog-post-card-hitbox",
      content_class: "blog-post-card-content",
      media: {
        image: logo_url,
        alt: "#{title} Logo",
        image_class: "blog-logo",
        wrapper_class: "blog-post-card-logo",
        placeholder: "📝",
        placeholder_class: "blog-logo-placeholder"
      },
      body_class: "blog-post-card-details",
      title: title,
      title_class: "blog-post-title",
      description: content_truncate(description),
      description_class: "blog-post-description",
      description_tag: :p,
      date: published,
      date_class: "blog-post-date",
      date_text_class: "blog-post-date-text",
      reading_time: post_info["reading_time_label"],
      reading_time_class: "blog-post-reading-time",
      tags_outer_class: "blog-post-meta",
      tags_class: "blog-post-meta-row",
      filter_scope: "blogs",
      interactive_tags: interactive_tags,
      tags: tags,
      data: {
        filter_card: "blogs",
        filter_text: filter_text,
        filter_tags: filter_tags.join("|"),
        filter_years: published_year
      },
      aria_label: "Open #{title} blog post"
    )
  end

  private

  def blog_post_year(post_info)
    return Time.parse(post_info["published"].to_s).year if post_info["published"].present?

    post_info["year"].presence
  rescue StandardError
    post_info["year"].presence
  end
end
