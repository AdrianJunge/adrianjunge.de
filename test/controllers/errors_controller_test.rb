require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "renders a custom not found page for unknown routes" do
    get "/definitely-not-a-real-route"

    assert_response :not_found
    assert_select "main.error-page"
    assert_select "h1", text: /404 Page not found/
    assert_select "main.error-page img.content-hero-icon[src*='task-bar/error']"
    assert_select "#terminal-container"
    assert_select ".taskbar-link[href=?]", "/"
    assert_select "a[href=?]", "/posts-timeline"
  end

  test "renders custom static status routes" do
    {
      "/400" => [ :bad_request, "400 Bad request" ],
      "/422" => [ :unprocessable_content, "422 Unprocessable request" ],
      "/500" => [ :internal_server_error, "500 Internal server error" ]
    }.each do |path, (status, heading)|
      get path

      assert_response status
      assert_select "main.error-page"
      assert_select "h1", text: /#{Regexp.escape(heading)}/
    end
  end

  test "renders custom not found page for invalid blog and ctf subpaths" do
    [
      "/blog/definitely-not-a-post",
      "/ctf/definitely-not-a-ctf",
      "/ctf/cscg/definitely-not-a-writeup"
    ].each do |path|
      get path

      assert_response :not_found
      assert_select "main.error-page"
      assert_select "h1", text: /404 Page not found/
      assert_select "p", text: /urban legend/
      assert_select "#terminal-container"
      assert_no_match "Blog post not found", response.body
      assert_no_match "Invalid path", response.body
      assert_no_match "Invalid post", response.body
    end
  end
end
