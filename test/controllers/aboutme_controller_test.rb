require "test_helper"

class AboutmeControllerTest < ActionDispatch::IntegrationTest
  test "shows about page with every public collection and derived counter" do
    repository = production_content_repository

    get about_path

    assert_response :success
    assert_select "main.aboutme-page"
    assert_select ".aboutme-section:not([open])", 5
    assert_select ".aboutme-section[open]", 0
    assert_select "#bug-bounties", 0
    assert_select ".aboutme-stat:not(a) .aboutme-stat-value", text: SiteProfile.bug_bounty_count.to_s
    assert_select ".aboutme-stat:not(a) .aboutme-stat-label", text: "Bug bounties"
    assert_select "a[href='#bug-bounties']", 0
    assert_select ".taskbar-link[href=?]", about_path, text: "About"

    ContentTestHelpers::ABOUT_COLLECTIONS.each do |spec|
      entries = about_collection_entries(spec, repository: repository)
      expected_count = spec.fetch(:count).call(repository, entries)
      section_selector = "##{spec.fetch(:id)}"

      assert_select "#{section_selector}.aboutme-section", 1
      assert_select "#{section_selector} #{spec.fetch(:card_selector)}", entries.length
      assert_select ".aboutme-stat[href='##{spec.fetch(:id)}'] .aboutme-stat-value", text: expected_count.to_s
      assert_select "#{section_selector} .aboutme-section-count", text: /\A#{expected_count}\b/

      rendered_ids = css_select("#{section_selector} #{spec.fetch(:card_selector)}").map { |node| node["id"] }.sort
      assert_equal entries.map { |entry| entry.fetch("id") }.sort, rendered_ids
    end
  end

  test "legacy page aliases return not found" do
    [ "/aboutme", "/posts-timeline", "/posts-timeline?q=Joomla&year=2026" ].each do |path|
      get path
      assert_response :not_found
      assert_nil response.headers["Location"]
      assert_select "main.error-page"

      head path
      assert_response :not_found
      assert_nil response.headers["Location"]
      assert_empty response.body
    end
  end

  test "landing sidebar links to about page" do
    get root_path

    assert_response :success
    assert_select ".taskbar-link[href=?]", about_path, text: "About"
  end

  test "landing page exposes repository-derived counters and a fixed bounty count" do
    repository = production_content_repository
    cves = repository.about_entries(ApplicationController::ABOUTME_CVES_PATH)

    get root_path

    assert_response :success
    assert_select "h1", text: /Welcome/
    assert_select ".landing-action[href=?]", timeline_path, text: /Timeline/
    assert_select ".landing-action[href=?]", about_path, text: /About me/
    assert_select ".landing-metrics.aboutme-stats"
    assert_select ".landing-metric.aboutme-stat", 4
    assert_select ".landing-metric:first-child[href=?]", timeline_path, text: /Posts/
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#cves", text: cves.length.to_s
    assert_select ".landing-metric:not(a) .landing-metric-value", text: SiteProfile.bug_bounty_count.to_s
    assert_select ".landing-metric:not(a) .landing-metric-label", text: "Bounties"
    assert_select ".landing-metric[href=?]", "#{about_path}#bug-bounties", false
    assert_select ".landing-metric[href=?]", about_path, text: /& more\.\.\./
    assert_select ".landing-metric[href=?]", "#{about_path}#my-challenges", false
    assert_select ".landing-metric[href=?]", "#{about_path}#certificates", false
    assert_select ".landing-metric[href=?]", "#{about_path}#achievements", false
    assert_select ".landing-metric[href=?] .landing-metric-value", timeline_path, text: repository.post_count.to_s
    assert_select ".landing-metric[href=?] .landing-metric-sublabel", timeline_path,
                  text: repository.format_reading_time(repository.total_post_reading_time_minutes)
    assert_select ".landing-metric .aboutme-stat-icon", false
    assert_select "#landing-featured-title", false
    assert_select ".landing-featured-card", false
  end

  test "landing and About descriptions match their rendered and searchable sources" do
    search = SiteSearch.new

    get root_path
    lead = css_select(".landing-lead").text.squish
    tagline = css_select("#typing").text.squish
    home_sections = search.documents.find { |document| document[:url] == "/" }.fetch(:sections)
    assert_equal SiteProfile.landing_lead, lead
    assert_equal SiteProfile.landing_tagline, tagline
    assert_includes home_sections.first.fetch(:passages), lead
    assert_includes home_sections.last.fetch(:passages), tagline

    get about_path
    repository = production_content_repository
    front_matter = repository.parse_markdown(repository.about_markdown).front_matter
    biography = css_select(".aboutme-copy p").first.text.squish
    about_sections = search.documents.find { |document| document[:url] == "/about" }.fetch(:sections)
    assert_select "meta[name='description'][content=?]", front_matter.fetch("description")
    assert_select "meta[property='og:description'][content=?]", front_matter.fetch("description")
    assert_includes about_sections.flat_map { |section| section.fetch(:passages) }, biography
  end

  test "about content satisfies semantic publication contracts" do
    repository = production_content_repository

    ContentTestHelpers::ABOUT_COLLECTIONS.each do |spec|
      raw_entries = parse_content_json(spec.fetch(:path))
      visible_entries = about_collection_entries(spec, repository: repository)

      assert_kind_of Array, raw_entries
      assert_equal raw_entries.map { |entry| entry["id"] }.uniq,
                   raw_entries.map { |entry| entry["id"] },
                   "duplicate IDs in #{spec.fetch(:path)}"
      assert visible_entries.none? { |entry| repository.hidden_content?(entry) }
      assert visible_entries.all? { |entry| entry["id"].present? && entry["title"].present? }
      assert_descending_about_entries visible_entries, repository, spec.fetch(:path)
    end

    cves = repository.about_entries(ApplicationController::ABOUTME_CVES_PATH)
    cves.each do |entry|
      labels = Array(entry["tags"]).map { |tag| about_tag_label(tag) }
      references = Array(entry["links"]).select do |link|
        link.is_a?(Hash) && link["label"].present? && link["url"].to_s.match?(%r{\Ahttps?://})
      end

      assert entry["subtitle"].present?, "missing subtitle for #{entry['id']}"
      assert labels.any? { |label| ContentVulnerabilityTag.cve?(label) }, "missing CVE tag for #{entry['id']}"
      assert labels.any? { |label| ContentVulnerabilityTag.cwe?(label) }, "missing CWE tag for #{entry['id']}"
      assert_operator references.length, :>=, 2, "expected two external references for #{entry['id']}"
      assert_valid_timeline entry
    end

    repository.authored_challenges.each do |entry|
      writeup_tag = Array(entry["tags"]).find do |tag|
        tag.is_a?(Hash) && tag["label"].present? && tag["url"].to_s.start_with?("/ctf/")
      end

      assert writeup_tag, "missing local writeup tag for #{entry['id']}"
      assert repository.ctf_posts.any? { |post| CGI.unescape(post[:link]) == CGI.unescape(writeup_tag["url"]) },
             "unknown writeup URL for #{entry['id']}: #{writeup_tag['url']}"
      assert_valid_timeline entry
    end

    [
      ApplicationController::ABOUTME_CERTIFICATES_PATH,
      ApplicationController::ABOUTME_TALKS_PATH,
      ApplicationController::ABOUTME_ACHIEVEMENTS_PATH
    ].each do |path|
      repository.about_entries(path).each { |entry| assert_valid_timeline entry }
    end
  end

  private

  def assert_descending_about_entries(entries, repository, path)
    times = entries.map { |entry| repository.about_entry_time(entry, fallback_path: path).to_i }
    assert_equal times.sort.reverse, times, "entries are not newest-first in #{path}"
  end

  def assert_valid_timeline(entry)
    events = Array(entry["timeline"])
    return if events.empty?

    assert events.all? { |event| event.is_a?(Hash) && event["title"].present? },
           "invalid timeline event for #{entry['id']}"
    dated_events = events.select { |event| event["date"].present? }
    assert dated_events.all? { |event| production_content_repository.parsed_time(event["date"], fallback: nil) },
           "invalid timeline date for #{entry['id']}"
  end
end
