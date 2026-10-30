require "test_helper"

class ProfileCardsHelperTest < ActionView::TestCase
  test "profile and content cards share record badge markup and accessible actions" do
    render inline: <<~ERB
      <div id="profile"><%= profile_card_tag(label: 'CWE-89', url: 'https://example.org/old') %></div>
      <div id="content"><%= content_card_tag('CWE-89', default_scope: 'timeline', default_interactive: true) %></div>
    ERB

    profile_tag = css_select("#profile a.content-tag").sole
    content_tag = css_select("#content a.content-tag").sole
    assert_equal content_tag.inner_html, profile_tag.inner_html
    assert_equal "https://cwe.mitre.org/data/definitions/89.html", profile_tag["href"]
    assert_equal content_tag["aria-label"], profile_tag["aria-label"]
    assert_select "#profile .content-tag-label", text: "CWE-89"
    assert_select "#profile .content-tag-chevron[aria-hidden='true']", 1
  end

  test "profile filter labels preserve custom text and typed severity" do
    render inline: "<%= profile_card_tag(label: 'Security severity', filter_tag: 'severity:high') %>"

    assert_select "a.content-tag.severity-badge-high[href='/timeline?tag=severity%3Ahigh'][aria-label='Security severity: Filter timeline by High'] .content-tag-label", text: "Security severity"
    assert_select ".content-tag-chevron", 0
  end

  test "profile date badges stay semantic and do not become timeline filters" do
    render inline: "<%= profile_card_tag(label: '2 Oct 2023', datetime: '2023-10-02') %>"

    assert_select "time.content-tag.content-tag-static[datetime='2023-10-02'] .content-tag-label", text: "2 Oct 2023"
    assert_select "a, button", 0
  end

  test "profile CVE tags always use their canonical record even without an explicit URL" do
    render inline: <<~ERB
      <%= profile_card_tag(label: 'cve-2099-1234') %>
      <%= profile_card_tag(label: 'CVE-2099-5678', url: 'https://example.org/old-record') %>
    ERB

    %w[CVE-2099-1234 CVE-2099-5678].each do |identifier|
      assert_select "a.aboutme-cve-id[href=?][target='_blank'][rel='noopener noreferrer']", "https://www.cve.org/CVERecord?id=#{identifier}", text: identifier
    end
    assert_select ".aboutme-tag-timeline", 0
  end

  test "profile references retain native same-page and email navigation" do
    [ "#certificates", "/about#certificates", "mailto:todo@example.com" ].each do |url|
      render inline: "<%= profile_card_optional_link('Reference', url) %>", locals: { url: url }

      assert_select "a[href=?]", url
      assert_select "a[target]", 0
    end
  end

  test "external profile references retain their safe new-tab behavior" do
    render inline: "<%= profile_card_optional_link('Reference', 'https://example.com/reference') %>"

    assert_select "a[target='_blank'][rel='noopener noreferrer']", 1
  end
end
