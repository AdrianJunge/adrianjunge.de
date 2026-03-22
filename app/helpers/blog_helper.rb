module BlogHelper
  def render_blog_post_card(post_slug, post_info, blogs_metadata)
    max_description_length = 200
    title = post_info["title"].presence || post_slug.humanize
    description = post_info["description"] || "No description available"
    published = post_info["published"] || "Unknown date"
    categories = Array(post_info["categories"]).presence || []
    category_text = categories.join(", ").presence || "Post"
    
    logo_url = post_info["logo"]
    
    if !logo_url.present?
      blogs_metadata.each do |slug, blog|
        if slug.downcase == post_slug.downcase
          logo_url = blog["logo"]
          break
        end
      end
    end

    post_path = blog_post_path(post_slug)

    content_tag(:a, href: post_path, class: "blog-post-card") do
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
            content_tag(:div, class: "flex flex-wrap gap-2") do
              categories.map do |category|
                content_tag(:span, category, class: "inline-block px-2 py-1 text-xs font-medium text-white bg-slate-700 rounded")
              end.join.html_safe
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
      end
    end
  end
end
