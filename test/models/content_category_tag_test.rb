require "test_helper"

class ContentCategoryTagTest < ActiveSupport::TestCase
  test "uses privilege escalation as the canonical privilege category label" do
    assert_equal "privesc", ContentCategoryTag.css_key("Privilege Escalation")
    assert ContentCategoryTag.recognized?("Privilege Escalation")

    refute ContentCategoryTag::CATEGORY_KEYS.key?("privesc")
  end

  test "treats web exploitation as the web category" do
    assert_equal "web", ContentCategoryTag.css_key("Web Exploitation")
    assert ContentCategoryTag.recognized?("Web Exploitation")
  end
end
