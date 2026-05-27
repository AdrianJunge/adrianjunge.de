class BlogController < ApplicationController
  include ActionView::Helpers::SanitizeHelper
  include MarkdownHelper

  def index
    @blogs = content_repository.blog_metadata

    @blog_posts = content_repository.blog_posts
    @blog_posts.sort_by! { |post| post[:published] }.reverse!
    @filter_years = @blog_posts.map { |post| post[:published].year }.uniq.sort.reverse
    @filter_tags = sorted_filter_values(@blog_posts.flat_map { |post| post[:categories] })
    @filter_tag_groups = filter_tag_groups(@filter_tags, topic_label: "Blog topics")
  end

  def show
    @post_slug = params[:which].gsub("..", "").gsub("/", "")

    @blogs = content_repository.blog_metadata

    @markdown_content = safe_markdown_content(BLOG_BASE_PATH, @post_slug, render_error: true)
    return unless @markdown_content

    parsed = parse_markdown_content(@markdown_content)
    @blog_info = content_repository.post_metadata_from(parsed)
    @headings = get_headings_from_content(@markdown_content)
    @html_content = render_markdown(@markdown_content)

    blog_config = @blogs[@post_slug] || {}
    @blog_category = blog_config["category"] || "Post"
    @blog_title = blog_config["title"].presence || @blog_info["title"].presence || @post_slug.humanize
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
end
