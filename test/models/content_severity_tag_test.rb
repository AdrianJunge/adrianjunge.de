require "test_helper"

class ContentSeverityTagTest < ActiveSupport::TestCase
  test "normalizes severity labels to shared css keys" do
    assert_equal "critical", ContentSeverityTag.css_key("Critical")
    assert_equal "high", ContentSeverityTag.css_key("High")
    assert_equal "medium", ContentSeverityTag.css_key("Moderate")
    assert_equal "medium", ContentSeverityTag.css_key("Medium")
    assert_equal "low", ContentSeverityTag.css_key("Low")
    assert_equal "info", ContentSeverityTag.css_key("Informational")
    assert_equal "tba", ContentSeverityTag.css_key("TBA")
    assert_nil ContentSeverityTag.css_key("Hard")
  end

  test "builds about severity class names" do
    assert_equal "aboutme-severity-high", ContentSeverityTag.css_class("High")
    assert_equal "severity-badge-medium", ContentSeverityTag.css_class("Moderate", prefix: "severity-badge")
  end
end
