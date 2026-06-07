require "test_helper"

class CtfHelperTest < ActionView::TestCase
  test "writeup cards support multiple authors with independent urls" do
    render inline: "<%= render_writeup_card('Example', '/ctf/demo/Example', info) %>", locals: {
      info: {
        "title" => "Example",
        "description" => "A writeup with multiple challenge authors.",
        "categories" => [ "Web" ],
        "published" => "2026-01-01",
        "reading_time_label" => "4 min read",
        "authors" => [
          { "name" => "External Author", "url" => "https://example.com" },
          { "name" => "Local Author", "url" => "/about" },
          { "name" => "No Link", "url" => "" }
        ]
      }
    }

    assert_select ".blog-post-authors", text: /Challenge by/
    assert_select ".blog-post-reading-time", text: "4 min read"
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

    assert_select ".blog-post-meta-row > button.writeup-winner-badge:first-child[data-filter-tag=?]", "Writeup winner", text: /Contest win/
    assert_select ".blog-post-meta-row > a.writeup-winner-badge", 0
    assert_select ".writeup-winner-icon", text: "🏆"
    assert_select ".blog-post-card[data-filter-tags*='Writeup winner']"
    assert_select ".blog-post-card[data-filter-tags*='Contest win']", false
  end

  test "non-interactive writeup cards link shiny badges instead of rendering static filter chips" do
    render inline: "<%= render_writeup_card('Winner', '/ctf/demo/Winner', info, interactive_tags: false) %>", locals: {
      info: {
        "title" => "Winner",
        "description" => "A winning authored writeup.",
        "categories" => [ "Web" ],
        "published" => "2026-01-01",
        "writeup_winner" => {
          "label" => "Contest win",
          "proof_url" => "https://example.com/proof"
        },
        "optional" => {
          "authored_challenge" => {
            "event" => "DemoCTF 2026",
            "event_url" => "https://example.com/ctf"
          }
        }
      }
    }

    assert_select ".blog-post-meta-row > a.writeup-winner-badge[href='https://example.com/proof'][target='_blank'][rel='noopener noreferrer']", text: /Contest win/
    assert_select ".blog-post-meta-row > a.authored-challenge-badge[href='https://example.com/ctf'][target='_blank'][rel='noopener noreferrer']", text: /Authored challenge/
    assert_select ".blog-post-meta-row > button.writeup-winner-badge", false
    assert_select ".blog-post-meta-row > button.authored-challenge-badge", false
    assert_select ".blog-post-meta-row > .filter-chip.blog-post-static-chip", text: "Web"
  end

  test "writeup cards render authored challenge badge from optional metadata" do
    render inline: "<%= render_writeup_card('Authored', '/ctf/demo/Authored', info) %>", locals: {
      info: {
        "title" => "Authored",
        "description" => "A challenge I authored.",
        "categories" => [ "Web" ],
        "published" => "2026-01-01",
        "optional" => {
          "authored_challenge" => {
            "event" => "DemoCTF 2026",
            "event_url" => "https://ctftime.org/event/demo"
          }
        }
      }
    }

    assert_select ".blog-post-meta-row > button.authored-challenge-badge:first-child[data-filter-tag=?]", "Authored challenge", text: /Authored challenge/
    assert_select ".blog-post-meta-row > a.authored-challenge-badge", 0
    assert_select ".authored-challenge-icon", text: "✒️"
    assert_select ".blog-post-card[data-filter-tags*='Authored challenge']"
  end

  test "writeup cards render static difficulty badge with filterable difficulty metadata" do
    render inline: "<%= render_writeup_card('Difficulty', '/ctf/demo/Difficulty', info) %>", locals: {
      info: {
        "title" => "Difficulty",
        "description" => "A writeup with a challenge difficulty.",
        "categories" => [ "Web" ],
        "difficulty" => "Hard",
        "published" => "2026-01-01"
      }
    }

    assert_select ".blog-post-meta-row > .difficulty-badge.difficulty-badge-hard.difficulty-badge-card", text: "Hard"
    assert_select ".blog-post-meta-row > .difficulty-badge[data-filter-tag]", false
    assert_select ".blog-post-card[data-filter-text*='Hard']"
    assert_select ".blog-post-card[data-filter-tags*='Hard']"
  end

  test "article difficulty badge falls back when metadata is omitted" do
    render inline: "<%= render_writeup_difficulty_badge(info, context: :article) %>", locals: {
      info: {
        "title" => "Unknown",
        "categories" => [ "Web" ]
      }
    }

    assert_select ".difficulty-badge.difficulty-badge-unknown.difficulty-badge-article", text: "unknown difficulty"
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
