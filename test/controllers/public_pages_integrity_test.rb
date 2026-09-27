require "test_helper"
require "set"
require_relative "../../scripts/support/site_integrity"

# This suite intentionally crawls the real published catalog. Synthetic filter
# behavior has its own independently specified fixtures in the system suite.
class PublicPagesIntegrityTest < ActionDispatch::IntegrationTest
  test "all generated public page routes render successfully" do
    public_page_paths.each do |path|
      get path

      assert_response :success, "expected #{path} to render"
      assert_select "#terminal-container, #terminal-taskbar-button", 0, "expected #{path} to omit the retired terminal"
      assert_select "nav#top-taskbar", 1, "expected #{path} to include the top taskbar"
    end
  end

  test "all published internal links finish successfully and fragments exist after redirects" do
    links = SiteIntegrity::LocalLinks.new(origins: [ "http://www.example.com", "https://www.example.com", SiteProfile.origin ]) do |path|
      get path
      [ response.status, response.headers.to_h, response.body.dup ]
    end
    checked = Set.new
    destinations = Set.new
    documents = {}

    public_page_paths.each do |path|
      source = links.resolve(links.target(path))
      source_document = Nokogiri::HTML(source.body)
      source_document.css("a[href], area[href]").each do |element|
        href = element["href"]
        target = links.target(href, from: source.uri)
        next unless target
        next if ignored_internal_path?(target.path) || checked.include?(target.to_s)

        checked << target.to_s
        result = links.resolve(target)
        destinations << result.uri.path
        document = documents[result.uri.request_uri] ||= Nokogiri::HTML(result.body)
        assert links.fragment_exists?(result, document: document), "missing #{result.uri.fragment.inspect} on #{result.uri.path}, linked by #{href.inspect} from #{path}"
      rescue SiteIntegrity::Failure => error
        flunk "#{href.inspect} from #{path}: #{error.message}"
      end
    end

    missing_public_pages = public_page_paths.to_set - destinations
    assert_empty missing_public_pages, "public pages without an internal link: #{missing_public_pages.to_a.sort.join(', ')}"
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

  def ignored_internal_path?(path)
    # Downloads and generated responsive assets are checked in production-check.
    path.start_with?("#{asset_path_prefix}/", "/ctf/resources/", "/rails/", "/pgp-vurlo.asc")
  end
end
