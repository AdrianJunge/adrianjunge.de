require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "site index is conditional JSON data accessible without a modern browser" do
    repository = fixture_content_repository
    with_stubbed_content_repository(repository) do
      get site_search_index_path, headers: { "User-Agent" => "Mozilla/5.0 Version/10.0 Safari/602.1" }
      assert_response :success
      payload = response.parsed_body
      assert_equal "2", payload.fetch("version")
      assert_not_includes response.body, SiteProfile.email
      assert_equal SiteSearch.new(repository: repository).documents.pluck(:url), payload.fetch("documents").pluck("url")
      assert_not payload.key?("articles")
      assert_includes response.headers["Cache-Control"], "public"
      etag = response.headers.fetch("ETag")
      get site_search_index_path, headers: { "If-None-Match" => etag }
      assert_response :not_modified

      repository.blog_posts.first[:body] += "\n\nChanged searchable content."
      get site_search_index_path, headers: { "If-None-Match" => etag }
      assert_response :success
      assert_not_equal etag, response.headers.fetch("ETag")
    end
  end

  test "all shipped index destinations and section fragments exist on live pages" do
    documents = SiteSearch.new.documents
    documents.group_by { |document| document[:url].split("#", 2).first }.each do |path, records|
      get path
      assert_response :success, path
      live_ids = css_select("[id]").map { |node| node["id"] }
      records.each do |document|
        fragments = [ document[:url].split("#", 2)[1], *document[:sections].pluck(:anchor) ].compact_blank
        fragments.each { |fragment| assert_includes live_ids, fragment, "missing #{path}##{fragment}" }
      end
    end
  end

  test "the withdrawn discovery pages remain unavailable" do
    %w[/search /reading-paths /reading-paths/algorithms-two-angles /explore].each do |path|
      get path
      assert_response :not_found
    end
    get site_search_index_path
    assert_response :success
    assert response.parsed_body.fetch("documents").none? { |document| document.fetch("url").match?(%r{\A/(?:search|reading-paths|research|talks|contact|explore)(?:/|\z)}) }
  end
end
