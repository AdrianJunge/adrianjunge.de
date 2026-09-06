class AboutmeController < ApplicationController
  include MarkdownHelper

  def index
    @about_content = content_repository.about_markdown
    parsed_about = parse_markdown_content(@about_content)
    @about_html = render_markdown(parsed_about.content, parsed: true)
    @about_info = parsed_about.front_matter
    @cves = content_repository.about_entries(ABOUTME_CVES_PATH)
    @bug_bounties = content_repository.about_entries(ABOUTME_BUG_BOUNTIES_PATH)
    @challenges = content_repository.authored_challenges
    @certificates = content_repository.about_entries(ABOUTME_CERTIFICATES_PATH)
    @talks = content_repository.about_entries(ABOUTME_TALKS_PATH)
    @achievements = content_repository.about_entries(ABOUTME_ACHIEVEMENTS_PATH)
    @cve_entry_count = @cves.length
    @talk_event_count = content_repository.timeline_event_count(@talks)
    @achievement_event_count = content_repository.timeline_event_count(@achievements)
  end
end
