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
    assert_select "link[rel='stylesheet'][href=?]", TerminalHelper::XTERM_CSS_CDN_URL
    assert_select "link[rel='stylesheet'][href^='/assets'][href*='xterm.css']", 0
    assert_select "link[rel='alternate'][title='Blog Posts (RSS)']"
  end

  test "article pages expose article metadata" do
    get "/ctf/kitctf/xmalloc"

    assert_response :success
    assert_select "meta[property='og:type'][content=?]", "article"
    assert_select "meta[property='article:published_time']", 1
    assert_select "meta[property='article:tag'][content=?]", "pwn"
    assert_select "script[type='application/ld+json']", text: /"@type":"TechArticle"/
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
    assert_includes response.body, "<loc>#{search_url}</loc>"
    assert_includes response.body, "<loc>#{timeline_url}</loc>"
    assert_includes response.body, "<loc>#{ctf_url}/umdctf/A%20Minecraft%20Movie</loc>"
    assert_includes response.body, "<loc>#{blog_post_url("htb-cpts")}</loc>"
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
