require "test_helper"

class ContentImageHelperTest < ActionView::TestCase
  include ContentImageHelper

  test "card variants resolve with dimensions and deliberate eager loading overrides" do
    image = Nokogiri::HTML.fragment(content_image_tag("ctf/lactf.png", alt: "LACTF", loading: "eager", sizes: "128px")).at_css("img")
    assert_equal "LACTF", image["alt"]
    assert_equal "eager", image["loading"]
    assert_equal "async", image["decoding"]
    assert_equal "128px", image["sizes"]
    assert_equal "384", image["width"]
    assert_equal "384", image["height"]
    assert_equal 3, image["srcset"].split(",").length
    assert_match %r{/variants/ctf/lactf-384(?:-[a-f0-9]+)?\.webp\z}, image["src"]
  end

  test "profile uses its real format and screenshots preserve native resolution" do
    profile = ContentImageHelper.image_attributes("landing/profile.webp")
    assert_equal 128, profile[:width]
    assert_equal 128, profile[:height]
    screenshot = ContentImageHelper.image_attributes("blog/posts/java-strings/java-string-pool.png")
    original = ContentImageHelper.manifest.fetch("blog/posts/java-strings/java-string-pool.png")
    assert_equal original.fetch("width"), screenshot[:width]
    assert_nil screenshot[:srcset]
  end

  test "remote images remain untouched and do not gain invented dimensions" do
    assert_equal({ src: "https://example.com/image.png" }, ContentImageHelper.image_attributes("https://example.com/image.png"))
  end

  test "every descriptor and variant names an existing public image" do
    ContentImageHelper.manifest.each do |logical, descriptor|
      assert Rails.root.join("app/assets/images", logical).file?, logical
      assert Rails.root.join("app/assets/images", descriptor.fetch("src")).file?, descriptor.inspect
      Array(descriptor["variants"]).each do |variant|
        assert Rails.root.join("app/assets/images", variant.fetch("path")).file?, variant.inspect
      end
    end
    assert_equal 1200, ContentImageHelper.image_attributes("landing/social-card.png")[:width]
    assert_equal 630, ContentImageHelper.image_attributes("landing/social-card.png")[:height]
  end
end
