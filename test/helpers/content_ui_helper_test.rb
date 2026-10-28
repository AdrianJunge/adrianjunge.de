require "test_helper"

class ContentUiHelperTest < ActionView::TestCase
  test "recognition filter names include the visible award while preserving their filter value" do
    render inline: <<~ERB
      <%= content_filter_chip('Best web writeup 2025', scope: 'timeline', tag_value: 'Writeup winner', winner: true) %>
      <%= content_filter_chip('Best challenge writeup', scope: nil, tag_value: 'Writeup winner', winner: true) %>
    ERB

    assert_select "button[data-filter-scope='timeline'][data-filter-tag='Writeup winner'][aria-label='Best web writeup 2025: Filter by Writeup winner']",
                  text: "Best web writeup 2025"
    assert_select "a[href='/timeline?tag=Writeup+winner'][aria-label='Best challenge writeup: Filter timeline by Writeup winner']",
                  text: "Best challenge writeup"
  end

  test "difficulty and severity names use readable labels instead of internal filter keys" do
    render inline: <<~ERB
      <%= content_filter_chip('High', scope: 'timeline', severity_key: 'High') %>
      <%= content_filter_chip('Hard', scope: nil, difficulty_key: 'Hard') %>
    ERB

    assert_select "button[data-filter-tag='severity:high'][aria-label='Filter by High']", text: "High"
    assert_select "a[href='/timeline?tag=difficulty%3Ahard'][aria-label='Filter timeline by Hard']", text: "Hard"
  end

  test "proof and event badge names retain their visible labels and action descriptions" do
    render inline: <<~ERB
      <%= content_winner_badge(label: 'Best web writeup 2025', url: '/proof.pdf') %>
      <%= content_authored_badge(label: 'Authored challenge', url: 'https://example.com/ctf', aria_label: 'Open DemoCTF 2026') %>
      <%= content_card_tag({ label: 'CTF writing award', url: '/card-proof.pdf', winner: true }, default_scope: nil, default_interactive: false) %>
    ERB

    assert_select "a[href='/proof.pdf'][aria-label='Best web writeup 2025: Open contest win proof'] .content-tag-label",
                  text: "Best web writeup 2025"
    assert_select "a[href='https://example.com/ctf'][aria-label='Authored challenge: Open DemoCTF 2026'] .content-tag-label",
                  text: "Authored challenge"
    assert_select "a[href='/card-proof.pdf'][aria-label='CTF writing award: Open contest win proof'] .content-tag-label",
                  text: "CTF writing award"
  end

  test "custom badge names include the visible label only once" do
    render inline: <<~ERB
      <%= content_tag_badge('Web', classes: [], filter_scope: 'timeline', aria_label: 'Show matching entries') %>
      <%= content_tag_badge('Best writeup', classes: [], url: '/proof.pdf', aria_label: 'Open Best writeup proof') %>
    ERB

    assert_select "button[data-filter-tag='Web'][aria-label='Web: Show matching entries']", text: "Web"
    assert_select "a[href='/proof.pdf'][aria-label='Open Best writeup proof'] .content-tag-label", text: "Best writeup"
  end
end
