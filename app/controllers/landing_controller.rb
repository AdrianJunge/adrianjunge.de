class LandingController < ApplicationController
  def index
    @most_recent_posts = most_recent_all_posts(3)
    @featured_items = ContentIndex.new.featured_items(3)
    @amount_posts = content_repository.post_count
    @amount_post_reading_time = content_repository.format_reading_time(content_repository.total_post_reading_time_minutes)
    @amount_cves = content_repository.about_entries(ABOUTME_CVES_PATH).length
    @amount_bug_bounties = content_repository.about_entries(ABOUTME_BUG_BOUNTIES_PATH).length
    @amount_challenges = content_repository.authored_challenges.length
    @amount_certificates = content_repository.about_entries(ABOUTME_CERTIFICATES_PATH).length
    @amount_achievements = content_repository.achievement_event_count(content_repository.about_entries(ABOUTME_ACHIEVEMENTS_PATH))

    @blogs = content_repository.blog_metadata
  end

  private

  def most_recent_all_posts(limit = 3)
    ctf_posts = content_repository.ctf_posts
    blog_posts = content_repository.blog_posts

    combined = ctf_posts + blog_posts

    combined.sort_by { |p| -p[:published].to_i }.first(limit)
  end
end
