require "application_system_test_case"

class AboutmeTest < ApplicationSystemTestCase
  test "visiting about me page renders the public profile sections" do
    visit about_path

    assert_selector "main.aboutme-page"
    assert_selector ".taskbar-link[href='/about']", text: "About me", visible: :all
    assert_text "CVEs"
    assert_text "Bug bounties"
    assert_text "Created CTF Challenges"
    assert_text "Certificates"
    assert_text "Relevant achievements"
    assert_text "CVE-2026-39327"
    assert_text "CVE-2026-35221"
    assert_text "CVE-2026-35222"
    assert_text "CVE-2026-48898"
    assert_text "Privilege escalation through com_users batch task"
    assert_text "Authenticated blind SQL injection in com_finder"
    assert_text "Authenticated blind SQL injection in com_tags"
    assert_text "SuiteCRM advisory #1 (TBA)"
    assert_text "SuiteCRM advisory #2 (TBA)"
    assert_text "Firedancer bug bounty finding (TBA)"
    assert_text "Smile at me"
    assert_text "GPNCTF 2025"
    assert_text "Web challenge about URL parser differentials"
    assert_selector "#my-challenges a[href='/ctf/gpnctf/Smile%20at%20me']", text: "Read writeup"
    assert_no_text "Public advisories"
    assert_no_text "Responsible disclosure"
    assert_no_text "Credentials"
    assert_no_text "Milestones"
    within "#achievements" do
      assert_no_text "Computer Science master's student at KIT"
    end
    assert_no_text "Placeholder"
    assert_no_text "Pending disclosure"
    assert_no_text "Details will be added"
    assert_selector "#cves article.aboutme-finding-card-static", minimum: 1
    assert_selector "#cves details.aboutme-finding-card-cve", minimum: 1
    assert_selector "#bug-bounties article.aboutme-finding-card-static"
    assert_no_selector "#bug-bounties details"
    assert_selector ".aboutme-achievement-card", minimum: 1
  end

  test "about me page stays within narrow mobile viewports" do
    [ [ 390, 1200 ], [ 320, 1200 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      visit about_path

      overflow = page.evaluate_script(<<~JS)
        document.documentElement.scrollWidth - document.documentElement.clientWidth
      JS

      assert_operator overflow, :<=, 1, "expected no horizontal overflow at #{width}px"
      assert_selector "main.aboutme-page"
      assert_text "About me"
      assert_text "Certificates"
      assert_text "Created CTF Challenges"
      assert_text "Relevant achievements"
    end
  end

  test "about me entry cards stay full width on desktop" do
    page.current_window.resize_to(1280, 1400)
    visit about_path

    cve_card_positions = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#cves .aboutme-finding-card"))
        .slice(0, 2)
        .map((card) => Math.round(card.getBoundingClientRect().top))
    JS
    achievement_card_positions = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#achievements .aboutme-achievement-card"))
        .slice(0, 2)
        .map((card) => Math.round(card.getBoundingClientRect().top))
    JS

    assert_operator cve_card_positions.second, :>, cve_card_positions.first
    assert_operator achievement_card_positions.second, :>, achievement_card_positions.first
  end

  test "my challenges link to their writeups" do
    visit about_path

    within "#my-challenges" do
      assert_text "Smile at me"
      assert_text "CTF challenge published for GPNCTF 2025."
      click_link "Read writeup"
    end

    assert_current_path "/ctf/gpnctf/Smile%20at%20me"
    assert_text "Smile at me"
    assert_text "I'm the author of this challenge"
  end

  test "about me entries are ordered newest first" do
    visit about_path

    first_cve_title = page.evaluate_script(<<~JS)
      document.querySelector("#cves .aboutme-finding-card .aboutme-finding-summary").innerText.trim()
    JS
    achievement_titles = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#achievements .aboutme-achievement-card h3"))
        .map((heading) => heading.innerText.trim())
    JS
    achievement_details = page.evaluate_script(<<~JS)
      Object.fromEntries(
        Array.from(document.querySelectorAll("#achievements .aboutme-achievement-card")).map((card) => [
          card.querySelector("h3").innerText.trim(),
          Array.from(card.querySelectorAll(".aboutme-achievement-details li")).map((detail) => detail.innerText.trim())
        ])
      )
    JS

    assert_equal "Privilege escalation through com_users batch task", first_cve_title
    assert_equal [
      "Firedancer v1.0 audit competition (TBA)",
      "DHM",
      "CSCG",
      "KITCTF"
    ], achievement_titles
    assert_equal [
      "2025: Participated in the DHM finals after qualifying through CSCG.",
      "2024: Placed #1 at the Deutsche Hacking Meisterschaft."
    ], achievement_details["DHM"]
    assert_equal [
      "2025: Qualified for DHM again and finished top 10 globally.",
      "2024: Qualified for DHM through CSCG."
    ], achievement_details["CSCG"]
    assert_text "2024: Placed #1 at the Deutsche Hacking Meisterschaft."
    assert_text "2025: Participated in the DHM finals after qualifying through CSCG."
    assert_text "2024: Qualified for DHM through CSCG."
    assert_text "2025: Qualified for DHM again and finished top 10 globally."
    assert_text "2025: #3 at GlacierCTF, qualifying for DHM 2025 as KITCTF team."
    assert_text "2025: #3 at SwampCTF."
    assert_text "2024: #3 at GlacierCTF."
    assert_text "2024: #1 at SwampCTF."
    assert_text "2024: Participated in the SnakeCTF finals in Italy."
    assert_text "2025: #6 at GoogleCTF as the FluxKITtens merger team (FluxFingers & KITCTF), and qualified for the finals in Mexico."
  end
end
