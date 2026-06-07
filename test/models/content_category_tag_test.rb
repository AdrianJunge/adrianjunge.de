require "test_helper"

class ContentCategoryTagTest < ActiveSupport::TestCase
  test "uses privilege escalation as the canonical privilege category label" do
    assert_equal "privesc", ContentCategoryTag.css_key("Privilege Escalation")
    assert ContentCategoryTag.recognized?("Privilege Escalation")

    refute ContentCategoryTag::CATEGORY_KEYS.key?("privesc")
  end
end
