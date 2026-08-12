class BlogController < ApplicationController
  include ActionView::Helpers::SanitizeHelper
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
    @markdown_content = post[:content]
    @blog_info = post[:metadata]
    blog_config = @blogs.fetch(@post_slug)

    @headings = []
    @html_content = render_markdown(@markdown_content, headings: @headings)

    @blog_category = blog_config["category"] || "Post"
    @blog_title = blog_config["title"].presence || @blog_info["title"].presence || @post_slug.humanize
    @previous_post, @next_post = get_previous_and_next_post(@post_slug)
  end

  def feed
    @items = content_repository.blog_posts.map do |item|
      {
        blog: item[:item],
        title: item[:title],
        description: sanitize(item[:description], tags: %w[p br strong em a code pre img], attributes: %w[href src alt title]),
        link: item[:link],
        pub_date: item[:published],
        guid: item[:link]
      }
    end

    respond_to do |format|
      format.rss { render layout: false }
      format.atom { render layout: false }
    end
  end

  private

  def get_previous_and_next_post(post_slug)
    adjacent_content_items(content_repository.blog_posts, post_slug)
  end
end
