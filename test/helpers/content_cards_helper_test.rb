require "test_helper"

class ContentCardsHelperTest < ActionView::TestCase
  test "timeline cards retain a first-position CVE even beyond the tag limit" do
    item = {
      kind: "cve", title: "Example finding", link: "/about#example",
      tags: [ "High", "Product", "Web", "Security", "SQL injection", "CWE-89", "CVE-2099-1234" ]
    }

    render inline: "<%= render_content_card(timeline_card_options(item)) %>", locals: { item: item }

    assert_select ".timeline-tags > .content-tag", 6
    assert_select ".timeline-tags > a.cve-badge:first-child[href='https://www.cve.org/CVERecord?id=CVE-2099-1234'] .content-tag-label", text: "CVE-2099-1234"
    assert_select ".timeline-tags [data-filter-tag='severity:high']", 1
    assert_select ".timeline-tags [data-filter-tag='CVE-2099-1234']", 0
    assert_select ".timeline-card-hitbox[aria-label='Open Example finding (CVE-2099-1234)']", 1
  end

  test "timeline fallback icons have contrast while custom artwork keeps its colors" do
    render inline: <<~ERB
      <%= render_content_card(timeline_card_options({ kind: 'timeline_event', title: 'Default', tags: [] })) %>
      <%= render_content_card(timeline_card_options({ kind: 'blog', title: 'Blog', tags: [] })) %>
      <%= render_content_card(timeline_card_options({ kind: 'timeline_event', title: 'Custom', tags: [], logo: 'timeline/picoctf.png' })) %>
    ERB

    assert_select ".timeline-card-logo img.content-hero-icon-inverted[src*='task-bar/timeline']", 1
    assert_select ".timeline-card-logo img.content-hero-icon-inverted[src*='task-bar/blog']", 1
    assert_select ".timeline-card-logo img[alt='Custom icon']:not(.content-hero-icon-inverted)", 1
  end
end
