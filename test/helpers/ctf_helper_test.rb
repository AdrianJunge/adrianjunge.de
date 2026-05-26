require "test_helper"

class CtfHelperTest < ActionView::TestCase
  test "writeup cards support multiple authors with independent urls" do
    render inline: "<%= render_writeup_card('Example', '/ctf/demo/Example', info) %>", locals: {
      info: {
        "title" => "Example",
        "description" => "A writeup with multiple challenge authors.",
        "categories" => [ "Web" ],
        "published" => "2026-01-01",
        "authors" => [
          { "name" => "External Author", "url" => "https://example.com" },
          { "name" => "Local Author", "url" => "/about" },
          { "name" => "No Link", "url" => "" }
        ]
      }
    }

    assert_select ".blog-post-authors", text: /Challenge by/
    assert_select ".blog-post-author-link[href=?][target=?][rel=?]", "https://example.com", "_blank", "noopener noreferrer", text: "External Author"
    assert_select ".blog-post-author-link[href=?]", "/about", text: "Local Author"
    assert_select ".blog-post-author-name", text: "No Link"
  end
end
