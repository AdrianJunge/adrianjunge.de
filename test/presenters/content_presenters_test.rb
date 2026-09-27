require "test_helper"

class ContentPresentersTest < ActiveSupport::TestCase
  test "normalized blog cards retain the same metadata across index and landing variants" do
    post = fixture_content_repository.blog_post("alpha-post")
    index = BlogCardPresenter.new(post: post, url: post[:link])
    landing = BlogCardPresenter.new(post: post, url: post[:link], interactive_tags: false, section_url: "/blog")

    %i[title description date reading_time tags data media].each do |key|
      assert_equal index[key], landing[key], "Different #{key} for the same post"
    end
    assert_equal post[:title], index[:title]
    assert_equal post[:logo], index[:media][:image]
    assert_equal post[:link], index[:url]
    assert index[:interactive_tags]
    assert_not landing[:interactive_tags]
    assert_equal "/blog", landing[:section_link][:url]
  end

  test "card variants reject layout overrides and unknown variants" do
    assert_raises(ArgumentError) { ContentCardPresenter.new(variant: :post, root_tag: :a) }
    assert_raises(KeyError) { ContentCardPresenter.new(variant: :unknown) }
  end

  test "cards omit blank metadata and incomplete section links" do
    card = ContentCardPresenter.new(
      variant: :post, title: "An entry", url: "", tags: [ nil, "Web" ],
      meta_items: [ nil, "", { label: nil }, { "label" => "5 solves", "class_name" => "solves" } ],
      section_link: { url: "/blog" }
    )

    assert_nil card[:url]
    assert_nil card[:section_link]
    assert_equal [ "Web" ], card[:tags]
    assert_equal [ { label: "5 solves", class_name: "blog-post-reading-time solves" } ], card[:meta_items]
    assert_not_includes card[:root_attributes][:class], "ui-hover-lift"
    assert_not_includes card[:root_attributes][:class], "content-card-with-section-link"
  end

  test "CTF event cards preserve filtering and distinguish recognition from categories" do
    tags = [ "Web", "difficulty:easy", WriteupWinner::FILTER_LABEL, AuthoredChallenge::FILTER_LABEL ]
    card = CtfEventCardPresenter.new(
      name: "Example CTF", event: { "writeups" => "/ctf/example", "directory" => "example", "description" => "An event" },
      filters: { writeup_count: 1, tags: tags, years: [ 2026, 2025 ] }, reading_time: "3 min read"
    )

    assert_equal "1 writeup", card[:date]
    assert_equal "/ctf/example", card[:url]
    assert_equal "2026|2025", card[:data][:filter_years]
    assert_equal tags.join("|"), card[:data][:filter_tags]
    assert card[:tags].first[:category]
    assert card[:tags][1][:difficulty_filter]
    assert card[:tags][2][:winner]
    assert card[:tags][3][:authored]
    assert card[:tags].drop(1).none? { |tag| tag[:category] }
  end

  test "filter presentation selects common content types and retains every remaining tag" do
    groups = [
      { "label" => "Topics", "tags" => [ "Web", "web", "Security" ] },
      { label: "Content type", tags: [ "Talk", "Blog post", "Algorithms", "CTF writeup" ] },
      { label: "Empty", tags: [] }
    ]
    original = groups.deep_dup
    filters = ContentFiltersPresenter.new(scope: "timeline", years: [ 2025, nil, "", 2026, "2025" ], tag_groups: groups)

    assert_equal [ "2026", "2025" ], filters.years
    assert_equal [ "Blog post", "CTF writeup", "Talk" ], filters.common_group[:tags]
    assert_equal [ "Algorithms" ], filters.additional_groups.first[:tags]
    assert_equal [ "Web", "Security" ], filters.additional_groups.last[:tags]
    assert_equal original, groups
    assert_equal "timeline-search-input", filters.search_id
  end

  test "empty filter groups fall back to tags and empty filters stay usable" do
    filters = ContentFiltersPresenter.new(scope: "blogs", tags: [ "Ruby", nil, "ruby", "" ], tag_groups: [ nil, {} ])
    assert_equal [ "Ruby" ], filters.common_group[:tags]
    assert_empty filters.additional_groups

    empty = ContentFiltersPresenter.new(scope: "blogs")
    assert_nil empty.common_group
    assert_empty empty.additional_groups
    assert_equal 0, empty.total
  end

  test "finding cards never overlay disclosure controls with a card link" do
    data = { title: "Research", card_url: "/blog/research", collapsible: true, body_blocks: [ { text: "Details" } ] }
    card = ProfileCardPresenter.new(data)

    assert card[:collapsible]
    assert_nil card[:card_url]
    assert_not_includes card[:class_name], "aboutme-card-linked"
    assert_equal "/blog/research", data[:card_url]

    empty = ProfileCardPresenter.new(data.merge(body_blocks: []))
    assert_not empty[:collapsible]
    assert_equal "/blog/research", empty[:card_url]
    assert_includes empty[:class_name], "aboutme-card-linked"
  end

  test "finding tags keep metadata before links without mutating their source" do
    tags = [ { label: "Slides", url: "https://example.org" }, { label: "Ruby" } ]
    card = ProfileCardPresenter.new(tags: tags, nested: true)

    assert_equal [ "Ruby", "Slides" ], card[:tags].map { |tag| tag[:label] }
    assert_equal [ "Slides", "Ruby" ], tags.map { |tag| tag[:label] }
    assert_equal :h4, card[:heading_tag]
  end

  test "all profile icon consumers use the same registry defaults" do
    assert_equal "other/cve.svg", ContentIconRegistry.for(:cve)
    assert_equal "ctf/kitctf.png", ContentIconRegistry.for("challenge")
    assert_equal "other/talk-slides.png", ContentIconRegistry.for("unknown", title: "Intro to Ruby")
    assert_equal "other/certificate.svg", ContentIconRegistry.for("unknown", title: "CPTS certificate")
    assert_equal "other/achievement.svg", ContentIconRegistry.for("unknown")
  end
end
