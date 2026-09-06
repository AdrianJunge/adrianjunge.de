require "test_helper"

class ContentConfigurationTest < ActiveSupport::TestCase
  test "services can resolve a separate content checkout without controller constants" do
    config = ContentConfiguration.new(root: "/tmp/example-content-checkout")
    assert_equal Pathname("/tmp/example-content-checkout/app/assets/blog/posts"), config.path(:BLOG_BASE_PATH)
    assert_equal config.path(:ABOUTME_CVES_PATH), config.resolve(ContentConfiguration::ABOUTME_CVES_PATH)
    assert_equal ContentConfiguration::ABOUTME_CVES_PATH, config.schema_path(config.path(:ABOUTME_CVES_PATH))
    assert_equal Pathname("/tmp/custom.json"), config.resolve("/tmp/custom.json")
  end
end
