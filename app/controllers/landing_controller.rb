class LandingController < ApplicationController
  def index
    ctf_infos = get_all_ctf_infos()
    @most_recent_posts = most_recent_all_posts(3)
    @amount_posts, @amount_tags, @amount_ctfs = get_amounts()

    # Load blog metadata for landing view
    begin
      @blogs = JSON.parse(File.read(BLOG_INFO_PATH))
    rescue StandardError
      @blogs = {}
    end
  end

  private

  def get_amounts
    ctf_infos = get_all_ctf_infos()
    tags = Set.new
    post_amount = 0
    ctf_infos.each do |ctf_info|
      post_amount += ctf_info.length
      ctf_info.each_value do |info|
        categories = info["categories"] || []
        categories.each do |category|
          tags.add(category)
        end
      end
    end
    [ post_amount, tags.size, ctf_infos.length ]
  end

  def most_recent_all_posts(limit = 3)
    # Combine CTF writeups and blog posts
    ctf_posts = get_all_posts_for_feed(BASE_PATH, CTF_INFO_PATH, "/ctf")
    blog_posts = get_blog_posts_for_feed

    combined = ctf_posts + blog_posts

    # Sort by published date and return limit
    combined.sort_by { |p| -p[:published].to_i }.first(limit)
  end

  def most_recent_ctf_writeups(ctf_infos, limit = 3)
    flat = ctf_infos.flat_map { |entry| entry.values }

    flat.sort_by do |info|
      begin
        Date.strptime(info["published"], "%Y-%m-%d")
      rescue
        Date.new(1970, 1, 1)
      end
    end.reverse.first(limit)
  end
end
