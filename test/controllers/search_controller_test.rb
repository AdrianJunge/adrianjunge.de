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
      payload.fetch("documents").each do |document|
        assert_match %r{\A#{Regexp.escape(asset_path_prefix)}/}, document.fetch("icon").fetch("src")
      end
      post = repository.blog_posts.first
      source = ContentImageHelper.image_attributes(post[:logo]).fetch(:src)
      indexed_post = payload.fetch("documents").find { |document| document["url"] == post[:link] }
      assert_equal ApplicationController.helpers.asset_path(source), indexed_post.dig("icon", "src")
      assert_equal false, indexed_post.dig("icon", "inverted")
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
      live_passages = SiteSearchPassages.extract(css_select("main").first)
      live_passages.concat(css_select(".timeline-kind-pill, .timeline-tag-pill").map { |node| node.text.squish })
      records.each do |document|
        fragments = [ document[:url].split("#", 2)[1], *document[:sections].pluck(:anchor) ].compact_blank
        fragments.each { |fragment| assert_includes live_ids, fragment, "missing #{path}##{fragment}" }
        document[:sections].each do |section|
          [ section[:heading], *section[:passages] ].compact_blank.each do |passage|
            assert live_passages.any? { |text| text.include?(passage) }, "#{path} does not display #{passage.inspect}"
          end
        end
      end
    end
  end

  test "standalone search result points to a visible timeline card absent from About" do
    repository = fixture_content_repository
    with_stubbed_content_repository(repository) do
      get timeline_path
      assert_response :success
      assert_select "#timeline-event-fixture-timeline-only.timeline-item .timeline-title", text: "Timeline Only Milestone"
      assert_select "#timeline-event-fixture-timeline-only .timeline-meta", text: /uniquetimelineword/
      assert_select "#timeline-event-fixture-timeline-hidden", 0
      structured_data = css_select("script[type='application/ld+json']").flat_map { |node| Array.wrap(JSON.parse(node.text)) }
      collection = structured_data.find { |document| document["@type"] == "CollectionPage" }
      assert collection
      assert_includes collection.dig("mainEntity", "itemListElement").pluck("url"),
                      SiteProfile.absolute_url("/timeline#timeline-event-fixture-timeline-only")

      get about_path
      assert_response :success
      assert_select "#fixture-timeline-only, #timeline-event-fixture-timeline-only", 0
    end
  end

  test "timeline disambiguation context matches the rendered page including controls and non-milestone cards" do
    repository = fixture_content_repository
    with_stubbed_content_repository(repository) do
      search = SiteSearch.new(repository: repository)
      document = search.documents.find { |record| record[:url] == timeline_path }
      get timeline_path
      assert_response :success
      assert_equal SiteSearchPassages.page_text(response.body), document.fetch(:page_text)
      assert_includes document[:page_text], "Oldest first"
      assert_includes document[:page_text], repository.ctf_posts.first[:title]
      assert_includes document[:page_text], "2023"
      assert_empty search.search("Oldest first")
    end
  end

  test "challenge author search context follows the displayed title attribution and publication order" do
    repository = fixture_content_repository
    post = repository.ctf_posts.first
    post[:metadata]["authors"] = [ { "name" => "nrg", "url" => "https://example.com/nrg" }, "the_moon_guy" ]
    document = SiteSearch.new(repository: repository).documents.find { |record| record[:url] == post[:link] }

    with_stubbed_content_repository(repository) do
      get post[:link]
      assert_response :success
      header = css_select(".writeup-year, .writeup-title, .writeup-authors-article, .post-meta-line")
      visible_passages = header.flat_map { |node| SiteSearchPassages.extract(node) }
      assert_equal visible_passages, document[:sections].first[:passages].first(visible_passages.length)
      assert_select ".writeup-authors-article .content-author-list", text: "nrg, the_moon_guy"
    end
  end

  test "timeline month precision retains its visible date label in search and markup" do
    repository = fixture_content_repository
    events = repository.timeline_events
    events.first.merge!("date" => "2019-09", "display_date" => "Around Sep 2019")

    repository.define_singleton_method(:timeline_events) { events }
    search = SiteSearch.new(repository: repository)
    url = "/timeline#timeline-event-fixture-timeline-only"
    document = search.documents.find { |entry| entry[:url] == url }
    assert_equal "Around Sep 2019", document[:sections].first[:passages].first
    assert_includes search.search("Around Sep 2019").pluck(:url), url

    with_stubbed_content_repository(repository) do
      get timeline_path
      assert_response :success
      assert_select "#timeline-event-fixture-timeline-only[data-filter-years='2019'] time[datetime='2019-09']", text: "Around Sep 2019"
      assert_select "#timeline-event-fixture-timeline-only time[datetime='2019-09-30T00:00:00Z']", 0
    end
  end

  test "timeline search passages follow rendered side badges and canonical card tags" do
    repository = fixture_content_repository
    events = repository.timeline_events
    events.first["tags"] = [
      "Beginnings", "algorithm", "ctf competition", "web", "difficulty:hard",
      "Topic one", "Topic two", "Topic three", "Overflowneedle", WriteupWinner::FILTER_LABEL
    ]
    repository.define_singleton_method(:timeline_events) { events }
    search = SiteSearch.new(repository: repository)
    document = search.documents.find { |entry| entry[:url] == "/timeline#timeline-event-fixture-timeline-only" }

    with_stubbed_content_repository(repository) do
      get timeline_path
      assert_response :success
      card = css_select("#timeline-event-fixture-timeline-only").sole
      visible_passages = card.css("time, .timeline-kind-pill, .timeline-title, .timeline-tag-pill, .timeline-meta").map { |node| node.text.squish }
      assert_equal visible_passages, document[:sections].flat_map { |section| section[:passages] }
      assert_equal [ "Algorithms", "CTF Competition", "Beginnings", "Web", "Hard", "Topic one", "Topic two", "Topic three" ], document[:tags]
      assert_not_includes document.to_json, "difficulty:hard"
      assert_not_includes document.to_json, WriteupWinner::FILTER_LABEL
      assert_empty search.search("Overflowneedle")
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

  test "blog categories are visible article badges with working timeline filters" do
    { "/blog/java-strings" => "JVM Internals", "/blog/joomla-sqli" => "AI-Assisted Auditing" }.each do |path, label|
      get path
      assert_response :success
      assert_select ".blog-article-meta-panel .article-meta-tags .article-meta-row-label", text: "Tags"
      assert_select ".blog-article-meta-panel a.category-badge-article[href=?]", timeline_path(tag: label), text: label
    end
  end
end
