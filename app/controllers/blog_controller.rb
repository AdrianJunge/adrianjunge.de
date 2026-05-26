class BlogController < ApplicationController
  include ActionView::Helpers::SanitizeHelper
  include MarkdownHelper

  def index
    file = File.read(BLOG_INFO_PATH)
    @blogs = JSON.parse(file)

    @blog_posts = get_blog_posts_for_feed
    @blog_posts.sort_by! { |post| post[:published] }.reverse!
    @filter_years = @blog_posts.map { |post| post[:published].year }.uniq.sort.reverse
    @filter_tags = sorted_filter_values(@blog_posts.flat_map { |post| post[:categories] })
  end

  def show
    @post_slug = params[:which].gsub("..", "").gsub("/", "")

    file = File.read(BLOG_INFO_PATH)
    @blogs = JSON.parse(file)

    unless File.exist?(BLOG_BASE_PATH.join("#{@post_slug}.md"))
      render plain: "Blog post not found", status: :not_found
      return
    end

    file_path = BLOG_BASE_PATH.join("#{@post_slug}.md")
    @markdown_content = File.read(file_path)
    parsed = parse_markdown_content(@markdown_content)
    @blog_info = parsed&.front_matter || {}
    @headings = get_blog_post_headings(@post_slug)
    @html_content = render_markdown(@markdown_content)

    blog_config = @blogs[@post_slug] || {}
    @blog_category = blog_config["category"] || "Post"
    @blog_title = blog_config["title"].presence || @blog_info["title"].presence || @post_slug.humanize
  end

  def feed
    @items = []

    @items = get_blog_posts_for_feed

    @items.map! do |item|
      file_path = BLOG_BASE_PATH.join("#{item[:slug]}.md")
      content = File.read(file_path)
      parsed = parse_markdown_content(content)

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
