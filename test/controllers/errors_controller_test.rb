require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "renders a custom not found page for unknown routes" do
    [ "/definitely-not-a-real-route", "/search/does-not-exist" ].each do |path|
      get path

      assert_response :not_found
      assert_select "main.error-page"
      assert_select "h1", text: /404 Page not found/
      assert_select "main.error-page img.content-hero-icon[src*='task-bar/error']"
      assert_select "#terminal-container", 0
      assert_select ".taskbar-link[href=?]", "/"
      assert_select "a[href=?]", "/timeline"
    end
  end

  test "withdrawn content destinations are absent from navigation and return not found" do
    retired = [ "/start", "/research", "/talks", "/contact", "/reading-paths", "/search" ]
    get "/blog"
    assert_response :success
    retired.each { |path| assert_select "a[href=?]", path, count: 0 }
    (retired + [ "/research/joomla-com-tags-authenticated-blind-sqli", "/reading-paths/algorithms-two-angles" ]).each do |path|
      get path
      assert_response :not_found
      assert_select "main.error-page"
    end
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
    repository = fixture_content_repository
    event = repository.ctf_event("democtf")
    paths = [
      "/blog/definitely-not-a-post",
      "/ctf/definitely-not-a-ctf",
      "/ctf/#{ERB::Util.url_encode(event[:slug])}/definitely-not-a-writeup"
    ]

    with_stubbed_content_repository(repository) do
      paths.each do |path|
        get path

        assert_response :not_found
        assert_select "main.error-page"
        assert_select "h1", text: /404 Page not found/
        assert_select "p", text: /urban legend/
        assert_select "#terminal-container", 0
        assert_no_match "Blog post not found", response.body
        assert_no_match "Invalid path", response.body
        assert_no_match "Invalid post", response.body
      end
    end
  end

  test "renders custom html error page for missing asset-like paths" do
    get "/asdf.png"

    assert_response :not_found
    assert_equal "text/html", response.media_type
    assert_select "main.error-page"
    assert_select "h1", text: /404 Page not found/
    assert_no_match "Missing template", response.body
  end

  test "missing article offers real related titles and one public article detour without echoing input" do
    repository = fixture_content_repository
    with_stubbed_content_repository(repository) do
      get "/blog/alhpa-research", params: { private_note: "unpublished-request-value" }

      assert_response :not_found
      assert_select "meta[name=robots][content='noindex, nofollow']"
      assert_select ".error-detour-list a[href='/blog/alpha-post']", text: "Alpha Research"
      assert_select "[data-random-article]", 1
      assert_includes (repository.blog_posts + repository.ctf_posts).pluck(:link), css_select("[data-random-article]").first["href"]
      assert_no_match "alhpa-research", response.body
      assert_no_match "unpublished-request-value", response.body
      assert_select ".error-panel p", text: /urban legend/
    end
  end

  test "direct 404 has no unrelated article suggestions" do
    get "/404"

    assert_response :not_found
    assert_select ".error-detour-list", 0
    assert_select "[data-random-article]", 1
  end

  test "random detour describes the selected article type even when only one collection has content" do
    content = fixture_content_repository
    [
      [ [ content.blog_posts.first ], [], "A random post, freshly picked for this wrong turn." ],
      [ [], [ content.ctf_posts.first ], "A random CTF writeup, freshly picked for this wrong turn." ]
    ].each do |blogs, writeups, description|
      repository = Struct.new(:blog_posts, :ctf_posts).new(blogs, writeups)
      post = (blogs + writeups).first
      with_stubbed_content_repository(repository) do
        get "/404"

        assert_response :not_found
        assert_select ".error-random-detour p", text: description
        assert_select "a[data-random-article][href=?]", post[:link], text: post[:metadata]["title"]
      end
    end
  end

  test "article titles in recovery links remain plain escaped text" do
    repository = fixture_content_repository
    repository.blog_posts.first[:metadata]["title"] = "Alpha <em>Research</em> & Notes"
    with_stubbed_content_repository(repository) do
      get "/missing-alpha"

      assert_response :not_found
      assert_select ".error-detour-list a", text: "Alpha <em>Research</em> & Notes"
      assert_select ".error-detour-list em", 0
    end
  end

  test "optional detours failing does not break the original 404 page" do
    repository = Object.new
    repository.define_singleton_method(:blog_posts) { raise ContentRepository::InvalidContent, "unavailable-content-detail" }
    with_stubbed_content_repository(repository) do
      get "/unknown-destination"

      assert_response :not_found
      assert_select "h1", text: /404 Page not found/
      assert_select ".error-detours", 0
      assert_select ".error-actions a[href='/']", text: "Home"
      assert_no_match "unavailable-content-detail", response.body
    end
  end

  test "other error statuses do not load optional article collections" do
    repository = Object.new
    calls = []
    repository.define_singleton_method(:blog_posts) { calls << :blog_posts; raise "Unexpected content access" }
    repository.define_singleton_method(:ctf_posts) { calls << :ctf_posts; raise "Unexpected content access" }
    with_stubbed_content_repository(repository) do
      { "/400" => :bad_request, "/422" => :unprocessable_content, "/500" => :internal_server_error }.each do |path, status|
        get path
        assert_response status
        assert_select ".error-detours", 0
      end
    end
    assert_empty calls
  end
end
