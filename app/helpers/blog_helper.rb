module BlogHelper
  def render_blog_post_card(post_slug, post_info, interactive_tags: true)
    max_description_length = 200
    title = post_info["title"].presence || post_slug.humanize
    description = post_info["description"] || "No description available"
    published = post_info["published"] || "Unknown date"
    categories = Array(post_info["categories"]).presence || []
    logo_url = post_info["logo"]
    published_year = blog_post_year(post_info)
    filter_text = ([ title, description, published, published_year, post_info["topic"] ] + categories).compact.join(" ")

    post_path = blog_post_path(post_slug)

    content_tag(
      :article,
      class: "blog-post-card ui-card-surface ui-hover-lift",
      data: {
        filter_card: "blogs",
        filter_text: filter_text,
        filter_tags: categories.join("|"),
        filter_years: published_year
      }
    ) do
      hitbox_html = link_to("", post_path, class: "blog-post-card-hitbox", aria: { label: "Open #{title} blog post" })

      content_tag(:div, class: "blog-post-card-content") do
        logo_html = content_tag(:div, class: "blog-post-card-logo") do
          if logo_url.present?
            image_tag(logo_url, alt: "#{title} Logo", class: "blog-logo")
          else
            content_tag(:div, class: "blog-logo-placeholder") do
              "📝"
            end
          end
        end

        content_html = content_tag(:div, class: "blog-post-card-details") do
          title_html = content_tag(:h3, class: "blog-post-title") do
            title
          end

          meta_html = content_tag(:div, class: "blog-post-meta") do
            content_tag(:div, class: "blog-post-meta-row") do
              safe_join(categories.map { |category| blog_category_chip(category, interactive_tags: interactive_tags) })
            end
          end

          truncated_description = description.length > max_description_length ? "#{description[0, max_description_length]}..." : description
          desc_html = content_tag(:p, class: "blog-post-description") do
            truncated_description
          end

          date_html = content_tag(:div, class: "blog-post-date") do
            content_tag(:span, published, class: "blog-post-date-text")
          end

          title_html + meta_html + desc_html + date_html
        end

        logo_html + content_html
      end + hitbox_html
    end
  end

  private

  def blog_category_chip(category, interactive_tags:)
    return content_tag(:span, category, class: "filter-chip blog-post-static-chip") unless interactive_tags

    content_tag(
      :button,
      category,
      type: "button",
      class: "filter-chip ui-hover-lift",
      data: { filter_scope: "blogs", filter_tag: category },
      aria: { pressed: "false", label: "Filter blog posts by #{category}" }
    )
  end

  def blog_post_year(post_info)
    return Time.parse(post_info["published"].to_s).year if post_info["published"].present?

    post_info["year"].presence
  rescue StandardError
    post_info["year"].presence
  end
end
