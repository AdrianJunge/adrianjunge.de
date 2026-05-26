class LandingController < ApplicationController
  def index
    @most_recent_posts = most_recent_all_posts(3)
    @amount_posts, @amount_ctfs = get_amounts()
    @amount_cves = read_aboutme_count(ABOUTME_CVES_PATH)
    @amount_bug_bounties = read_aboutme_count(ABOUTME_BUG_BOUNTIES_PATH)
    @amount_certificates = read_aboutme_count(ABOUTME_CERTIFICATES_PATH)
    @amount_achievements = read_aboutme_count(ABOUTME_ACHIEVEMENTS_PATH)

    begin
      @blogs = JSON.parse(File.read(BLOG_INFO_PATH))
    rescue StandardError
      @blogs = {}
    end
  end

  private

  def get_amounts
    ctf_infos = get_all_ctf_infos()
    post_amount = 0
    ctf_infos.each do |ctf_info|
      post_amount += ctf_info.length
    end
    [ post_amount, ctf_infos.length ]
  end

  def most_recent_all_posts(limit = 3)
    ctf_posts = get_all_posts_for_feed(BASE_PATH, CTF_INFO_PATH, "/ctf")
    blog_posts = get_blog_posts_for_feed

    combined = ctf_posts + blog_posts

    combined.sort_by { |p| -p[:published].to_i }.first(limit)
  end

  def read_aboutme_count(path)
    return 0 unless File.exist?(path)

    JSON.parse(File.read(path)).length
  rescue JSON::ParserError
    0
  end
end
