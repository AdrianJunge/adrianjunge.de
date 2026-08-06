require "test_helper"

class AboutmeControllerTest < ActionDispatch::IntegrationTest
  test "shows about me page with security sections" do
    get about_path
    repository = ContentRepository.new
    cves = repository.about_entries(ApplicationController::ABOUTME_CVES_PATH)
    bug_bounties = repository.about_entries(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH)

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
    assert_select ".aboutme-stat[href=?] .aboutme-stat-value", "#bug-bounties", text: bug_bounties.length.to_s
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
    bug_bounties = repository.about_entries(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH)

    assert_response :success
    assert_select "h1", text: "Welcome to my bug collection 🐛"
    assert_select ".landing-action[href=?]", timeline_path, text: /Timeline/
    assert_select ".landing-action[href=?]", about_path, text: /About me/
    assert_select ".landing-metrics.aboutme-stats"
    assert_select ".landing-metric.aboutme-stat", 4
    assert_select ".landing-metric:first-child[href=?]", timeline_path, text: /Posts/
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#cves", text: cves.length.to_s
    assert_select ".landing-metric[href=?] .landing-metric-value", "#{about_path}#bug-bounties", text: bug_bounties.length.to_s
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
    repository = ContentRepository.new
    cves = parse_content_json(ApplicationController::ABOUTME_CVES_PATH)
    bug_bounties = parse_content_json(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH)
    challenge_records = parse_content_json(ApplicationController::ABOUTME_CHALLENGES_PATH)
    challenges = repository.authored_challenges
    certificates = parse_content_json(ApplicationController::ABOUTME_CERTIFICATES_PATH)
    talks = parse_content_json(ApplicationController::ABOUTME_TALKS_PATH)
    achievements = parse_content_json(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH)

    assert_kind_of Array, cves
    assert_kind_of Array, bug_bounties
    assert_kind_of Array, challenge_records
    assert_kind_of Array, certificates
    assert_kind_of Array, talks
    assert_kind_of Array, achievements
    assert_equal 26, cves.length
    assert_equal %w[
      ffmpeg-dvbsub-parser-integer-overflow-out-of-bounds-write
      ffmpeg-rscc-uninitialized-heap-memory-disclosure
      ffmpeg-screenpresso-uninitialized-heap-memory-disclosure
      ffmpeg-tiff-uninitialized-heap-memory-disclosure
      ffmpeg-cfhd-transform2-out-of-bounds-write
    ], cves.first(5).map { |entry| entry["id"] }
    assert_equal "suitecrm-map-markers-distance-authenticated-sqli", cves[5]["id"]
    assert_equal %w[
      ffmpeg-vf-hqdn3d-dynamic-resolution-out-of-bounds-write
      ffmpeg-iamf-demuxer-uncontrolled-resource-consumption
      ffmpeg-lcl-zlib-uninitialized-memory-disclosure
      ffmpeg-mace6-integer-overflow-out-of-bounds-write
      ffmpeg-png-apng-exif-out-of-bounds-write
      ffmpeg-vf-quirc-dynamic-resolution-out-of-bounds-write
    ], cves.slice(6, 6).map { |entry| entry["id"] }
    assert_equal %w[
      ffmpeg-tdsc-video-decoder-out-of-bounds-write
      ffmpeg-ty-shorten-out-of-bounds-write
      ffmpeg-vf-floodfill-out-of-bounds-write
      ffmpeg-vf-swaprect-out-of-bounds-write
      joomla-com-users-batch-task-privilege-escalation
    ], cves.slice(12, 5).map { |entry| entry["id"] }
    cve_tag_labels = cves.flat_map { |entry| entry.fetch("tags", []) }.filter_map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }
    assert_includes cve_tag_labels, "CVE-2026-70628"
    assert_includes cve_tag_labels, "CVE-2026-70629"
    assert_includes cve_tag_labels, "CVE-2026-70630"
    assert_includes cve_tag_labels, "CVE-2026-70631"
    assert_includes cve_tag_labels, "CVE-2026-70632"
    assert_includes cve_tag_labels, "CVE-2026-69142"
    assert_includes cve_tag_labels, "CVE-2026-66036"
    assert_includes cve_tag_labels, "CVE-2026-66037"
    assert_includes cve_tag_labels, "CVE-2026-66038"
    assert_includes cve_tag_labels, "CVE-2026-66039"
    assert_includes cve_tag_labels, "CVE-2026-66040"
    assert_includes cve_tag_labels, "CVE-2026-66041"
    assert_includes cve_tag_labels, "CVE-2026-65703"
    assert_includes cve_tag_labels, "CVE-2026-65704"
    assert_includes cve_tag_labels, "CVE-2026-65705"
    assert_includes cve_tag_labels, "CVE-2026-65706"
    assert_includes cve_tag_labels, "CVE-2026-39327"
    assert_includes cve_tag_labels, "CVE-2026-35221"
    assert_includes cve_tag_labels, "CVE-2026-35222"
    assert_includes cve_tag_labels, "CVE-2026-48898"
    august_ffmpeg_cves = cves.first(5)
    assert_equal [
      %w[2026-07-24 2026-07-24 2026-07-29 2026-08-04 2026-08-06],
      %w[2026-07-24 2026-07-24 2026-07-29 2026-08-04 2026-08-06],
      %w[2026-07-24 2026-07-24 2026-07-27 2026-08-04 2026-08-06],
      %w[2026-07-24 2026-07-24 2026-07-30 2026-08-04 2026-08-06],
      %w[2026-07-24 2026-07-24 2026-07-31 2026-08-04 2026-08-06]
    ], august_ffmpeg_cves.map { |entry| entry["timeline"].map { |event| event["date"] } }
    assert august_ffmpeg_cves.all? { |entry| entry["timeline"].first["title"] == "Reported the vulnerability to the FFmpeg security team." }
    assert august_ffmpeg_cves.all? { |entry| entry.dig("timeline", -2) == { "date" => "2026-08-04", "title" => "Requested a CVE through VulnCheck." } }
    assert august_ffmpeg_cves.all? { |entry| entry["timeline"].last["title"] == "CVE published." }
    suitecrm_cve = cves.find { |entry| entry["id"] == "suitecrm-map-markers-distance-authenticated-sqli" }
    assert suitecrm_cve
    assert_equal %w[2026-03-28 2026-03-31 2026-05-21 2026-08-05], suitecrm_cve["timeline"].map { |event| event["date"] }
    assert_equal "CVE assigned and security advisory published.", suitecrm_cve["timeline"].last["title"]
    july_ffmpeg_cves = cves.slice(6, 6)
    assert_equal [
      %w[2026-07-08 2026-07-12 2026-07-22 2026-07-24 2026-07-24],
      %w[2026-06-24 2026-06-28 2026-06-28 2026-07-24 2026-07-24],
      %w[2026-06-24 2026-06-28 2026-07-05 2026-07-24 2026-07-24],
      %w[2026-06-26 2026-06-28 2026-07-03 2026-07-24 2026-07-24],
      %w[2026-07-11 2026-07-12 2026-07-21 2026-07-24 2026-07-24],
      %w[2026-06-24 2026-06-28 2026-07-05 2026-07-24 2026-07-24]
    ], july_ffmpeg_cves.map { |entry| entry["timeline"].map { |event| event["date"] } }
    assert july_ffmpeg_cves.all? { |entry| entry.dig("timeline", -2) == { "date" => "2026-07-24", "title" => "Requested a CVE through VulnCheck." } }
    assert july_ffmpeg_cves.all? { |entry| entry["timeline"].last["date"] == "2026-07-24" }
    previous_ffmpeg_cve_ids = %w[
      ffmpeg-tdsc-video-decoder-out-of-bounds-write
      ffmpeg-ty-shorten-out-of-bounds-write
      ffmpeg-vf-floodfill-out-of-bounds-write
      ffmpeg-vf-swaprect-out-of-bounds-write
    ]
    ffmpeg_cves = cves.select { |entry| previous_ffmpeg_cve_ids.include?(entry["id"]) }
    assert_equal [
      %w[2026-06-28 2026-07-11 2026-07-13 2026-07-17 2026-07-23],
      %w[2026-06-28 2026-07-11 2026-07-13 2026-07-17 2026-07-23],
      %w[2026-06-29 2026-07-12 2026-07-13 2026-07-17 2026-07-23],
      %w[2026-06-29 2026-07-11 2026-07-13 2026-07-17 2026-07-23]
    ], ffmpeg_cves.map { |entry| entry["timeline"].map { |event| event["date"] } }
    assert ffmpeg_cves.all? { |entry| entry["timeline"].any? { |event| event == { "date" => "2026-07-17", "title" => "Requested a CVE through VulnCheck." } } }
    assert ffmpeg_cves.all? { |entry| entry["timeline"].last["date"] == "2026-07-23" }
    assert_not cves.any? { |entry| entry["id"].include?("suitecrm-tba") }
    assert_operator bug_bounties.length, :>=, 1
    firedancer = bug_bounties.find { |entry| entry["id"] == "frankendancer-netshred-overrun" }
    assert firedancer
    assert_equal "Firedancer", firedancer["title"]
    assert_equal "Race condition in the netshred module", firedancer["subtitle"]
    assert_includes repository.about_entries(ApplicationController::ABOUTME_BUG_BOUNTIES_PATH).map { |entry| entry["id"] }, firedancer["id"]
    assert_operator challenge_records.length, :>=, 2
    assert_operator challenges.length, :>=, 2
    assert_equal challenge_records.map { |entry| entry["id"] }.sort, challenges.map { |entry| entry["id"] }.sort
    scanwich = challenges.find { |entry| entry["id"] == "scanwich-station" }
    smile_at_me = challenges.find { |entry| entry["id"] == "smile-at-me" }
    assert scanwich
    assert smile_at_me
    assert_equal "Scanwich Station", scanwich["title"]
    assert_nil scanwich["subtitle"]
    assert_includes scanwich["summary"], "Published for GPNCTF 2026"
    assert_nil scanwich["url"]
    assert_equal "https://gpn24.ctf.kitctf.de/", scanwich["tags"].first["url"]
    assert_includes scanwich["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "GPNCTF 2026"
    assert_includes scanwich["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Hard"
    assert_includes scanwich["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Web"
    assert_includes scanwich["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Pwn"
    assert_includes scanwich["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Writeup"
    assert_nil scanwich["date"]
    assert_equal "2026-06-05", scanwich.dig("timeline", 0, "date")
    assert_includes smile_at_me["summary"], "Published for GPNCTF 2025"
    assert_nil smile_at_me["url"]
    assert_includes smile_at_me["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "GPNCTF 2025"
    assert_includes smile_at_me["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Hard"
    assert_includes smile_at_me["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Web"
    assert_includes smile_at_me["tags"].map { |tag| tag.is_a?(Hash) ? tag["label"] : tag }, "Writeup"
    assert_nil smile_at_me["date"]
    assert_equal "2025-06-21", smile_at_me.dig("timeline", 0, "date")
    assert_nil certificates.first["subtitle"]
    assert_nil certificates.first["date"]
    assert_equal %w[2026-02-02 2026-03-13 2026-03-23], certificates.first["timeline"].map { |event| event["date"] }
    assert_includes certificates.first["summary"], "full penetration-test report"
    assert_nil certificates.first["url"]
    assert_equal [ "Certificate", "Writeup" ], certificates.first["tags"].map { |tag| tag["label"] }
    assert_equal "https://www.credly.com/badges/a9a49759-8f35-4c46-8783-a11a4a1bfdf0/public_url", certificates.first["tags"].first["url"]
    assert_equal 2, talks.length
    kitctf_talk = talks.find { |entry| entry["id"] == "kitctf-web-intro" }
    joomla_talk = talks.find { |entry| entry["id"] == "joomla-sqli" }
    assert_equal "KITCTF Web Intro", kitctf_talk["title"]
    assert_nil kitctf_talk["date"]
    assert_equal "2026-05-07", kitctf_talk.dig("timeline", 0, "date")
    assert_equal [ "Slides", "Overview" ], kitctf_talk["tags"].map { |tag| tag["label"] }
    assert_equal "https://kitctf.de/talks/2026-05-07-web/web-26-ss.pdf", kitctf_talk["tags"].first["url"]
    assert_equal "Teaching AI to hack Joomla so I can skip my homework", joomla_talk["title"]
    assert_equal "2026-07-09", joomla_talk.dig("timeline", 0, "date")
    assert_equal "/talks/teaching-ai-to-hack-joomla.pdf", joomla_talk.dig("tags", 0, "url")
    achievement_ids = achievements.map { |entry| entry["id"] }
    assert_includes achievement_ids, "immunefi"
    assert_includes achievement_ids, "dhm"
    assert_includes achievement_ids, "cscg"
    assert_includes achievement_ids, "kitctf"
    visible_achievement_ids = repository.about_entries(ApplicationController::ABOUTME_ACHIEVEMENTS_PATH).map { |entry| entry["id"] }
    assert_includes visible_achievement_ids, "immunefi"
    assert_includes visible_achievement_ids, "dhm"
    assert_includes visible_achievement_ids, "cscg"
    assert_includes visible_achievement_ids, "kitctf"
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
