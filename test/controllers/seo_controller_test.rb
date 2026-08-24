require "test_helper"

class SeoControllerTest < ActionDispatch::IntegrationTest
  test "root page exposes shared SEO metadata and feed discovery" do
    get root_path

    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_select "meta[charset=?]", "utf-8"
    assert_select "link[rel='canonical'][href=?]", root_url
    assert_select "meta[property='og:site_name'][content=?]", SeoHelper::SITE_NAME
    assert_select "meta[property='og:type'][content=?]", "website"
    assert_select "meta[name='twitter:card'][content=?]", "summary_large_image"
    assert_json_ld_type "WebSite"
    assert_json_ld_type "SearchAction", nested: true
    assert_select "script[type='application/ld+json']", text: %r{/timeline\?q=\{search_term_string\}}
    assert_select "link[rel='stylesheet'][href=?]", TerminalHelper::XTERM_CSS_CDN_URL
    assert_select "link[rel='stylesheet'][href^='#{asset_path_prefix}'][href*='xterm.css']", 0
    assert_select "link[rel='alternate'][title='adrianjunge.de (RSS)'][href=?]", feed_xml_url
    assert_select "link[rel='alternate'][title='adrianjunge.de (Atom)'][href=?]", feed_url(format: :atom)
    assert_select "link[rel='alternate'][title='adrianjunge.de (JSON Feed)'][href=?]", feed_json_url
    assert_json_ld_type "BreadcrumbList"
    assert_select "link[rel='alternate'][title='Blog Posts (RSS)']", 0
    assert_select "link[rel='alternate'][title='CTF Writeups (RSS)']", 0
  end

  test "CTF article metadata mirrors the selected repository record" do
    post = production_content_repository.ctf_posts.find do |candidate|
      candidate[:metadata]["published"].present? && Array(candidate[:metadata]["categories"]).any?
    end || flunk("expected a published categorized CTF writeup")
    metadata = post[:metadata]
    section = metadata["ctf"].presence || post[:which]
    expected_tags = (Array(metadata["categories"]) + [ post[:which] ]).map(&:to_s).reject(&:blank?).uniq

    get post[:link]

    assert_response :success
    assert_select "meta[property='og:type'][content=?]", "article"
    assert_select "meta[property='article:published_time'][content]", 1
    assert_select "meta[property='article:section'][content=?]", section
    assert_equal expected_tags.sort, meta_contents("meta[property='article:tag']").sort

    article = json_ld_by_type("TechArticle")
    assert article
    assert_equal "#{post[:title]} - #{section} writeup", article.fetch("headline")
    assert_equal section, article.fetch("articleSection")
    assert_equal absolute_url_for(post[:link]), article.fetch("url")
    assert_json_ld_type "BreadcrumbList"
  end

  test "blog article metadata mirrors the selected repository record" do
    repository = production_content_repository
    post = repository.blog_posts.find do |candidate|
      candidate[:metadata]["published"].present? && candidate[:which].present?
    end || flunk("expected a published blog post")
    expected_tags = (Array(post[:metadata]["categories"]) + [ post[:which] ]).map(&:to_s).reject(&:blank?).uniq

    get post[:link]

    assert_response :success
    assert_select "meta[property='og:type'][content=?]", "article"
    assert_select "meta[property='article:section'][content=?]", post[:which]
    assert_equal expected_tags.sort, meta_contents("meta[property='article:tag']").sort

    article = json_ld_by_type("TechArticle")
    assert article
    assert_equal post[:title], article.fetch("headline")
    assert_equal post[:which], article.fetch("articleSection")
    assert_equal absolute_url_for(post[:link]), article.fetch("url")
    assert_json_ld_type "BreadcrumbList"
  end

  test "collection JSON-LD lists complete current collections" do
    repository = production_content_repository
    index = ContentIndex.new(repository: repository)
    cases = [
      [ blog_path, repository.blog_posts.map { |post| [ post[:title], post[:link] ] } ],
      [ ctf_path, repository.ctf_events.map { |event| [ event[:name], event[:metadata]["writeups"] ] } ],
      [ timeline_path, index.all_items.map { |item| [ item[:title], item[:link] ] } ]
    ]

    cases.each do |path, expected_items|
      get path

      assert_response :success
      collection = json_ld_by_type("CollectionPage")
      assert collection, "missing CollectionPage JSON-LD for #{path}"
      assert_equal expected_json_ld_items(expected_items), json_ld_item_pairs(collection)
      assert_json_ld_type "BreadcrumbList"
    end

    get about_path
    assert_response :success
    collection = json_ld_by_type("CollectionPage")
    assert collection
    assert_equal %w[cves bug-bounties my-challenges certificates talks achievements].map { |anchor| absolute_url_for("/about##{anchor}") }.sort,
                 collection.dig("mainEntity", "itemListElement").map { |item| item.fetch("url") }.sort
    assert_json_ld_type "BreadcrumbList"
  end

  test "error pages are excluded from indexing" do
    get "/404"

    assert_response :not_found
    assert_select "meta[name='robots'][content=?]", "noindex, nofollow"
    assert_select "link[rel='canonical']", 0
  end

  test "sitemap URL set exactly matches public repository routes" do
    repository = production_content_repository

    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type
    document = Nokogiri::XML(response.body)
    assert_empty document.errors
    actual_urls = document.xpath("//*[local-name()='url']/*[local-name()='loc']").map(&:text).sort
    expected_urls = [ root_url, about_url, ctf_url, blog_url, timeline_url ]
    expected_urls.concat(repository.blog_posts.map { |post| blog_post_url(post[:slug]) })
    repository.ctf_events.each do |event|
      posts = repository.ctf_posts_for_event(event[:slug])
      next if posts.empty?

      expected_urls << "#{ctf_url}/#{ERB::Util.url_encode(event[:slug])}"
      expected_urls.concat(posts.map do |post|
        "#{ctf_url}/#{ERB::Util.url_encode(post[:directory])}/#{ERB::Util.url_encode(post[:slug])}"
      end)
    end

    assert_equal expected_urls.uniq.sort, actual_urls
    lastmods = document.xpath("//*[local-name()='url']/*[local-name()='lastmod']")
    assert_equal actual_urls.length, lastmods.length
    assert lastmods.all? { |node| node.text.match?(/\A\d{4}-\d{2}-\d{2}\z/) }
    assert actual_urls.none? { |url| url.include?("/feed") }
  end

  test "robots file points crawlers at the sitemap" do
    get "/robots.txt"

    assert_response :success
    assert_includes response.body, "User-agent: *"
    assert_includes response.body, "Allow: /"
    assert_includes response.body, "Sitemap: https://adrianjunge.de/sitemap.xml"
  end

  private

  def json_ld_documents
    css_select("script[type='application/ld+json']").flat_map do |node|
      value = JSON.parse(node.text)
      value.is_a?(Array) ? value : [ value ]
    end
  end

  def json_ld_by_type(type)
    json_ld_documents.find { |document| document["@type"] == type }
  end

  def assert_json_ld_type(type, nested: false)
    found = if nested
      json_ld_documents.any? { |document| json_ld_contains_type?(document, type) }
    else
      json_ld_by_type(type).present?
    end
    assert found, "expected JSON-LD type #{type}"
  end

  def json_ld_contains_type?(value, type)
    case value
    when Hash
      value["@type"] == type || value.values.any? { |child| json_ld_contains_type?(child, type) }
    when Array
      value.any? { |child| json_ld_contains_type?(child, type) }
    else
      false
    end
  end

  def json_ld_item_pairs(collection)
    Array(collection.dig("mainEntity", "itemListElement"))
      .map { |item| [ item.fetch("name"), item.fetch("url") ] }
      .sort
  end

  def expected_json_ld_items(items)
    items.map { |title, link| [ ActionController::Base.helpers.strip_tags(title.to_s).squish, absolute_url_for(link) ] }.sort
  end

  def meta_contents(selector)
    css_select(selector).map { |node| node["content"] }
  end

  def absolute_url_for(path)
    return path if path.to_s.match?(%r{\Ahttps?://})

    "http://www.example.com#{path}"
  end
end
