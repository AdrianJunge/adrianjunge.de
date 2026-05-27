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
end
