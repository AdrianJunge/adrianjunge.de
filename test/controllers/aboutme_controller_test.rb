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
    assert_select ".aboutme-stat[href=?]", "#my-challenges", text: /Challenges/
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
    certificates = JSON.parse(File.read(ApplicationController::ABOUTME_CERTIFICATES_PATH))
    achievements = JSON.parse(File.read(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH))

    assert_response :success
    assert_select "h1", text: "Welcome to my bug collection 🐛"
    assert_select ".landing-action[href=?]", "/posts-timeline", text: /Posts timeline/
    assert_select ".landing-action[href=?]", about_path, text: /About me/
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#cves", text: cves.length.to_s
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#bug-bounties", text: bug_bounties.length.to_s
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#certificates", text: certificates.length.to_s
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#achievements", text: achievements.length.to_s
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
    assert_equal "GPNCTF 2025", challenges.first["category"]
    assert_equal "/ctf/gpnctf/Smile%20at%20me", challenges.first["title_url"]
    assert_equal %w[
      firedancer-v1-audit-competition-tba
      dhm
      cscg
      kitctf
    ], achievements.map { |entry| entry["id"] }
    dhm = achievements.find { |entry| entry["id"] == "dhm" }
    cscg = achievements.find { |entry| entry["id"] == "cscg" }
    assert_equal "2025, 2024", dhm["date"]
    assert_equal [
      "2025: Participated in the DHM finals after qualifying through CSCG.",
      "2024: Placed #1 at the Deutsche Hacking Meisterschaft."
    ], dhm["details"]
    assert_equal "2025, 2024", cscg["date"]
    assert_equal [
      "2025: Qualified for DHM again and finished top 10 globally.",
      "2024: Qualified for DHM through CSCG."
    ], cscg["details"]
    kitctf = achievements.find { |entry| entry["id"] == "kitctf" }
    assert_equal "https://ctftime.org/team/7221/", kitctf["title_url"]
    assert kitctf["details"].include?("2025: #3 at GlacierCTF, qualifying for DHM 2025 as KITCTF team.")
    assert kitctf["details"].include?("2025: #3 at SwampCTF.")
    assert kitctf["details"].include?("2024: #3 at GlacierCTF.")
    assert kitctf["details"].include?("2024: #1 at SwampCTF.")
    assert kitctf["details"].include?("2024: Participated in the SnakeCTF finals in Italy.")
    assert kitctf["details"].include?("2025: #6 at GoogleCTF as the FluxKITtens merger team (FluxFingers & KITCTF), and qualified for the finals in Mexico.")

    (cves + bug_bounties).each do |entry|
      assert entry["project"].present?
      assert entry["project_url"].present?
      assert entry["title"].present?
      assert_kind_of Array, entry["timeline"] if entry["timeline"].present?
    end

    cves.reject { |entry| entry["id"].include?("tba") }.each do |entry|
      assert entry["cve_id"].present?
      assert entry.fetch("references", []).any? { |link| link["url"] == "https://www.cve.org/CVERecord?id=#{entry["cve_id"]}" }
    end

    (challenges + certificates + achievements).each do |entry|
      assert entry["title"].present?
      assert entry["category"].present?
    end
  end
end
