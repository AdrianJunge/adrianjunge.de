require "test_helper"

class AboutmeControllerTest < ActionDispatch::IntegrationTest
  test "shows about me page with security sections" do
    get about_path
    repository = ContentRepository.new
    cves = repository.about_entries(ApplicationController::ABOUTME_CVES_PATH)

    assert_response :success
    assert_select "main.aboutme-page"
    assert_select ".taskbar-link[href=?]", about_path, text: /About me/
    assert_select ".aboutme-section-title", text: "CVEs"
    assert_select ".aboutme-section-title", text: "Bug bounties"
    assert_select ".aboutme-section-title", text: "Created CTF Challenges"
    assert_select ".aboutme-section-title", text: "Certificates"
    assert_select ".aboutme-section-title", text: "Talks"
    assert_select ".aboutme-section-title", text: "Relevant achievements"
    assert_select ".aboutme-finding-card", minimum: 1
    assert_select ".aboutme-achievement-card", minimum: 1
    assert_select ".aboutme-stat[href=?] .aboutme-stat-value", "#cves", text: cves.length.to_s
    assert_select ".aboutme-stat[href=?] .aboutme-stat-value", "#bug-bounties", text: "0"
    assert_select ".aboutme-stat[href=?]", "#my-challenges", text: /Created CTF Challenges/
    assert_select ".aboutme-stat[href=?]", "#certificates", text: /Certificates/
    assert_select ".aboutme-stat[href=?]", "#talks", text: /Talks/
    assert_select ".aboutme-stat[href=?]", "#achievements", text: /Achievements/
  end

  test "aboutme redirects to canonical about route" do
    get "/aboutme"

    assert_redirected_to about_path
  end

  test "landing sidebar links to about page" do
    get root_path

    assert_response :success
    assert_select ".taskbar-link[href=?]", about_path, text: /About me/
  end

  test "landing page exposes about section counters" do
    get root_path

    repository = ContentRepository.new
    cves = repository.about_entries(ApplicationController::ABOUTME_CVES_PATH)

    assert_response :success
    assert_select "h1", text: "Welcome to my bug collection 🐛"
    assert_select ".landing-action[href=?]", timeline_path, text: /Timeline/
    assert_select ".landing-action[href=?]", about_path, text: /About me/
    assert_select ".landing-metrics.aboutme-stats"
    assert_select ".landing-metric.aboutme-stat", 4
    assert_select ".landing-metric:first-child[href=?]", timeline_path, text: /Posts/
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#cves", text: cves.length.to_s
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#bug-bounties", text: "0"
    assert_select ".landing-metric[href=?]", "#{about_path}#bug-bounties", text: /Bounties/
    assert_select ".landing-metric[href=?]", about_path, text: /& more\.\.\./
    assert_select ".landing-metric[href=?]", "#{about_path}#my-challenges", false
    assert_select ".landing-metric[href=?]", "#{about_path}#certificates", false
    assert_select ".landing-metric[href=?]", "#{about_path}#achievements", false
    assert_select ".landing-metric[href=?] .landing-metric-value", timeline_path, text: repository.post_count.to_s
    assert_select ".landing-metric[href=?] .landing-metric-sublabel", timeline_path, text: repository.format_reading_time(repository.total_post_reading_time_minutes)
    assert_select ".landing-metric .aboutme-stat-icon", false
    assert_select "#landing-featured-title", false
    assert_select ".landing-featured-card", false
  end

  test "about me content files have expected shape" do
    cves = JSON.parse(File.read(ApplicationController::ABOUTME_CVES_PATH))
    bug_bounties = JSON.parse(File.read(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH))
    challenge_records = JSON.parse(File.read(ApplicationController::ABOUTME_CHALLENGES_PATH))
    challenges = ContentRepository.new.authored_challenges
    certificates = JSON.parse(File.read(ApplicationController::ABOUTME_CERTIFICATES_PATH))
    talks = JSON.parse(File.read(ApplicationController::ABOUTME_TALKS_PATH))
    achievements = JSON.parse(File.read(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH))

    assert_kind_of Array, cves
    assert_kind_of Array, bug_bounties
    assert_kind_of Array, challenge_records
    assert_kind_of Array, certificates
    assert_kind_of Array, talks
    assert_kind_of Array, achievements
    assert_equal 10, cves.length
    assert_equal %w[
      joomla-com-users-batch-task-privilege-escalation
      joomla-com-tags-authenticated-blind-sqli
      joomla-com-finder-authenticated-blind-sqli
      churchcrm-settingsindividual-blind-sqli
      churchcrm-propertyassign-blind-sqli
    ], cves.first(5).map { |entry| entry["id"] }
    cve_tag_labels = cves.flat_map { |entry| entry.fetch("tags", []) }.filter_map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }
    assert_includes cve_tag_labels, "CVE-2026-39327"
    assert_includes cve_tag_labels, "CVE-2026-35221"
    assert_includes cve_tag_labels, "CVE-2026-35222"
    assert_includes cve_tag_labels, "CVE-2026-48898"
    assert_not cves.any? { |entry| entry["id"].include?("suitecrm-tba") }
    assert_equal 1, bug_bounties.length
    assert_equal "firedancer-tba", bug_bounties.first["id"]
    assert_equal true, bug_bounties.first["hidden"]
    assert_empty ContentRepository.new.about_entries(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH)
    assert_equal 2, challenge_records.length
    assert_equal 2, challenges.length
    assert_equal challenge_records, challenges
    assert_equal [ "scanwich-station", "smile-at-me" ], challenges.map { |entry| entry["id"] }
    assert_equal "Scanwich Station", challenges.first["title"]
    assert_nil challenges.first["subtitle"]
    assert_includes challenges.first["summary"], "Published for GPNCTF 2026"
    assert_equal "/ctf/gpnctf/Scanwich%20Station", challenges.first["url"]
    assert_equal [ "GPNCTF 2026", "Hard", "Writeup" ], challenges.first["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }
    assert_equal "https://gpn24.ctf.kitctf.de/", challenges.first["tags"].first["url"]
    assert_includes challenges.second["summary"], "Published for GPNCTF 2025"
    assert_equal [ "GPNCTF 2025", "Hard", "Writeup" ], challenges.second["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }
    assert_equal "/ctf/gpnctf/Smile%20at%20me", challenges.second["url"]
    assert_nil certificates.first["subtitle"]
    assert_includes certificates.first["summary"], "full penetration-test report"
    assert_equal "/blog/htb-cpts", certificates.first["url"]
    assert_equal [ "Certificate", "Writeup" ], certificates.first["tags"].map { |tag| tag["label"] }
    assert_equal "https://www.credly.com/badges/a9a49759-8f35-4c46-8783-a11a4a1bfdf0/public_url", certificates.first["tags"].first["url"]
    assert_equal 1, talks.length
    assert_equal "kitctf-web-intro-2026", talks.first["id"]
    assert_equal "KITCTF Web Intro", talks.first["title"]
    assert_equal "2026-05-07", talks.first["date"]
    assert_equal "https://kitctf.de/intro/", talks.first["url"]
    assert_equal [ "Slides", "Overview" ], talks.first["tags"].map { |tag| tag["label"] }
    assert_equal "https://kitctf.de/talks/2026-05-07-web/web-26-ss.pdf", talks.first["tags"].first["url"]
    assert_equal %w[
      dhm
      cscg
      kitctf
    ], achievements.map { |entry| entry["id"] }
    assert_equal %w[
      kitctf
      dhm
      cscg
    ], ContentRepository.new.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH).map { |entry| entry["id"] }
    dhm = achievements.find { |entry| entry["id"] == "dhm" }
    cscg = achievements.find { |entry| entry["id"] == "cscg" }
    assert_equal %w[dhm-2025 dhm-2024], dhm["timeline"].map { |event| event["id"] }
    assert_equal [
      "Participated in the DHM finals after qualifying through CSCG.",
      "Placed #1 at the Deutsche Hacking Meisterschaft."
    ], dhm["timeline"].map { |event| event["summary"] }
    assert_equal %w[cscg-2025 cscg-2024], cscg["timeline"].map { |event| event["id"] }
    assert_equal [
      "Qualified for DHM again and finished top 10 globally.",
      "Qualified for DHM through CSCG."
    ], cscg["timeline"].map { |event| event["summary"] }
    kitctf = achievements.find { |entry| entry["id"] == "kitctf" }
    assert_equal "https://ctftime.org/team/7221/", kitctf["tags"].find { |tag| tag["label"] == "KITCTF" }["url"]
    assert_equal %w[
      kitctf-glacierctf-2025
      kitctf-googlectf-2025
      kitctf-swampctf-2025
      kitctf-snakectf-finals-2024
      kitctf-glacierctf-2024
      kitctf-swampctf-2024
    ], kitctf["timeline"].map { |event| event["id"] }
    assert kitctf["timeline"].any? { |event| event["summary"] == "#3 at GlacierCTF, qualifying for DHM 2025 as KITCTF team." }
    assert kitctf["timeline"].any? { |event| event["summary"] == "#3 at SwampCTF." }
    assert kitctf["timeline"].any? { |event| event["summary"] == "#1 at SwampCTF." }
    assert kitctf["timeline"].any? { |event| event["summary"] == "Qualified for and participated in the SnakeCTF finals in Italy." }
    assert kitctf["timeline"].any? { |event| event["summary"] == "#6 at Google CTF as the FluxKITtens merger team (FluxFingers and KITCTF), qualifying for the Hackceler8 finals in Mexico." }

    cves.each do |entry|
      assert entry["title"].present?
      assert entry["subtitle"].present?
      assert entry["tags"].any?
      assert entry["links"].any? { |link| link["label"] == "Repository" }
      assert entry["links"].any? { |link| link["label"] == "Advisory source" }
      assert_kind_of Array, entry["timeline"] if entry["timeline"].present?
    end

    cves.each do |entry|
      labels = entry["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }
      assert labels.any? { |label| label.start_with?("CVE-") }
      assert labels.any? { |label| label.start_with?("CWE-") }
    end

    (challenges + certificates + talks + achievements).each do |entry|
      assert entry["title"].present?
      assert_kind_of Array, entry["tags"] if entry["tags"].present?
    end
  end
end
