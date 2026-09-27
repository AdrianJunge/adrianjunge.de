module BlogHelper
  # The two-argument form remains available for callers rendering standalone metadata.
  def render_blog_post_card(post, post_info = nil, interactive_tags: true, show_section_icon: false)
    post = { slug: post, metadata: post_info } if post_info
    render_content_card(BlogCardPresenter.new(
      post: post,
      url: post[:link].presence || blog_post_path(post[:slug]),
      interactive_tags: interactive_tags,
      section_url: (blog_path if show_section_icon)
    ))
  end
end
