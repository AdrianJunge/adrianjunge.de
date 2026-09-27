require "application_system_test_case"

class ErrorDetoursTest < ApplicationSystemTestCase
  test "404 suggestions fit narrow screens and work with keyboard and JavaScript disabled" do
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
    [ 320, 1440 ].each do |width|
      page.current_window.resize_to(width, 1000)
      visit "/blog/java-strngs"

      assert_selector "h1", text: "404 Page not found"
      destination = find(".error-detour-list a[href='/blog/java-strings']", text: "Funny Java Strings?")
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), :<=, 1
      assert_operator destination.native.rect.height, :>=, 44
      destination.send_keys(:enter)
      assert_current_path "/blog/java-strings"
      assert_selector "h1", text: "Funny Java Strings?"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
  end

  test "the scenic route describes and links directly to a published article without JavaScript" do
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
    page.current_window.resize_to(390, 1000)
    visit "/404"

    assert_no_selector ".error-detour-list"
    destination = find("a[data-random-article]")
    href = URI.parse(destination[:href]).path
    repository = production_content_repository
    article = (repository.blog_posts + repository.ctf_posts).find { |post| post[:link] == href }
    assert article, "Random destination must belong to the published article pool: #{href}"
    label = article[:type] == "ctf" ? "CTF writeup" : "post"
    assert_selector ".error-random-detour p", text: "A random #{label}, freshly picked for this wrong turn."
    destination.click
    assert_current_path href
    assert_selector "main.article-page"
  ensure
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
  end
end
