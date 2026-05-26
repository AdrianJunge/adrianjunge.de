require "test_helper"

class AboutmeMilestoneCardTest < ActionView::TestCase
  test "milestone card links title and renders references" do
    render partial: "aboutme/milestone_card", locals: {
      entry: {
        "title" => "Example milestone",
        "title_url" => "https://example.com/milestone",
        "category" => "Competition",
        "date" => "2026",
        "summary" => "Placed well in an example event.",
        "details" => [
          "Solved practical web and pwn tasks."
        ],
        "links" => [
          { "label" => "Reference", "url" => "https://example.com/reference" }
        ]
      }
    }

    assert_select "article.aboutme-achievement-card"
    assert_select "h3 a[href=?][target=?][rel=?]", "https://example.com/milestone", "_blank", "noopener noreferrer", text: "Example milestone"
    assert_select ".aboutme-achievement-meta time[datetime=?]", "2026"
    assert_select ".aboutme-link-row a[href=?]", "https://example.com/reference"
  end

  test "milestone card omits empty fields and links" do
    render partial: "aboutme/milestone_card", locals: {
      entry: {
        "title" => "Sparse milestone",
        "title_url" => "",
        "category" => "",
        "date" => "",
        "summary" => "",
        "details" => [ "" ],
        "links" => [
          { "label" => "", "url" => "" }
        ]
      }
    }

    assert_select "article.aboutme-achievement-card"
    assert_select ".aboutme-achievement-meta", 0
    assert_select "h3", text: "Sparse milestone"
    assert_select ".aboutme-achievement-details", 0
    assert_select ".aboutme-link-row", 0
  end
end
