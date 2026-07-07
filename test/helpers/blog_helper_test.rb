require "test_helper"

class BlogHelperTest < ActionView::TestCase
  test "blog cards render reading time" do
    render inline: "<%= render_blog_post_card('example', info) %>", locals: {
      info: {
        "title" => "Example",
        "description" => "A blog post.",
        "category" => "Security Research",
        "categories" => [ "Research" ],
        "published" => "2026-01-01",
        "reading_time_label" => "3 min read"
      }
    }

    assert_select ".blog-post-reading-time", text: "3 min read"
    assert_select ".blog-post-meta-row > button.filter-chip[data-filter-tag='Security Research'] .content-tag-label", text: "Security Research"
    assert_select ".blog-post-meta-row > button.filter-chip[data-filter-tag='Security Research'] .content-tag-arrow", 0
    assert_select ".blog-post-card[data-filter-tags*='Security Research']"
  end

  test "blog cards can render declared difficulty metadata" do
    render inline: "<%= render_blog_post_card('example', info) %>", locals: {
      info: {
        "title" => "Example",
        "description" => "A blog post with optional difficulty metadata.",
        "category" => "Security Research",
        "categories" => [ "Research" ],
        "difficulty" => "Easy",
        "published" => "2026-01-01"
      }
    }

    assert_select ".blog-post-meta-row > button.difficulty-badge.difficulty-badge-easy.difficulty-badge-filter[data-filter-tag='Easy'] .content-tag-label", text: "Easy"
    assert_select ".blog-post-meta-row > button.difficulty-badge[data-filter-tag='Easy'] .content-tag-arrow", 0
    assert_select ".blog-post-card[data-filter-tags*='Security Research']"
    assert_select ".blog-post-card[data-filter-tags*='Easy']"
    assert_select ".blog-post-card[data-filter-tags*='Research']"
  end

  test "blog cards do not duplicate content type categories" do
    render inline: "<%= render_blog_post_card('example', info) %>", locals: {
      info: {
        "title" => "Example",
        "description" => "An algorithms post.",
        "category" => "Algorithm",
        "categories" => [ "Algorithms", "LeetCode" ],
        "published" => "2026-01-01"
      }
    }

    assert_select ".blog-post-meta-row > button.filter-chip[data-filter-tag='Algorithms']", 1
    assert_select ".blog-post-meta-row > button.filter-chip[data-filter-tag='LeetCode']", 1
    assert_select ".blog-post-card[data-filter-tags='Algorithms|LeetCode']"
  end
end
