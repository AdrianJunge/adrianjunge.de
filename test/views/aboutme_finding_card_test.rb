require "test_helper"

class AboutmeFindingCardTest < ActionView::TestCase
  test "finding card renders collapsible vulnerability details" do
    render partial: "aboutme/finding_card", locals: {
      kind: "cve",
      entry: {
        "project" => "Example Project",
        "project_url" => "https://github.com/example/project",
        "title" => "Example advisory title",
        "title_url" => "https://github.com/example/project/security/advisories/GHSA-example",
        "cve_id" => "CVE-2026-0001",
        "severity" => "High",
        "short_summary" => "Stored cross-site scripting in report titles.",
        "summary" => "An authenticated user could inject script into a report title rendered to other users.",
        "tested_version" => "1.2.3",
        "impact" => "Session actions in affected user contexts.",
        "github_advisories" => [
          { "label" => "GHSA-example", "url" => "https://github.com/advisories/GHSA-example" }
        ],
        "timeline" => [
          { "date" => "2026-01-01", "event" => "Reported to maintainer" }
        ]
      }
    }

    assert_select "details.aboutme-finding-card-cve"
    assert_select "summary", text: /Example Project/
    assert_select "summary .aboutme-finding-main > .aboutme-finding-project:first-child"
    assert_select "summary .aboutme-finding-project + .aboutme-finding-badges"
    assert_select "summary a[href=?][target=?][rel=?]", "https://github.com/example/project", "_blank", "noopener noreferrer"
    assert_select "summary a[href=?][target=?][rel=?]", "https://github.com/example/project/security/advisories/GHSA-example", "_blank", "noopener noreferrer", text: "Example advisory title"
    assert_select ".aboutme-cve-id", text: "CVE-2026-0001"
    assert_select "dt", text: "Tested version"
    assert_select "dd", text: "1.2.3"
    assert_select "dt", text: "Status", count: 0
    assert_select ".aboutme-detail-block h3", text: "Disclosure timeline"
    assert_select ".aboutme-timeline li", 1
  end

  test "finding card omits CVE fields when no CVE ID is present" do
    render partial: "aboutme/finding_card", locals: {
      kind: "bug-bounty",
      entry: {
        "project" => "Firedancer",
        "project_url" => "https://github.com/firedancer-io/firedancer",
        "title" => "Firedancer bug bounty finding (TBA)",
        "title_url" => "https://immunefi.com/bug-bounty/firedancer/information/",
        "severity" => "TBA"
      }
    }

    assert_select "details.aboutme-finding-card-bug-bounty", 0
    assert_select "article.aboutme-finding-card-static.aboutme-finding-card-bug-bounty"
    assert_select ".aboutme-cve-id", 0
    assert_no_match(/CVE ID/, rendered)
    assert_no_match(/No CVE assigned/, rendered)
  end

  test "TBA CVE finding stays static while showing the expected CVE badge" do
    render partial: "aboutme/finding_card", locals: {
      kind: "cve",
      entry: {
        "project" => "SuiteCRM",
        "project_url" => "https://github.com/salesagility/SuiteCRM",
        "title" => "SuiteCRM advisory #1 (TBA)",
        "title_url" => "https://github.com/salesagility/SuiteCRM",
        "severity" => "TBA",
        "cve_id" => "TBA",
        "summary" => "TBA",
        "tested_version" => "TBA",
        "impact" => "TBA",
        "github_advisories" => [
          { "label" => "GHSA-xxxx-xxxx-xxxx", "url" => "" }
        ],
        "timeline" => [
          { "date" => "2026-", "event" => "" }
        ],
        "references" => [
          { "label" => "SuiteCRM repository", "url" => "https://github.com/salesagility/SuiteCRM" }
        ]
      }
    }

    assert_select "details.aboutme-finding-card-cve", 0
    assert_select "article.aboutme-finding-card-static.aboutme-finding-card-cve"
    assert_select ".aboutme-severity", text: "TBA"
    assert_select ".aboutme-cve-id", text: "TBA"
    assert_no_match(/GHSA-xxxx-xxxx-xxxx/, rendered)
    assert_no_match(/Tested version/, rendered)
    assert_no_match(/Disclosure timeline/, rendered)
  end

  test "finding card omits empty fields and nested empty groups" do
    render partial: "aboutme/finding_card", locals: {
      kind: "bug-bounty",
      entry: {
        "project" => "Firedancer",
        "project_url" => "https://github.com/firedancer-io/firedancer",
        "title" => "Firedancer bug bounty finding (TBA)",
        "title_url" => "https://immunefi.com/bug-bounty/firedancer/information/",
        "severity" => "",
        "cve_id" => "",
        "summary" => "",
        "tested_version" => "",
        "impact" => "",
        "github_advisories" => [
          { "label" => "", "url" => "" }
        ],
        "timeline" => [
          { "date" => "", "event" => "" }
        ],
        "references" => [
          { "label" => "", "url" => "" }
        ]
      }
    }

    assert_select "article.aboutme-finding-card-static.aboutme-finding-card-bug-bounty"
    assert_select ".aboutme-finding-badges", 0
    assert_select ".aboutme-detail-block", 0
    assert_no_match(/Info/, rendered)
  end
end
