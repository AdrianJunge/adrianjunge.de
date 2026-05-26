require "test_helper"

class SidebarNavigationTest < ActionDispatch::IntegrationTest
  MAIN_NAV_LINKS = {
    "Home" => "/",
    "About me" => "/about",
    "CTF" => "/ctf",
    "Blog" => "/blog",
    "Posts" => "/posts-timeline"
  }.freeze

  PUBLIC_PAGES_WITH_SIDEBAR = [
    "/",
    "/about",
    "/ctf",
    "/blog",
    "/posts-timeline"
  ].freeze

  test "main sidebar navigation is present on every public page with sidebar" do
    PUBLIC_PAGES_WITH_SIDEBAR.each do |path|
      get path

      assert_response :success, "expected #{path} to render successfully"

      assert_select ".flex-grow > .taskbar-item", 0,
                    "expected #{path} not to render sidebar controls as normal-flow taskbar items"
      assert_select ".flex-grow > #menu-icon-right", 1,
                    "expected #{path} to render the sidebar open control as a fixed icon"
      assert_select ".flex-grow > #menu-icon-left", 1,
                    "expected #{path} to render the sidebar close control as a fixed icon"

      MAIN_NAV_LINKS.each do |label, href|
        assert_select ".taskbar-link[href=?]", href, { text: /#{Regexp.escape(label)}/, count: 1 },
                      "expected #{path} to include one #{label} sidebar link"
      end

      assert_select "#terminal-taskbar-button", 1, "expected #{path} to include the terminal sidebar button"
    end
  end

  test "terminal exposes absolute top level navigation on every public page" do
    PUBLIC_PAGES_WITH_SIDEBAR.each do |path|
      get path

      assert_response :success

      terminal = css_select("#terminal-container").first
      assert terminal, "expected #{path} to include terminal data"

      terminal_paths = JSON.parse(terminal["data-terminal-text"])
      by_label = terminal_paths.index_by { |entry| entry["label"] }

      assert_equal "/", by_label.fetch("~").fetch("url")
      assert_equal "/about", by_label.fetch("about").fetch("url")
      assert_equal "/ctf", by_label.fetch("ctf").fetch("url")
      assert_equal "/blog", by_label.fetch("blog").fetch("url")
      assert_equal "/posts-timeline", by_label.fetch("posts").fetch("url")
    end
  end
end
