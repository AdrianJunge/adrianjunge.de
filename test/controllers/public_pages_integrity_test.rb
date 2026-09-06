require "test_helper"
require "set"
require "uri"

class PublicPagesIntegrityTest < ActionDispatch::IntegrationTest
  test "all generated public page routes render successfully" do
    public_page_paths.each do |path|
      get path

      assert_response :success, "expected #{path} to render"
      assert_select "#terminal-container", 1, "expected #{path} to include the terminal shell"
      assert_select "nav#top-taskbar", 1, "expected #{path} to include the top taskbar"
    end
  end

  test "internal links from generated public pages resolve" do
    checked_paths = Set.new

    public_page_paths.each do |path|
      get path
      assert_response :success, "expected #{path} to render before checking links"

      internal_page_links.each do |href|
        target_path = normalized_internal_link_path(href)
        next if target_path.blank? || checked_paths.include?(target_path)

        checked_paths << target_path
        get target_path

        assert_includes [ 200, 301, 302 ], response.status, "expected #{href} from #{path} to resolve"
      end
    end

    missing_public_pages = public_page_paths.to_set - checked_paths
    assert_empty missing_public_pages, "public pages without an internal link: #{missing_public_pages.to_a.sort.join(', ')}"
  end

  test "internal link normalization rejects external and malformed URLs" do
    assert_equal "/blog/example?q=term", normalized_internal_link_path("/blog/example?q=term#result")
    assert_equal "/about", normalized_internal_link_path("https://www.example.com/about")
    assert_nil normalized_internal_link_path("https://external.example/about")
    assert_nil normalized_internal_link_path("//external.example/about")
    assert_nil normalized_internal_link_path("mailto:test@example.com")
    assert_nil normalized_internal_link_path("http://[")
  end

  test "same-page and cross-page fragment links have rendered destinations" do
    pages = public_page_paths.to_h do |path|
      get path
      assert_response :success
      [ path, Nokogiri::HTML(response.body) ]
    end
    pages.each do |path, document|
      document.css("a[href]").each do |link|
        uri = URI.join("http://www.example.com#{path}", link["href"])
        next unless uri.host == "www.example.com" && uri.fragment.present?
        next if ignored_internal_path?(uri.path)

        target = pages[uri.path]
        next unless target

        id = URI::DEFAULT_PARSER.unescape(uri.fragment)
        assert target.css("[id]").any? { |element| element["id"] == id }, "missing ##{id} on #{uri.path}, linked from #{path}"
      rescue URI::InvalidURIError
        # Malformed links are covered by the route/link validation checks.
      end
    end
  end

  private

  def public_page_paths
    repository = ContentRepository.new
    main_paths = [ root_path, about_path, ctf_path, blog_path, timeline_path ]
    ctf_overview_paths = repository.ctf_metadata.values.map { |entry| entry.fetch("writeups") }
    ctf_post_paths = repository.ctf_posts.map { |post| post[:link] }
    blog_post_paths = repository.blog_posts.map { |post| post[:link] }

    (main_paths + ctf_overview_paths + ctf_post_paths + blog_post_paths).uniq
  end

  def internal_page_links
    css_select("a[href], area[href]").filter_map { |node| node["href"].presence }
  end

  def normalized_internal_link_path(href)
    uri = URI.parse(href)
    return nil if uri.host.present? && uri.host != "www.example.com"
    return nil if uri.scheme.present? && !%w[http https].include?(uri.scheme)

    path = uri.path.presence || root_path
    return nil if ignored_internal_path?(path)

    query = uri.query.present? ? "?#{uri.query}" : ""
    "#{path}#{query}"
  rescue URI::InvalidURIError
    nil
  end

  def ignored_internal_path?(path)
    path.start_with?(
      "#{asset_path_prefix}/",
      "/ctf/resources/",
      "/rails/",
      "/pgp-vurlo.asc"
    )
  end
end
