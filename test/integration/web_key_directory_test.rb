require "test_helper"

class WebKeyDirectoryTest < ActionDispatch::IntegrationTest
  BASES = %w[/.well-known/openpgpkey /.well-known/openpgpkey/adrianjunge.de].freeze
  KEY_HASH = "53a3k6s45xb3w5niiaq14mjsf1xeuoz3".freeze
  OLD_SAFARI = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15".freeze

  test "WKD returns the exact binary certificate with public cross origin access" do
    each_layout do |_base, key_path|
      get "#{key_path}?l=stdin", headers: { "Origin" => "https://www.webkeydirectory.com", "User-Agent" => OLD_SAFARI }
      assert_response :success
      assert_equal "application/octet-stream", response.media_type
      assert_equal File.binread(Rails.root.join("public", key_path.delete_prefix("/"))), response.body.b
      assert_includes response.body, "stdin@adrianjunge.de"
      assert_not_includes response.body, "adjun37@gmail.com"
      assert_not_includes response.body, "-----BEGIN PGP"
      assert_public_headers
      assert_equal response.body.bytesize, response.headers.fetch("Content-Length").to_i
    end
  end

  test "HEAD and a queryless key lookup work without HTML browser restrictions" do
    each_layout do |_base, key_path|
      get key_path
      assert_response :success
      expected_modified = response.headers.fetch("Last-Modified")

      head "#{key_path}?l=STDIN", headers: { "User-Agent" => "curl/8.0" }
      assert_response :success
      assert_empty response.body
      assert_equal "application/octet-stream", response.media_type
      assert_equal expected_modified, response.headers.fetch("Last-Modified")
      assert_public_headers
    end
  end

  test "the required empty policy supports GET and HEAD with CORS" do
    each_layout do |base, _key_path|
      [ :get, :head ].each do |method|
        public_send(method, "#{base}/policy")
        assert_response :success
        assert_empty response.body
        assert_equal "text/plain", response.media_type
        assert_equal "0", response.headers["Content-Length"]
        assert_public_headers
      end
    end
  end

  test "key responses can be revalidated without losing their protocol headers" do
    each_layout do |_base, key_path|
      get key_path
      modified = response.headers.fetch("Last-Modified")
      get key_path, headers: { "If-Modified-Since" => modified }
      assert_response :not_modified
      assert_empty response.body
      assert_public_headers
    end
  end

  test "unpublished keys and directories return 404 instead of listings or fallback keys" do
    each_layout do |base, key_path|
      [ base, "#{base}/", "#{base}/hu", "#{base}/hu/", "#{base}/hu/#{'0' * 32}?l=asdf", "#{key_path}.asc" ].each do |path|
        [ :get, :head ].each do |method|
          public_send(method, path)
          assert_response :not_found, "#{method.upcase} #{path}"
          assert_equal "*", response.headers["Access-Control-Allow-Origin"]
          assert_not_includes response.body, "stdin@adrianjunge.de"
        end
      end
    end
  end

  test "publishing WKD keeps the armored download with its correct MIME type" do
    get SiteProfile.pgp_path
    assert_response :success
    assert_equal "application/pgp-keys", response.media_type
    assert_equal File.binread(Rails.root.join("public", SiteProfile.pgp_path.delete_prefix("/"))), response.body.b
    assert response.body.start_with?("-----BEGIN PGP PUBLIC KEY BLOCK-----")
    assert_public_headers

    head SiteProfile.pgp_path
    assert_response :success
    assert_empty response.body
    assert_equal "application/pgp-keys", response.media_type
  end

  test "the static key service refuses write methods" do
    each_layout do |_base, key_path|
      post key_path
      assert_response :method_not_allowed
      assert_includes response.headers.fetch("Allow"), "GET"
      assert_includes response.headers.fetch("Allow"), "HEAD"
    end
  end

  test "advanced WKD does not publish this key under another email domain" do
    host! "openpgpkey.adrianjunge.de"
    [ "policy", "hu/#{KEY_HASH}?l=stdin" ].each do |suffix|
      get "#{BASES.first}/gmail.com/#{suffix}"
      assert_response :not_found
    end
  end

  private

  def each_layout
    BASES.each do |base|
      host! base == BASES.first ? "adrianjunge.de" : "openpgpkey.adrianjunge.de"
      yield base, "#{base}/hu/#{KEY_HASH}"
    end
  end

  def assert_public_headers
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_includes response.headers.fetch("Cache-Control"), "must-revalidate"
    assert_not_includes response.headers.fetch("Cache-Control"), "immutable"
  end
end
