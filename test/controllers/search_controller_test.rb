require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "renders global search across posts and about content" do
    get search_path

    assert_response :success
    assert_select "main.search-page"
    assert_select ".search-result-card", minimum: 30
    assert_select ".search-result-card", text: /xmalloc/
    assert_select ".search-result-card", text: /Hack The Box Certified Penetration Testing Specialist/
    assert_select ".search-result-card", text: /CVE-2026-/
    assert_select ".content-filter-panel[data-filter-scope=?]", "global-search"
    assert_select "h1", text: "Global Search"
    assert_select ".taskbar-link[href=?]", search_path, text: /Global Search/
  end

  test "keeps query parameter as initial client side search value" do
    get search_path(q: "joomla")

    assert_response :success
    assert_select "input#global-search-input[value=?]", "joomla"
  end
end
