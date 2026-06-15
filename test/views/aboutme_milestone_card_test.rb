require "test_helper"

class AboutmeMilestoneCardTest < ActionView::TestCase
  test "milestone card uses shared linked-card template" do
    render partial: "aboutme/card", locals: {
      kind: "achievement",
      entry: {
        "title" => "Example milestone",
        "summary" => "Placed well in an example event after solving practical web and pwn tasks.",
        "tags" => [
          { "label" => "Competition", "url" => "https://example.com/competition" }
        ],
        "timeline" => [
          {
            "id" => "example-2026",
            "title" => "Example 2026 #1",
            "date" => "2026-01-02",
            "summary" => "Won the example event.",
            "url" => "https://example.com/event"
          }
        ],
        "links" => [
          { "label" => "Reference", "url" => "https://example.com/reference" }
        ]
      }
    }

    assert_select "details.aboutme-finding-card.aboutme-about-card-achievement.aboutme-achievement-card[data-animated-details='true']"
    assert_select ".aboutme-card-link-overlay", 0
    assert_select "summary h3", text: "Example milestone"
    assert_select "summary h3 a", 0
    assert_select "summary .aboutme-finding-main"
    assert_select "summary .aboutme-finding-project + .aboutme-finding-badges a[href=?]",
                  "https://example.com/competition",
                  text: "Competition"
    assert_select ".aboutme-finding-badges time", 0
    assert_select ".aboutme-detail-block h3", text: "Summary"
    assert_select ".aboutme-detail-block h3", text: "References"
    assert_select ".aboutme-card-details .aboutme-reference-link[href=?][target=?][rel=?]", "https://example.com/reference", "_blank", "noopener noreferrer", text: "Reference"
    assert_select ".aboutme-detail-block h3", text: "Timeline"
    assert_select ".aboutme-timeline time[datetime=?]", "2026-01-02"
    assert_select ".aboutme-timeline-title", 0
    assert_select ".aboutme-timeline-link.aboutme-timeline-event-link[href=?][target=?][rel=?][aria-label=?][title=?]",
                  "https://example.com/event",
                  "_blank",
                  "noopener noreferrer",
                  "Open Example 2026 #1",
                  "Open Example 2026 #1",
                  text: "Example 2026 #1"
    assert_select ".aboutme-timeline-event-tag", 0
    assert_select ".aboutme-timeline-summary", text: "Won the example event."
    assert_select ".aboutme-link-row", 0
  end

  test "milestone card omits empty fields and links" do
    render partial: "aboutme/card", locals: {
      kind: "achievement",
      entry: {
        "title" => "Sparse milestone"
      }
    }

    assert_select "article.aboutme-achievement-card"
    assert_select ".aboutme-finding-badges", 0
    assert_select "h3", text: "Sparse milestone"
    assert_select ".aboutme-achievement-details", 0
    assert_select ".aboutme-link-row", 0
  end

  test "milestone card can link compact tags to external references" do
    render partial: "aboutme/card", locals: {
      kind: "talk",
      entry: {
        "title" => "KITCTF Web Intro",
        "url" => "https://kitctf.de/intro/",
        "date" => "2026-05-07",
        "summary" => "Introductory web security talk for KITCTF.",
        "tags" => [
          { "label" => "Slides", "url" => "https://kitctf.de/talks/2026-05-07-web/web-26-ss.pdf" },
          { "label" => "Overview", "url" => "https://kitctf.de/intro/" }
        ]
      }
    }

    assert_select ".aboutme-finding-badges a.aboutme-tag-slides[href=?][target=?][rel=?]",
                  "https://kitctf.de/talks/2026-05-07-web/web-26-ss.pdf",
                  "_blank",
                  "noopener noreferrer",
                  text: "Slides"
    assert_select ".aboutme-finding-badges a.aboutme-tag-overview[href=?][target=?][rel=?]",
                  "https://kitctf.de/intro/",
                  "_blank",
                  "noopener noreferrer",
                  text: "Overview"
    assert_select ".aboutme-card-details .aboutme-reference-link[href=?]", "https://kitctf.de/intro/", 0
    assert_select ".aboutme-card-details .aboutme-reference-link[href=?]", "https://kitctf.de/talks/2026-05-07-web/web-26-ss.pdf", 0
    assert_select ".aboutme-link-row", 0
  end

  test "milestone card shows reading time for linked local posts" do
    render partial: "aboutme/card", locals: {
      kind: "certificate",
      entry: {
        "title" => "HTB CPTS",
        "url" => "/blog/htb-cpts",
        "summary" => "Certification writeup.",
        "tags" => [
          { "label" => "Writeup", "url" => "/blog/htb-cpts" }
        ]
      }
    }

    assert_select ".aboutme-card-reading-time", text: /min read/
  end
end
