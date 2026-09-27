require "test_helper"

class ResourceBrowserCompatibilityTest < ActionDispatch::IntegrationTest
  OLD_SAFARI = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15".freeze

  test "an older recognized browser can fetch every feed format and the sitemap" do
    {
      "/feed" => "application/rss+xml",
      "/feed.xml" => "application/xml",
      "/feed.atom" => "application/atom+xml",
      "/feed.json" => "application/feed+json",
      "/sitemap.xml" => "application/xml"
    }.each do |path, type|
      get path, headers: { "User-Agent" => OLD_SAFARI }
      assert_response :success, "expected #{path} to remain browser independent"
      assert_equal type, response.media_type
      etag = response.headers.fetch("ETag")
      get path, headers: { "User-Agent" => OLD_SAFARI, "If-None-Match" => etag }
      assert_response :not_modified
    end
  end

  test "an older browser can fetch catalogued CTF resources" do
    repository = fixture_content_repository
    post = repository.ctf_post("democtf", "Space Writeup")
    with_stubbed_content_repository(repository) do
      %i[challenge writeup].each do |kind|
        asset = repository.ctf_asset_for(post, kind)
        get ctf_file_download_path(asset[:id]), headers: { "User-Agent" => OLD_SAFARI }
        assert_response :success
        assert_equal File.binread(asset[:path]), response.body
        assert_equal "nosniff", response.headers["X-Content-Type-Options"]
      end
    end
  end

  test "HTML retains the modern browser policy independently of resources" do
    get root_path, headers: { "User-Agent" => OLD_SAFARI }
    assert_response :not_acceptable

    get blog_path
    assert_response :success
  end
end
