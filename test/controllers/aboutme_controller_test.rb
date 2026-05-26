require "test_helper"

class AboutmeControllerTest < ActionDispatch::IntegrationTest
  test "shows about me page with security sections" do
    get about_path

    assert_response :success
    assert_select "main.aboutme-page"
    assert_select ".taskbar-link[href=?]", about_path, text: /About me/
    assert_select ".aboutme-section-title", text: "CVEs"
    assert_select ".aboutme-section-title", text: "Bug bounties"
    assert_select ".aboutme-section-title", text: "Certificates"
    assert_select ".aboutme-section-title", text: "Relevant achievements"
    assert_select ".aboutme-finding-card", minimum: 1
    assert_select ".aboutme-achievement-card", minimum: 1
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

  test "about me content files have expected shape" do
    cves = JSON.parse(File.read(ApplicationController::ABOUTME_CVES_PATH))
    bug_bounties = JSON.parse(File.read(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH))
    certificates = JSON.parse(File.read(ApplicationController::ABOUTME_CERTIFICATES_PATH))
    achievements = JSON.parse(File.read(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH))

    assert_kind_of Array, cves
    assert_kind_of Array, bug_bounties
    assert_kind_of Array, certificates
    assert_kind_of Array, achievements
    assert cves.any? { |entry| entry["cve_id"] == "CVE-2026-39327" }
    assert_equal 11, cves.length
    assert_equal %w[
      suitecrm-tba-2
      suitecrm-tba-1
      joomla-tba-2
      joomla-tba-1
    ], cves.first(4).map { |entry| entry["id"] }
    assert_equal 2, cves.count { |entry| entry["project"] == "Joomla CMS" && entry["cve_id"].blank? }
    assert_equal 2, cves.count { |entry| entry["project"] == "SuiteCRM" && entry["cve_id"].blank? }
    assert bug_bounties.any? { |entry| entry["project"] == "Firedancer" && entry["title"].include?("TBA") }
    assert bug_bounties.any? { |entry| entry["project"] == "Firedancer" && entry["cve_id"].blank? }
    assert_equal %w[
      firedancer-v1-audit-competition-tba
      dhm-2025
      dhm-2024
    ], achievements.map { |entry| entry["id"] }

    (cves + bug_bounties).each do |entry|
      assert entry["project"].present?
      assert entry["project_url"].present?
      assert entry["title"].present?
      assert_kind_of Array, entry["timeline"] if entry["timeline"].present?
    end

    cves.reject { |entry| entry["id"].include?("tba") }.each do |entry|
      assert entry["cve_id"].present?
    end

    (certificates + achievements).each do |entry|
      assert entry["title"].present?
      assert entry["category"].present?
    end
  end
end
