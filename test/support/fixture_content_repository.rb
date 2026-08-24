class FixtureContentRepository < ContentRepository
  ROOT = Rails.root.join("test", "fixtures", "content").freeze
  ABOUT_PATHS = {
    ApplicationController::ABOUTME_CVES_PATH.to_s => ROOT.join("about", "cves.json"),
    ApplicationController::ABOUTME_BUG_BOUNTIES_PATH.to_s => ROOT.join("about", "bug_bounties.json"),
    ApplicationController::ABOUTME_CHALLENGES_PATH.to_s => ROOT.join("about", "challenges.json"),
    ApplicationController::ABOUTME_CERTIFICATES_PATH.to_s => ROOT.join("about", "certificates.json"),
    ApplicationController::ABOUTME_TALKS_PATH.to_s => ROOT.join("about", "talks.json"),
    ApplicationController::ABOUTME_ACHIEVEMENTS_PATH.to_s => ROOT.join("about", "achievements.json")
  }.freeze

  def initialize
    super(
      ctf_base_path: ROOT.join("ctf", "writeups"),
      blog_base_path: ROOT.join("blog", "posts"),
      ctf_challenge_files_path: ROOT.join("ctf", "files"),
      ctf_pdf_writeups_path: ROOT.join("ctf", "pdfs"),
      ctf_metadata_data: read_fixture_json(ROOT.join("ctf", "ctfs.json")),
      blog_metadata_data: read_fixture_json(ROOT.join("blog", "blogs.json"))
    )
  end

  def about_entries(path, include_hidden: false)
    fixture_path = ABOUT_PATHS.fetch(path.to_s)
    entries = read_fixture_json(fixture_path)
    return entries if include_hidden

    visible_entries = entries.reject { |entry| hidden_content?(entry) }.filter_map do |entry|
      events = Array(entry["timeline"]).reject { |event| hidden_content?(event) }
      if path.to_s == ApplicationController::ABOUTME_ACHIEVEMENTS_PATH.to_s
        next if events.empty?

        events = sorted_about_entries(events, fallback_path: fixture_path)
      end

      entry.key?("timeline") ? entry.merge("timeline" => events) : entry
    end

    sorted_about_entries(visible_entries, fallback_path: fixture_path)
  end

  def authored_challenges(link_prefix: "/ctf")
    about_entries(ApplicationController::ABOUTME_CHALLENGES_PATH).map do |entry|
      next entry if link_prefix == "/ctf"

      entry.deep_dup.tap do |copy|
        Array(copy["tags"]).each do |tag|
          next unless tag.is_a?(Hash) && tag["url"].to_s.start_with?("/ctf/")

          tag["url"] = tag["url"].sub(%r{\A/ctf}, link_prefix)
        end
      end
    end
  end

  def file_time(path, year = nil)
    fixture_path = ABOUT_PATHS.fetch(path.to_s, path)
    super(fixture_path, year)
  end

  private

  def read_fixture_json(path)
    JSON.parse(File.read(path), allow_comments: true)
  end
end
