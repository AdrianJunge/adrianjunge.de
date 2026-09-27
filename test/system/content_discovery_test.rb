require "application_system_test_case"

class ContentDiscoveryTest < ApplicationSystemTestCase
  test "article endings retain only previous and next navigation on mobile and desktop" do
    articles = [ production_content_repository.blog_posts, production_content_repository.ctf_posts ]

    [ 390, 1440 ].each do |width|
      page.current_window.resize_to(width, 1000)

      articles.each do |posts|
        visit posts[1][:link]
        assert_no_selector ".article-discovery, .article-follow, .article-feed-links", visible: :all
        assert_no_selector ".writeup-container h2", text: /\A(?:Keep reading|Follow new writing)\z/, visible: :all
        within ".writeup-container > .next-previous-writeups:last-child" do
          assert_selector ".previous-writeup-btn[href='#{posts[2][:link]}']"
          assert_selector ".next-writeup-btn[href='#{posts[0][:link]}']"
        end
        assert_no_horizontal_overflow(width)

        find(".previous-writeup-btn").send_keys(:enter)
        assert_current_path posts[2][:link]
        assert_no_horizontal_overflow(width)
      end
    end
  end

  private

  def assert_no_horizontal_overflow(width)
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width + 1
  end
end
