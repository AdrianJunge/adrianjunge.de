require "test_helper"

class AboutmeFindingCardTest < ActionView::TestCase
  test "finding card renders collapsible vulnerability details" do
    render partial: "aboutme/card", locals: {
      kind: "cve",
      entry: {
        "title" => "Example Project",
        "subtitle" => "Example advisory title",
        "summary" => "An authenticated user could inject script into a report title rendered to other users, allowing session actions in affected user contexts.",
        "tags" => [
          "High",
          { "label" => "CVE-2026-0001", "url" => "https://www.cve.org/CVERecord?id=CVE-2026-0001" },
          { "label" => "CWE-79", "url" => "https://cwe.mitre.org/data/definitions/79.html" }
        ],
        "links" => [
          { "label" => "Repository", "url" => "https://github.com/example/project" },
          { "label" => "Advisory source", "url" => "https://github.com/example/project/security/advisories/GHSA-example" }
        ],
        "timeline" => [
          { "date" => "2026-01-01", "title" => "Reported to maintainer" }
        ]
      }
    }

    assert_select "article.aboutme-finding-card-cve[data-card-disclosure] > details.profile-card-details"
    assert_select "article[role='button'], article[tabindex]", 0
    assert_select "summary[aria-label='Details for Example Project']", text: "Details"
    assert_select ".aboutme-card-header .aboutme-finding-main > .aboutme-finding-project:first-child"
    assert_select ".aboutme-card-header .aboutme-finding-project + .aboutme-finding-badges"
    assert_select "summary a, summary button", 0
    assert_select "summary .aboutme-finding-project-link", 0
    assert_select "summary a[href=?]", "https://github.com/example/project", 0
    assert_select "summary a[href=?]", "https://github.com/example/project/security/advisories/GHSA-example", 0
    assert_select "summary .aboutme-finding-summary-link.aboutme-finding-advisory-link", 0
    assert_select ".aboutme-cve-id.cve-badge[href=?][target=?][rel=?]", "https://www.cve.org/CVERecord?id=CVE-2026-0001", "_blank", "noopener noreferrer", text: "CVE-2026-0001"
    assert_select ".aboutme-cwe-id.cwe-badge[href=?][target=?][rel=?]", "https://cwe.mitre.org/data/definitions/79.html", "_blank", "noopener noreferrer", text: "CWE-79"
    assert_select ".aboutme-detail-block", text: /allowing session actions/
    assert_select ".aboutme-detail-block h3", text: "References"
    assert_select ".aboutme-card-details .aboutme-reference-link[href=?][aria-label=?][title=?]",
                  "https://github.com/example/project",
                  "Open Repository",
                  "Open Repository",
                  text: "Repository"
    assert_select ".aboutme-card-details .aboutme-reference-link", { text: /CVE record:/, count: 0 }
    assert_select ".aboutme-card-details .aboutme-reference-link", { text: /CWE entry:/, count: 0 }
    assert_select ".aboutme-card-details .aboutme-reference-link[href=?][aria-label=?][title=?]",
                  "https://github.com/example/project/security/advisories/GHSA-example",
                  "Open Advisory source",
                  "Open Advisory source",
                  text: "Advisory source"
    assert_select "dt", 0
    assert_no_match(/Status/, rendered)
    assert_no_match(/Duplicate CVE reference/, rendered)
    assert_no_match(/Duplicate project reference/, rendered)
    assert_no_match(/External analysis/, rendered)
    assert_select ".aboutme-link-row", 0
    assert_select ".aboutme-detail-block h3", text: "Disclosure timeline"
    assert_select ".aboutme-timeline li", 1
  end

  test "finding card omits CVE fields when no CVE ID is present" do
    render partial: "aboutme/card", locals: {
      kind: "bug-bounty",
      entry: {
        "title" => "Firedancer bug bounty finding",
        "tags" => [ "TBA" ]
      }
    }

    assert_select "details.aboutme-finding-card-bug-bounty", 0
    assert_select "article.aboutme-finding-card-static.aboutme-finding-card-bug-bounty"
    assert_select "[data-card-disclosure]", 0
    assert_select ".aboutme-cve-id", 0
    assert_select ".aboutme-cwe-id", 0
    assert_no_match(/CVE ID/, rendered)
    assert_no_match(/No CVE assigned/, rendered)
  end

  test "TBA CVE finding stays static while showing the expected CVE badge" do
    render partial: "aboutme/card", locals: {
      kind: "cve",
      entry: {
        "title" => "SuiteCRM",
        "subtitle" => "SuiteCRM advisory #1 (TBA)",
        "tags" => [ "TBA" ]
      }
    }

    assert_select "details.aboutme-finding-card-cve", 0
    assert_select "article.aboutme-finding-card-static.aboutme-finding-card-cve"
    assert_select ".aboutme-tag-tba", text: "TBA"
    assert_select ".aboutme-cve-id", 0
    assert_no_match(/GHSA-xxxx-xxxx-xxxx/, rendered)
    assert_no_match(/Disclosure timeline/, rendered)
  end

  test "finding card omits empty fields and nested empty groups" do
    render partial: "aboutme/card", locals: {
      kind: "bug-bounty",
      entry: {
        "title" => "Firedancer bug bounty finding"
      }
    }

    assert_select "article.aboutme-finding-card-static.aboutme-finding-card-bug-bounty"
    assert_select ".aboutme-finding-badges", 0
    assert_select ".aboutme-detail-block", 0
    assert_no_match(/Info/, rendered)
  end
end
