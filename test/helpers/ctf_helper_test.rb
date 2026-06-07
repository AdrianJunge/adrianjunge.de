require "test_helper"

class CtfHelperTest < ActionView::TestCase
  test "content filter chips render shared severity classes" do
    render inline: "<%= content_filter_chip('High', scope: 'timeline', severity_key: 'High') %>"

    assert_select "button.filter-chip.severity-badge.severity-badge-high.aboutme-severity-high.severity-badge-filter[data-filter-tag='High']", text: "High"
  end

  test "content card tags auto style recognized category and severity labels" do
    render inline: <<~ERB
      <%= content_card_tag('Privilege Escalation', default_scope: 'blogs', default_interactive: true) %>
      <%= content_card_tag('High', default_scope: 'timeline', default_interactive: true) %>
    ERB

    assert_select "button.filter-chip.category-badge.category-badge-privesc.category-badge-filter[data-filter-tag='Privilege Escalation']", text: "Privilege Escalation"
    assert_select "button.filter-chip.severity-badge.severity-badge-high.aboutme-severity-high.severity-badge-filter[data-filter-tag='High']", text: "High"
  end

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
    assert_select ".blog-post-meta-row > button.category-badge.category-badge-web.category-badge-filter[data-filter-tag='Web']", text: "Web"
  end

  test "writeup cards render colorful category badges after difficulty" do
    render inline: "<%= render_writeup_card('Categories', '/ctf/demo/Categories', info) %>", locals: {
      info: {
        "title" => "Categories",
        "description" => "A writeup with multiple categories.",
        "categories" => [ "Pwn", "Crypto" ],
        "difficulty" => "Medium",
        "published" => "2026-01-01"
      }
    }

    assert_select ".blog-post-meta-row > .difficulty-badge:first-child", text: "Medium"
    assert_select ".blog-post-meta-row > button.category-badge.category-badge-pwn.category-badge-filter[data-filter-tag='Pwn']", text: "Pwn"
    assert_select ".blog-post-meta-row > button.category-badge.category-badge-crypto.category-badge-filter[data-filter-tag='Crypto']", text: "Crypto"
    assert_select ".writeup-post-card-logo .category-split-icon[data-category-count='2'][role='img'][aria-label='Pwn and Crypto categories']"
    assert_select ".category-split-icon-slice[data-category='pwn'][style*='--category-index: 0; --category-count: 2; --category-clip: polygon(50% 50%'] .category-split-icon-image[src*='categories/pwn-']"
    assert_select ".category-split-icon-slice[data-category='crypto'][style*='--category-index: 1; --category-count: 2; --category-clip: polygon(50% 50%'] .category-split-icon-image[src*='categories/crypto-']"
    assert_select ".category-split-icon-divider[data-boundary]", 2
  end

  test "writeup cards split category icons into equal thirds for three categories" do
    render inline: "<%= render_writeup_card('Categories', '/ctf/demo/Categories', info) %>", locals: {
      info: {
        "title" => "Categories",
        "description" => "A writeup with three categories.",
        "categories" => [ "Web", "Pwn", "Crypto" ],
        "difficulty" => "Hard",
        "published" => "2026-01-01"
      }
    }

    assert_select ".writeup-post-card-logo .category-split-icon[data-category-count='3'][aria-label='Web, Pwn, and Crypto categories']"
    assert_select ".category-split-icon-slice", 3
    assert_select ".category-split-icon-slice[data-category='web'][style*='--category-index: 0; --category-count: 3; --category-clip: polygon(50% 50%'] .category-split-icon-image[src*='categories/web-']"
    assert_select ".category-split-icon-slice[data-category='pwn'][style*='--category-index: 1; --category-count: 3; --category-clip: polygon(50% 50%'] .category-split-icon-image[src*='categories/pwn-']"
    assert_select ".category-split-icon-slice[data-category='crypto'][style*='--category-index: 2; --category-count: 3; --category-clip: polygon(50% 50%'] .category-split-icon-image[src*='categories/crypto-']"
    assert_select ".category-split-icon-divider", 3
  end

  test "single category writeup cards keep the existing category icon" do
    render inline: "<%= render_writeup_card('Single', '/ctf/demo/Single', info) %>", locals: {
      info: {
        "title" => "Single",
        "description" => "A writeup with one category.",
        "categories" => [ "Web" ],
        "published" => "2026-01-01"
      }
    }

    assert_select ".writeup-post-card-logo .category-split-icon", false
    assert_select ".writeup-post-card-logo img.blog-logo[src*='categories/web-'][alt='Web category']"
  end

  test "writeup cards render optional hint counts without making them filters" do
    render inline: "<%= render_writeup_card('Hints', '/ctf/demo/Hints', info) %>", locals: {
      info: {
        "title" => "Hints",
        "description" => "A writeup with hints.",
        "categories" => [ "Web" ],
        "difficulty" => "Easy",
        "published" => "2026-01-01",
        "optional" => {
          "hints" => [
            "Look at `parse_url` first.",
            "The second redirect matters."
          ]
        }
      }
    }

    assert_select ".blog-post-meta-row > span.writeup-hints-chip", text: /2 hints/
    assert_select ".blog-post-meta-row > button.writeup-hints-chip", false
    assert_select ".blog-post-card[data-filter-tags*='hint']", false
  end

  test "ctf event year stays separate from published year" do
    assert_equal "2025", writeup_ctf_year("ctf_year" => "2025", "published" => "2026-01-01")
    assert_equal 2026, writeup_year("ctf_year" => "2025", "published" => "2026-01-01")
    assert_equal "2024", writeup_ctf_year("year" => "2024", "published" => "2026-01-01")
  end

  test "article hints render as collapsed markdown details" do
    render inline: "<%= render_writeup_hints(info) %>", locals: {
      info: {
        "optional" => {
          "hints" => [
            "Look at `in_array`.",
            "Use the `__toString` gadget."
          ]
        }
      }
    }

    assert_select "details.writeup-hints[open]", false
    assert_select "details.writeup-hints summary", text: /Hints/
    assert_select "details.writeup-hints .writeup-hints-count", text: "2 hints"
    assert_select "details.writeup-hints ul.writeup-hints-list li", 2
    assert_select "details.writeup-hints code", text: "in_array"
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

  test "article category badges render colorful static badges" do
    render inline: "<%= safe_join(render_writeup_category_badges(info, context: :article)) %>", locals: {
      info: {
        "categories" => [ "Web", "Privilege Escalation" ]
      }
    }

    assert_select ".category-badge.category-badge-web.category-badge-article", text: "Web"
    assert_select ".category-badge.category-badge-privesc.category-badge-article", text: "Privilege Escalation"
    assert_select ".category-badge[data-filter-tag]", false
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
