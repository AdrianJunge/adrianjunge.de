require "test_helper"

class ArticleReadingTest < ActionDispatch::IntegrationTest
  test "blog and CTF articles end with previous and next navigation without follow or related sections" do
    [ production_content_repository.blog_posts, production_content_repository.ctf_posts ].each do |posts|
      assert_operator posts.length, :>=, 3
      get posts[1][:link]
      assert_response :success
      assert_select ".writeup-container > .next-previous-writeups:last-child" do
        assert_select ".previous-writeup-btn[href=?]", posts[2][:link]
        assert_select ".next-writeup-btn[href=?]", posts[0][:link]
      end
      assert_select ".article-discovery, .article-follow, .article-feed-links", 0
      assert_select ".writeup-container h2", text: /\A(?:Keep reading|Follow new writing)\z/, count: 0
    end
  end

  test "blog and CTF articles retain their original dates social artwork and feed autodiscovery" do
    [ production_content_repository.blog_posts.first, production_content_repository.ctf_posts.first ].each do |post|
      get post[:link]
      assert_response :success
      assert_select ".post-meta-item", text: post[:metadata]["published"]
      assert_select "link[rel='alternate'][type='application/rss+xml'][href=?]", feed_xml_url
      assert_select "link[rel='alternate'][type='application/atom+xml'][href=?]", feed_url(format: :atom)
      assert_select "link[rel='alternate'][type='application/feed+json'][href=?]", feed_json_url
      assert_select ".article-corrections", 0
      assert_select "a", text: "Suggest a correction", count: 0
      assert_select "meta[property='og:image'][content*='/landing/social-card']", 1
      assert_select "meta[name='twitter:image'][content*='/landing/social-card']", 1
    end
  end

  test "reader summaries describe writeups in SEO without replacing the original challenge prompt" do
    post = production_content_repository.ctf_posts.find { |candidate| candidate[:metadata]["reader_summary"].present? }
    assert post, "Expected an authored reader summary"
    get post[:link]
    assert_response :success
    assert_select "meta[name='description'][content=?]", post[:description]
    assert_select "meta[property='og:description'][content=?]", post[:description]
    assert_select ".article-description[aria-label='About this writeup'] h2", text: "About this writeup"
    assert_select ".article-description[aria-label='About this writeup'] p", text: post[:metadata]["reader_summary"].squish
    assert_select ".article-description[aria-label='Challenge description'] p", text: post[:metadata]["description"].squish

    get "/ctf/#{post[:directory]}"
    assert_response :success
    assert_select ".blog-post-description", text: post[:metadata]["reader_summary"].squish
    assert_select ".blog-post-description", text: post[:metadata]["description"].squish, count: 0
  end
end
