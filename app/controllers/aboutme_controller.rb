class AboutmeController < ApplicationController
  include MarkdownHelper

  def index
    @about_content = content_repository.about_markdown
    @about_html = render_markdown(@about_content)
    @about_info = parse_markdown_content(@about_content)&.front_matter || {}
    @cves = content_repository.about_entries(ABOUTME_CVES_PATH)
    @bug_bounties = content_repository.about_entries(ABOUTME_BUG_BOUNTIES_PATH)
    @challenges = content_repository.authored_challenges
    @certificates = content_repository.about_entries(ABOUTME_CERTIFICATES_PATH)
    @achievements = content_repository.about_entries(ABOUTME_ACHIEVEMENTS_PATH)
    @cve_entry_count = @cves.length
    @achievement_event_count = content_repository.achievement_event_count(@achievements)
  end
end
