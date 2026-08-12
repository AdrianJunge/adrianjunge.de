require "test_helper"

class ContentPathSecurityTest < ActionDispatch::IntegrationTest
  test "catalogued blog posts and CTF writeups keep their canonical routes" do
    repository = ContentRepository.new
    blog_post = repository.blog_posts.first
    ctf_post = repository.ctf_posts.find { |post| post[:slug].include?(" ") } || repository.ctf_posts.first

    get blog_post[:link]
    assert_response :success
    assert_select ".writeup-title", text: blog_post[:title]

    get ctf_post[:link]
    assert_response :success
    assert_select ".writeup-title", text: ctf_post[:title]
  end

  test "unknown and noncanonical content paths fail closed" do
    repository = ContentRepository.new
    blog_post = repository.blog_posts.first
    ctf_post = repository.ctf_posts.first

    paths = [
      "/blog/not-a-published-post",
      "/blog/#{blog_post[:slug]}.md",
      "/blog/#{blog_post[:slug]}.html",
      "/ctf/not-a-configured-event",
      "/ctf/#{ctf_post[:directory]}/not-a-published-writeup",
      "/ctf/#{ctf_post[:directory]}/#{ERB::Util.url_encode(ctf_post[:slug])}.md"
    ]

    paths.each do |path|
      get path

      assert_response :not_found, "expected #{path.inspect} to be rejected"
    end
  end

  test "encoded traversal and separator variants never reach content actions" do
    repository = ContentRepository.new
    blog_slug = repository.blog_posts.first[:slug]
    ctf_post = repository.ctf_posts.first
    encoded_writeup = ERB::Util.url_encode(ctf_post[:slug])
    paths = [
      "/blog/%2e%2e%2f#{blog_slug}",
      "/blog/%252e%252e%252f#{blog_slug}",
      "/blog/%5c..%5c#{blog_slug}",
      "/blog/%00#{blog_slug}",
      "/blog/%2Fetc%2Fpasswd",
      "/blog/%E2%80%A4%E2%80%A4%2F#{blog_slug}",
      "/ctf/%2e%2e%2f#{ctf_post[:directory]}/#{encoded_writeup}",
      "/ctf/#{ctf_post[:directory]}/%2e%2e%2f#{encoded_writeup}",
      "/ctf/#{ctf_post[:directory]}/%252e%252e%252f#{encoded_writeup}",
      "/ctf/#{ctf_post[:directory]}/%5c..%5c#{encoded_writeup}",
      "/ctf/#{ctf_post[:directory]}/%00#{encoded_writeup}",
      "/ctf/#{ctf_post[:directory]}/%2Fetc%2Fpasswd"
    ]

    paths.each do |path|
      get path

      assert_includes [ 400, 404 ], response.status, "expected #{path.inspect} to be rejected"
      assert_not_includes response.body, "source \"https://rubygems.org\""
    end
  end

  test "query parameters cannot replace canonical route identifiers" do
    repository = ContentRepository.new
    blog_post = repository.blog_posts.first
    ctf_post = repository.ctf_posts.first

    get blog_post[:link], params: { which: "../../Gemfile" }
    assert_response :success
    assert_select ".writeup-title", text: blog_post[:title]

    get ctf_post[:link], params: { which: "../../app", writeup: "../../Gemfile" }
    assert_response :success
    assert_select ".writeup-title", text: ctf_post[:title]
  end

  test "private CTF resources are served only through opaque catalog identifiers" do
    repository = ContentRepository.new
    challenge_post, challenge = first_asset(repository, :challenge)
    writeup_post, writeup = first_asset(repository, :writeup)

    get challenge_post[:link]
    assert_response :success
    assert_select "a.download-btn[href=?]", ctf_file_download_path(challenge[:id])

    get writeup_post[:link]
    assert_response :success
    assert_select "a.open-pdf-btn[href=?]", ctf_file_download_path(writeup[:id])

    get ctf_file_download_path(challenge[:id])
    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_includes response.headers["Content-Disposition"], challenge[:basename]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]

    get ctf_file_download_path(writeup[:id])
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/inline/, response.headers["Content-Disposition"])
    assert_includes response.headers["Content-Disposition"], writeup[:basename]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]

    get ctf_file_download_path("0" * 64)
    assert_response :not_found

    get "/ctf/resources/../#{challenge[:id]}"
    assert_response :not_found

    get "/ctf/files/gpnctf/2025/smile-at-me.zip"
    assert_response :not_found

    get "/ctf/writeups/cscg/2024/hoster.pdf"
    assert_response :not_found

    assert_not Rails.root.join("public", "ctf", "files").exist?
    assert_not Rails.root.join("public", "ctf", "writeups").exist?
  end

  private

  def first_asset(repository, kind)
    repository.ctf_posts.each do |post|
      asset = repository.ctf_asset_for(post, kind)
      return [ post, asset ] if asset
    end

    flunk("expected at least one #{kind} asset")
  end
end
