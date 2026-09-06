class BlogController < ApplicationController
  include MarkdownHelper

  def index
    @blogs = content_repository.blog_metadata

    @blog_posts = content_repository.blog_posts
    @filter_years = @blog_posts.map { |post| post[:published].year }.uniq.sort.reverse
    @filter_tags = sorted_filter_values(@blog_posts.flat_map { |post| [ post[:which] ] + content_repository.metadata_tags(post[:metadata] || {}) })
    @filter_tag_groups = filter_tag_groups(@filter_tags, topic_label: "Blog topics")
  end

  def show
    post = content_repository.blog_post(params[:which])
    return render_error_page(:not_found) unless post

    @post_slug = post[:slug]
    @blogs = content_repository.blog_metadata
    @markdown_content = post[:body]
    @blog_info = post[:metadata]
    @published_time = post[:published]
    @modified_time = post[:modified]
    @has_math = @blog_info["has_math"]
    blog_config = @blogs.fetch(@post_slug)

    @headings = []
    @html_content = render_markdown(@markdown_content, headings: @headings, parsed: true)

    @blog_category = blog_config["category"] || "Post"
    @blog_title = post[:title]
    @previous_post, @next_post = get_previous_and_next_post(@post_slug)
  end

  private

  def get_previous_and_next_post(post_slug)
    adjacent_content_items(content_repository.blog_posts, post_slug)
  end
end
