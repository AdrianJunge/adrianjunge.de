require "test_helper"

class ProfileCardsHelperTest < ActionView::TestCase
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
