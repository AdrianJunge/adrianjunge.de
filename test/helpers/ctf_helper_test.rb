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

  test "writeup cards render contest win badge from metadata" do
    render inline: "<%= render_writeup_card('Winner', '/ctf/demo/Winner', info) %>", locals: {
      info: {
        "title" => "Winner",
        "description" => "A winning writeup.",
        "categories" => [ "Web" ],
        "published" => "2026-01-01",
        "writeup_winner" => {
          "label" => "Contest win",
          "proof_url" => "/ctf/certifications/example.pdf"
        }
      }
    }

    assert_select ".blog-post-meta-row > .writeup-winner-badge:first-child[href=?][target=?][rel=?]", "/ctf/certifications/example.pdf", "_blank", "noopener", text: "Contest win"
    assert_select ".blog-post-card[data-filter-tags*='Writeup winner']"
    assert_select ".blog-post-card[data-filter-tags*='Contest win']", false
  end

  test "writeup cards can render ctf organizer logos" do
    render inline: "<%= render_writeup_card('Logo', '/ctf/demo/Logo', info, logo: 'ctf/cscg.png') %>", locals: {
      info: {
        "title" => "Logo",
        "description" => "A writeup with a CTF logo.",
        "categories" => [ "Web" ],
        "published" => "2026-01-01"
      }
    }

    assert_select ".writeup-post-card-logo img.blog-logo[alt='Logo Logo']"
    assert_select ".writeup-post-card-logo svg", false
  end

  test "category icons are selected by basename and alphabetic filename" do
    png_path = CtfHelper::CATEGORY_ICON_DIRECTORY.join("temporary-category-icon.png")
    svg_path = CtfHelper::CATEGORY_ICON_DIRECTORY.join("temporary-category-icon.svg")
    File.binwrite(png_path, "placeholder")
    File.write(svg_path, "<svg></svg>")

    html = get_category_svg("Temporary-Category-Icon")

    assert_includes html, "categories/temporary-category-icon.png"
    assert_no_match(/<svg/, html)
  ensure
    FileUtils.rm_f([ png_path, svg_path ])
  end
end
