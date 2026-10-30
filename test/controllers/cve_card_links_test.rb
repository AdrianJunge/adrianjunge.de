require "test_helper"

class CveCardLinksTest < ActionDispatch::IntegrationTest
  test "every About CVE card starts with record links and SuiteCRM includes its severity" do
    get about_path
    assert_response :success

    cards = css_select(".aboutme-finding-card-cve")
    assert cards.any?
    labels = cards.map { |card| card.at_css("summary")["aria-label"] }
    assert_equal labels.uniq, labels, "CVE disclosure names must distinguish findings in the same project"
    cards.each do |card|
      tags = card.css(".aboutme-finding-badges > .aboutme-card-tag")
      assert ContentVulnerabilityTag.cve?(tags.first.text), "Expected a CVE first on #{card['id']}"
      tags.select { |tag| ContentVulnerabilityTag.cve?(tag.text) }.each do |tag|
        assert_equal "a", tag.name
        assert_equal "https://www.cve.org/CVERecord?id=#{tag.text.strip}", tag["href"]
        assert_not_includes tag["class"], "aboutme-tag-timeline"
        assert_includes card["aria-label"], tag.text.strip
        assert_includes card.at_css("summary")["aria-label"], tag.text.strip
      end
      card.css(".cwe-badge").each do |tag|
        assert_equal "a", tag.name
        assert_equal "https://cwe.mitre.org/data/definitions/#{tag.text.strip.delete_prefix('CWE-').to_i}.html", tag["href"]
        assert tag.at_css(".content-tag-label")
        assert tag.at_css(".content-tag-chevron[aria-hidden='true']")
      end
    end
    assert_select "#suitecrm-portal-get-entry-list-sql-injection .severity-badge-high", text: "High"
  end

  test "timeline CVE cards start with record links while the filter panel retains CVE buttons" do
    get timeline_path
    assert_response :success

    cards = css_select(".timeline-content").select { |card| card.at_css(".timeline-tags .cve-badge") }
    assert cards.any?
    labels = cards.map { |card| card.at_css(".timeline-card-hitbox")["aria-label"] }
    assert_equal labels.uniq, labels, "CVE card links must distinguish findings in the same project"
    cards.each do |card|
      tags = card.css(".timeline-tags > .content-tag")
      assert ContentVulnerabilityTag.cve?(tags.first.at_css(".content-tag-label").text), "Expected a CVE first on #{card.at_css('.timeline-title').text}"
      card.css(".timeline-tags .cve-badge, .timeline-tags .cwe-badge").each do |tag|
        identifier = tag.at_css(".content-tag-label").text
        assert_equal "a", tag.name
        expected_url = identifier.start_with?("CVE-") ? "https://www.cve.org/CVERecord?id=#{identifier}" : "https://cwe.mitre.org/data/definitions/#{identifier.delete_prefix('CWE-').to_i}.html"
        assert_equal expected_url, tag["href"]
        assert_nil tag["data-filter-tag"]
        assert tag.at_css(".content-tag-chevron[aria-hidden='true']")
        assert_select ".content-filter-panel button[data-filter-scope='timeline'][data-filter-tag=?]", identifier, 1
      end
    end
    suitecrm_card = cards.find { |card| card.at_css(".timeline-card-hitbox")["href"] == "/about#suitecrm-portal-get-entry-list-sql-injection" }
    assert suitecrm_card
    assert_equal "High", suitecrm_card.at_css(".severity-badge-high .content-tag-label").text
  end
end
