class AboutmeController < ApplicationController
  include MarkdownHelper

  def index
    @about_content = read_about_markdown
    @about_html = render_markdown(@about_content)
    @about_info = parse_markdown_content(@about_content)&.front_matter || {}
    @cves = read_aboutme_json(ABOUTME_CVES_PATH)
    @bug_bounties = read_aboutme_json(ABOUTME_BUG_BOUNTIES_PATH)
    @challenges = read_aboutme_json(ABOUTME_CHALLENGES_PATH)
    @certificates = read_aboutme_json(ABOUTME_CERTIFICATES_PATH)
    @achievements = read_aboutme_json(ABOUTME_ACHIEVEMENTS_PATH)
    @cve_entry_count = @cves.length
  end

  private

  def read_about_markdown
    File.exist?(ABOUTME_TEXT_PATH) ? File.read(ABOUTME_TEXT_PATH) : ""
  end

  def read_aboutme_json(path)
    return [] unless File.exist?(path)

    JSON.parse(File.read(path))
  rescue JSON::ParserError
    []
  end
end
