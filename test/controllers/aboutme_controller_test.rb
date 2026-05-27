require "test_helper"

class AboutmeControllerTest < ActionDispatch::IntegrationTest
  test "shows about me page with security sections" do
    get about_path
    cves = JSON.parse(File.read(ApplicationController::ABOUTME_CVES_PATH))

    assert_response :success
    assert_select "main.aboutme-page"
    assert_select ".taskbar-link[href=?]", about_path, text: /About me/
    assert_select ".aboutme-section-title", text: "CVEs"
    assert_select ".aboutme-section-title", text: "Bug bounties"
    assert_select ".aboutme-section-title", text: "Created CTF Challenges"
    assert_select ".aboutme-section-title", text: "Certificates"
    assert_select ".aboutme-section-title", text: "Relevant achievements"
    assert_select ".aboutme-finding-card", minimum: 1
    assert_select ".aboutme-achievement-card", minimum: 1
    assert_select ".aboutme-stat[href=?] .aboutme-stat-value", "#cves", text: cves.length.to_s
    assert_select ".aboutme-stat[href=?]", "#bug-bounties", text: /Bug bounties/
    assert_select ".aboutme-stat[href=?]", "#my-challenges", text: /Created Challenges/
    assert_select ".aboutme-stat[href=?]", "#certificates", text: /Certificates/
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

    cves = JSON.parse(File.read(ApplicationController::ABOUTME_CVES_PATH))
    bug_bounties = JSON.parse(File.read(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH))
    challenges = JSON.parse(File.read(ApplicationController::ABOUTME_CHALLENGES_PATH))
    certificates = JSON.parse(File.read(ApplicationController::ABOUTME_CERTIFICATES_PATH))
    achievements = JSON.parse(File.read(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH))
    achievement_events = achievements.sum { |entry| Array(entry["events"]).length }
    ctf_posts = JSON.parse(File.read(ApplicationController::CTF_INFO_PATH)).sum do |name, metadata|
      directory = metadata["terminal_path"].presence || name.downcase
      Dir.glob(ApplicationController::BASE_PATH.join(directory, "*.md")).length
    end
    post_count = ctf_posts + Dir.glob(ApplicationController::BLOG_BASE_PATH.join("*.md")).length

    assert_response :success
    assert_select "h1", text: "Welcome to my bug collection 🐛"
    assert_select ".landing-action[href=?]", timeline_path, text: /Timeline/
    assert_select ".landing-action[href=?]", about_path, text: /About me/
    assert_select ".landing-metrics.aboutme-stats"
    assert_select ".landing-metric.aboutme-stat", 6
    assert_select ".landing-metric:first-child[href=?]", timeline_path, text: /Posts/
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#cves", text: cves.length.to_s
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#bug-bounties", text: bug_bounties.length.to_s
    assert_select ".landing-metric[href=?]", "#{about_path}#my-challenges", text: /Created Challenges/
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#my-challenges", text: challenges.length.to_s
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#certificates", text: certificates.length.to_s
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#achievements", text: achievement_events.to_s
    assert_select ".landing-metric[href=?] .landing-metric-value", timeline_path, text: post_count.to_s
    assert_select ".landing-metric[href=?] .landing-metric-sublabel", timeline_path, text: ContentRepository.new.format_reading_time(ContentRepository.new.total_post_reading_time_minutes)
    assert_select ".landing-featured-card", 3
  end

  test "about me content files have expected shape" do
    cves = JSON.parse(File.read(ApplicationController::ABOUTME_CVES_PATH))
    bug_bounties = JSON.parse(File.read(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH))
    challenges = JSON.parse(File.read(ApplicationController::ABOUTME_CHALLENGES_PATH))
    certificates = JSON.parse(File.read(ApplicationController::ABOUTME_CERTIFICATES_PATH))
    achievements = JSON.parse(File.read(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH))

    assert_kind_of Array, cves
    assert_kind_of Array, bug_bounties
    assert_kind_of Array, challenges
    assert_kind_of Array, certificates
    assert_kind_of Array, achievements
    assert cves.any? { |entry| entry["cve_id"] == "CVE-2026-39327" }
    assert_equal 12, cves.length
    assert_equal %w[
      joomla-com-users-batch-task-privilege-escalation
      joomla-com-tags-authenticated-blind-sqli
      joomla-com-finder-authenticated-blind-sqli
      suitecrm-tba-2
      suitecrm-tba-1
    ], cves.first(5).map { |entry| entry["id"] }
    assert cves.any? { |entry| entry["cve_id"] == "CVE-2026-35221" }
    assert cves.any? { |entry| entry["cve_id"] == "CVE-2026-35222" }
    assert cves.any? { |entry| entry["cve_id"] == "CVE-2026-48898" }
    assert_equal 0, cves.count { |entry| entry["project"] == "Joomla CMS" && entry["cve_id"].blank? }
    assert_equal 2, cves.count { |entry| entry["project"] == "SuiteCRM" && entry["cve_id"].blank? }
    assert bug_bounties.any? { |entry| entry["project"] == "Firedancer" && entry["title"].include?("TBA") }
    assert bug_bounties.any? { |entry| entry["project"] == "Firedancer" && entry["cve_id"].blank? }
    assert_equal 1, challenges.length
    assert_equal [ "smile-at-me" ], challenges.map { |entry| entry["id"] }
    assert_equal "Smile at me", challenges.first["title"]
    assert_nil challenges.first["details"]
    assert_includes challenges.first["summary"], "Published for GPNCTF 2025"
    assert_equal "GPNCTF 2025", challenges.first["category"]
    assert_equal "/ctf/gpnctf/Smile%20at%20me", challenges.first["title_url"]
    assert_equal "/ctf/gpnctf/Smile%20at%20me", challenges.first["card_url"]
    assert_equal "https://ctftime.org/ctf/854/", challenges.first["category_url"]
    assert_nil certificates.first["details"]
    assert_includes certificates.first["summary"], "full penetration-test report"
    assert_equal "/blog/htb-cpts", certificates.first["card_url"]
    assert_equal "https://www.credly.com/badges/a9a49759-8f35-4c46-8783-a11a4a1bfdf0/public_url", certificates.first["category_url"]
    assert_equal %w[
      firedancer-v1-audit-competition
      dhm
      cscg
      kitctf
    ], achievements.map { |entry| entry["id"] }
    dhm = achievements.find { |entry| entry["id"] == "dhm" }
    cscg = achievements.find { |entry| entry["id"] == "cscg" }
    assert_equal %w[dhm-2025 dhm-2024], dhm["events"].map { |event| event["id"] }
    assert_equal [
      "Participated in the DHM finals after qualifying through CSCG.",
      "Placed #1 at the Deutsche Hacking Meisterschaft."
    ], dhm["events"].map { |event| event["summary"] }
    assert_equal %w[cscg-2025 cscg-2024], cscg["events"].map { |event| event["id"] }
    assert_equal [
      "Qualified for DHM again and finished top 10 globally.",
      "Qualified for DHM through CSCG."
    ], cscg["events"].map { |event| event["summary"] }
    kitctf = achievements.find { |entry| entry["id"] == "kitctf" }
    assert_equal "https://ctftime.org/team/7221/", kitctf["title_url"]
    assert_equal %w[
      kitctf-glacierctf-2025
      kitctf-googlectf-2025
      kitctf-swampctf-2025
      kitctf-snakectf-finals-2024
      kitctf-glacierctf-2024
      kitctf-swampctf-2024
    ], kitctf["events"].map { |event| event["id"] }
    assert kitctf["events"].any? { |event| event["summary"] == "#3 at GlacierCTF, qualifying for DHM 2025 as KITCTF team." }
    assert kitctf["events"].any? { |event| event["summary"] == "#3 at SwampCTF." }
    assert kitctf["events"].any? { |event| event["summary"] == "#1 at SwampCTF." }
    assert kitctf["events"].any? { |event| event["summary"] == "Qualified for and participated in the SnakeCTF finals in Italy." }
    assert kitctf["events"].any? { |event| event["summary"] == "#6 at Google CTF as the FluxKITtens merger team (FluxFingers and KITCTF), qualifying for the Hackceler8 finals in Mexico." }

    (cves + bug_bounties).each do |entry|
      assert entry["project"].present?
      assert entry["project_url"].present?
      assert entry["title"].present?
      assert_kind_of Array, entry["timeline"] if entry["timeline"].present?
    end

    cves.reject { |entry| entry["id"].include?("tba") }.each do |entry|
      assert entry["cve_id"].present?
      assert entry["cwe_id"].present?
      assert entry.fetch("references", []).any? { |link| link["url"] == "https://www.cve.org/CVERecord?id=#{entry["cve_id"]}" }
    end

    (challenges + certificates + achievements).each do |entry|
      assert entry["title"].present?
      assert entry["category"].present?
    end
  end
end
