require "test_helper"

class SidebarNavigationTest < ActionDispatch::IntegrationTest
  MAIN_NAV_LINKS = {
    "Home" => "/",
    "About me" => "/about",
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

      assert_select "#top-taskbar #terminal-taskbar-button", 1, "expected #{path} to include the terminal taskbar button"
    end
  end

  test "top taskbar marks the current main section" do
    MAIN_NAV_LINKS.each_value do |href|
      get href

      assert_response :success
      assert_select "#top-taskbar .taskbar-link.is-active[aria-current=page][href=?]", href, 1
    end
  end

  test "terminal exposes only route scoped child navigation" do
    expected_labels = {
      "/" => %w[~ . .. about ctf blog timeline],
      "/about" => %w[~ . ..],
      "/timeline" => %w[~ . ..]
    }

    expected_labels.each do |path, labels|
      get path

      assert_response :success
      assert_equal labels, terminal_labels_for_response, "unexpected terminal entries for #{path}"
    end

    get "/ctf"
    assert_response :success
    ctf_labels = terminal_labels_for_response
    assert_includes ctf_labels, "cscg"
    assert_includes ctf_labels, "gpnctf"
    assert_not_includes ctf_labels, "about"
    assert_not_includes ctf_labels, "blog"

    get "/blog"
    assert_response :success
    blog_labels = terminal_labels_for_response
    assert_includes blog_labels, "htb-cpts"
    assert_includes blog_labels, "java-strings"
    assert_not_includes blog_labels, "about"
    assert_not_includes blog_labels, "ctf"

    get "/ctf/cscg"
    assert_response :success
    writeup_labels = terminal_labels_for_response
    assert_includes writeup_labels, "KDF dream"
    assert_not_includes writeup_labels, "blog"
    assert_not_includes writeup_labels, "about"

    get "/ctf/cscg/KDF%20dream"
    assert_response :success
    assert_equal %w[~ . ..], terminal_labels_for_response

    get "/blog/htb-cpts"
    assert_response :success
    assert_equal %w[~ . ..], terminal_labels_for_response
  end

  private

  def terminal_labels_for_response
    terminal = css_select("#terminal-container").first
    assert terminal, "expected response to include terminal data"

    JSON.parse(terminal["data-terminal-text"]).map { |entry| entry["label"] }
  end
end
