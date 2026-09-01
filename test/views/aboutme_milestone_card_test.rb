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

  test "milestone card derives upcoming event labels and highlighting from dates" do
    travel_to Time.zone.local(2026, 9, 1, 12) do
      render partial: "aboutme/card", locals: {
        kind: "talk",
        entry: {
          "title" => "Example talks",
          "timeline" => [
            { "date" => "2026-08-31", "title" => "Past talk." },
            { "date" => "2026-11-09", "title" => "Talk at the future event." }
          ]
        }
      }
    end

    assert_select ".aboutme-timeline li[data-upcoming='false']", 1 do
      assert_select ".content-upcoming-badge", 0
      assert_select "time[datetime='2026-08-31']", text: "2026-08-31"
    end
    assert_select ".aboutme-timeline li.aboutme-timeline-item-upcoming[data-upcoming='true']", 1 do
      assert_select ".aboutme-timeline-date-row > .content-upcoming-badge.aboutme-upcoming-badge", text: "Upcoming"
      assert_select "time[datetime='2026-11-09']", text: "2026-11-09"
      assert_select ".aboutme-timeline-title", text: "Talk at the future event."
    end
    assert_no_match(/Upcoming:/, rendered)
  end

  test "milestone card can link compact tags to external references" do
    render partial: "aboutme/card", locals: {
      kind: "talk",
      entry: {
        "title" => "Fixture Web Intro",
        "url" => "https://fixture.invalid/intro/",
        "date" => "2099-05-07",
        "summary" => "Synthetic introductory web security talk.",
        "tags" => [
          { "label" => "Slides", "url" => "https://fixture.invalid/slides.pdf" },
          { "label" => "Overview", "url" => "https://fixture.invalid/intro/" }
        ]
      }
    }

    assert_select ".aboutme-finding-badges a.aboutme-tag-slides[href=?][target=?][rel=?]",
                  "https://fixture.invalid/slides.pdf",
                  "_blank",
                  "noopener noreferrer",
                  text: "Slides"
    assert_select ".aboutme-finding-badges a.aboutme-tag-overview[href=?][target=?][rel=?]",
                  "https://fixture.invalid/intro/",
                  "_blank",
                  "noopener noreferrer",
                  text: "Overview"
    assert_select ".aboutme-card-details .aboutme-reference-link[href=?]", "https://fixture.invalid/intro/", 0
    assert_select ".aboutme-card-details .aboutme-reference-link[href=?]", "https://fixture.invalid/slides.pdf", 0
    assert_select ".aboutme-link-row", 0
  end

  test "milestone card shows reading time for linked local posts" do
    @aboutme_post_reading_times = { "/blog/example-post" => "3 min read" }

    render partial: "aboutme/card", locals: {
      kind: "certificate",
      entry: {
        "title" => "Example certificate",
        "url" => "/blog/example-post",
        "summary" => "Certification writeup.",
        "tags" => [
          { "label" => "Post", "url" => "/blog/example-post" }
        ]
      }
    }

    assert_select ".aboutme-card-reading-time", text: "3 min read"
  end
end
