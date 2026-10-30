module BlogHelper
  def render_blog_category_badges(info, context: :article)
    ContentTagTaxonomy.canonical_values(Array(info["categories"])).map do |category|
      content_category_badge(label: category, context: context, title: "Post category: #{category}")
    end
  end

  # The two-argument form remains available for callers rendering standalone metadata.
  def render_blog_post_card(post, post_info = nil, interactive_tags: true, show_section_icon: false, title_tag: :h2)
    post = { slug: post, metadata: post_info } if post_info
    render_content_card(BlogCardPresenter.new(
      post: post,
      url: post[:link].presence || blog_post_path(post[:slug]),
      interactive_tags: interactive_tags,
      title_tag: title_tag,
      section_url: (blog_path if show_section_icon)
    ))
  end
end
