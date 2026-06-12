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

    assert_operator checked_paths.length, :>, 20
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
    return nil if uri.scheme.present? && uri.host != "www.example.com"
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
      "/assets/",
      "/ctf/files/",
      "/rails/",
      "/pgp-vurlo.asc"
    )
  end
end
