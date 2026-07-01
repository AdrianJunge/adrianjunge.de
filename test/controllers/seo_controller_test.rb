require "test_helper"

class SeoControllerTest < ActionDispatch::IntegrationTest
  test "root page exposes shared SEO metadata and CDN xterm stylesheet" do
    get root_path

    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_select "meta[charset=?]", "utf-8"
    assert_select "link[rel='canonical'][href=?]", root_url
    assert_select "meta[property='og:site_name'][content=?]", "vurlo"
    assert_select "meta[property='og:type'][content=?]", "website"
    assert_select "meta[name='twitter:card'][content=?]", "summary_large_image"
    assert_select "script[type='application/ld+json']", text: /"@type":"WebSite"/
    assert_select "script[type='application/ld+json']", text: /"@type":"SearchAction"/
    assert_select "script[type='application/ld+json']", text: %r{/timeline\?q=\{search_term_string\}}
    assert_select "link[rel='stylesheet'][href=?]", TerminalHelper::XTERM_CSS_CDN_URL
    assert_select "link[rel='stylesheet'][href^='#{asset_path_prefix}'][href*='xterm.css']", 0
    assert_select "link[rel='alternate'][title='adrianjunge.de (RSS)'][href=?]", feed_xml_url
    assert_select "link[rel='alternate'][title='adrianjunge.de (Atom)'][href=?]", feed_url(format: :atom)
    assert_select "link[rel='alternate'][title='adrianjunge.de (JSON Feed)'][href=?]", feed_json_url
    assert_select "script[type='application/ld+json']", text: /"@type":"BreadcrumbList"/
    assert_select "link[rel='alternate'][title='Blog Posts (RSS)']", 0
    assert_select "link[rel='alternate'][title='CTF Writeups (RSS)']", 0
  end

  test "article pages expose article metadata" do
    get "/ctf/kitctf/xmalloc"

    assert_response :success
    assert_select "meta[property='og:type'][content=?]", "article"
    assert_select "meta[property='article:published_time']", 1
    assert_select "meta[property='article:section'][content=?]", "KITCTFCTF"
    assert_select "meta[property='article:author'][content=?]", "ju256"
    assert_select "meta[property='article:tag'][content=?]", "Pwn"
    assert_select "meta[property='article:tag'][content=?]", "KITCTF"
    assert_select "meta[property='og:image'][content*='ctf/kitctf']"
    assert_select "script[type='application/ld+json']", text: /"@type":"TechArticle"/
    assert_select "script[type='application/ld+json']", text: /"articleSection":"KITCTFCTF"/
    assert_select "script[type='application/ld+json']", text: /"@type":"BreadcrumbList"/
  end

  test "blog article pages use post-specific SEO metadata" do
    get blog_post_path("java-strings")

    assert_response :success
    assert_select "meta[property='og:type'][content=?]", "article"
    assert_select "meta[property='article:section'][content=?]", "Security Research"
    assert_select "meta[property='article:tag'][content=?]", "JVM Internals"
    assert_select "meta[property='og:image'][content*='blog/java']"
    assert_select "script[type='application/ld+json']", text: /"headline":"Funny Java Strings\?"/
    assert_select "script[type='application/ld+json']", text: /"articleSection":"Security Research"/
    assert_select "script[type='application/ld+json']", text: /"@type":"BreadcrumbList"/
  end

  test "collection pages expose item lists from current content" do
    get blog_path
    assert_response :success
    assert_select "script[type='application/ld+json']", text: /"@type":"ItemList"/
    assert_select "script[type='application/ld+json']", text: /"Funny Java Strings\?"/
    assert_select "script[type='application/ld+json']", text: /"@type":"BreadcrumbList"/

    get ctf_path
    assert_response :success
    assert_select "script[type='application/ld+json']", text: /"@type":"ItemList"/
    assert_select "script[type='application/ld+json']", text: /"UMDCTF"/
    assert_select "script[type='application/ld+json']", text: /"@type":"BreadcrumbList"/

    get timeline_path
    assert_response :success
    assert_select "script[type='application/ld+json']", text: /"@type":"ItemList"/
    assert_select "script[type='application/ld+json']", text: /"Funny Java Strings\?"/
    assert_select "script[type='application/ld+json']", text: /"@type":"BreadcrumbList"/

    get about_path
    assert_response :success
    assert_select "script[type='application/ld+json']", text: /"Created CTF challenges"/
    assert_select "script[type='application/ld+json']", text: /"@type":"BreadcrumbList"/
  end

  test "error pages are excluded from indexing" do
    get "/404"

    assert_response :not_found
    assert_select "meta[name='robots'][content=?]", "noindex, nofollow"
    assert_select "link[rel='canonical']", 0
  end

  test "sitemap lists canonical page URLs" do
    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_includes response.body, "<loc>#{root_url}</loc>"
    assert_includes response.body, "<loc>#{timeline_url}</loc>"
    assert_includes response.body, "<loc>#{ctf_url}/umdctf/A%20Minecraft%20Movie</loc>"
    assert_includes response.body, "<loc>#{blog_post_url("htb-cpts")}</loc>"
    assert_includes response.body, "<loc>#{blog_post_url("java-strings")}</loc>"
    assert_not_includes response.body, blog_post_url("frankendancer-net-shred-overrun")
    assert_match %r{<lastmod>\d{4}-\d{2}-\d{2}</lastmod>}, response.body
    assert_not_includes response.body, "/feed"
  end

  test "robots file points crawlers at the sitemap" do
    get "/robots.txt"

    assert_response :success
    assert_includes response.body, "User-agent: *"
    assert_includes response.body, "Allow: /"
    assert_includes response.body, "Sitemap: https://adrianjunge.de/sitemap.xml"
  end
end
