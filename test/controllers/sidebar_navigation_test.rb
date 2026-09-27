require "test_helper"

class SidebarNavigationTest < ActionDispatch::IntegrationTest
  MAIN_NAV_LINKS = {
    "Home" => "/",
    "About" => "/about",
    "CTF" => "/ctf",
    "Blog" => "/blog",
    "Timeline" => "/timeline"
  }.freeze

  PUBLIC_PAGES_WITH_TASKBAR = [
    "/",
    "/about",
    "/ctf",
    "/blog",
    "/timeline"
  ].freeze

  test "main top taskbar navigation is present on every public page" do
    PUBLIC_PAGES_WITH_TASKBAR.each do |path|
      get path

      assert_response :success, "expected #{path} to render successfully"

      assert_select ".flex-grow > .taskbar-item", 0,
                    "expected #{path} not to render taskbar items outside the top taskbar"
      assert_select "#menu-icon-right", 0
      assert_select "#menu-icon-left", 0
      assert_select "nav#top-taskbar.top-taskbar[aria-label=?]", "Primary navigation", 1
      assert_select "nav#top-taskbar .top-taskbar-inner", 1

      MAIN_NAV_LINKS.each do |label, href|
        assert_select "#top-taskbar .taskbar-link[href=?]", href, { text: /#{Regexp.escape(label)}/, count: 1 },
                      "expected #{path} to include one #{label} taskbar link"
      end

      assert_select "#top-taskbar details.taskbar-feed-menu", 1
      assert_select "#top-taskbar .taskbar-feed-toggle", { text: /Feeds/, count: 1 },
                    "expected #{path} to include the feeds dropdown"
      assert_select "#top-taskbar .taskbar-feed-option[href=?]", feed_xml_path, { text: /RSS/, count: 1 },
                    "expected #{path} to include the RSS feed link"
      assert_select "#top-taskbar .taskbar-feed-option[href=?]", feed_path(format: :atom), { text: /Atom/, count: 1 },
                    "expected #{path} to include the Atom feed link"
      assert_select "#top-taskbar .taskbar-feed-option[href=?]", feed_json_path, { text: /JSON/, count: 1 },
                    "expected #{path} to include the JSON feed link"
      assert_select "#terminal-taskbar-button, #terminal-container", 0
      assert_select "#top-taskbar .taskbar-item button#search-taskbar-button[disabled][data-site-search-open][aria-controls=site-search-dialog][aria-haspopup=dialog][aria-expanded=false]", { text: /Search/, count: 1 },
                    "expected #{path} to include the global search launcher"
      assert_select "footer a[href='/reading-paths'], footer a[href='/search']", 0
    end
  end

  test "top taskbar marks the current main section" do
    MAIN_NAV_LINKS.each_value do |href|
      get href

      assert_response :success
      assert_select "#top-taskbar .taskbar-link.is-active[aria-current=page][href=?]", href, 1
    end
  end
end
