require "test_helper"

class MathjaxConfigurationTest < ActionDispatch::IntegrationTest
  test "only math articles publish the dependency configuration" do
    get "/blog/climbing-stairs"
    assert_response :success
    assert_select "[data-math-notice]", count: 1 do |elements|
      notice = elements.first
      assert_equal MathjaxDependencies.component_url, notice["data-mathjax-component-url"]
      assert_equal MathjaxDependencies.font_url, notice["data-mathjax-font-url"]
      assert_equal MathjaxDependencies.font_path, notice["data-mathjax-font-path"]
    end
    assert_select "script[src*='cdn.jsdelivr.net']", count: 0

    get "/blog/java-strings"
    assert_response :success
    assert_select "[data-mathjax-component-url]", count: 0
    assert_select "script[src*='cdn.jsdelivr.net']", count: 0
  end
end
