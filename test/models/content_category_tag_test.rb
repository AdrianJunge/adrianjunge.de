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

  test "category aliases share canonical labels and retain their established CSS keys" do
    { "Reverse" => %w[rev reverse reversing], "Blockchain" => %w[web3 blockchain] }.each do |label, aliases|
      aliases.each do |value|
        assert_equal label, ContentCategoryTag.canonical_label(value)
        assert_equal ContentCategoryTag.css_key(label), ContentCategoryTag.css_key(value)
      end
    end
    assert_nil ContentCategoryTag.canonical_label("unlisted topic")
  end
end
