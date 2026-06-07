require "test_helper"

class BlogHelperTest < ActionView::TestCase
  test "blog cards render reading time" do
    render inline: "<%= render_blog_post_card('example', info) %>", locals: {
      info: {
        "title" => "Example",
        "description" => "A blog post.",
        "categories" => [ "Research" ],
        "published" => "2026-01-01",
        "reading_time_label" => "3 min read"
      }
    }

    assert_select ".blog-post-reading-time", text: "3 min read"
  end

  test "blog cards can render declared difficulty metadata" do
    render inline: "<%= render_blog_post_card('example', info) %>", locals: {
      info: {
        "title" => "Example",
        "description" => "A blog post with optional difficulty metadata.",
        "categories" => [ "Research" ],
        "difficulty" => "Easy",
        "published" => "2026-01-01"
      }
    }

    assert_select ".blog-post-meta-row > .difficulty-badge.difficulty-badge-easy.difficulty-badge-card", text: "Easy"
    assert_select ".blog-post-card[data-filter-tags*='Easy']"
    assert_select ".blog-post-card[data-filter-tags*='Research']"
  end
end
