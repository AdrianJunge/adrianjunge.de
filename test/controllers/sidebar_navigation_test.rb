require "test_helper"

class SidebarNavigationTest < ActionDispatch::IntegrationTest
  MAIN_NAV_LINKS = {
    "Home" => "/",
    "About me" => "/about",
    "CTF" => "/ctf",
    "Blog" => "/blog",
    "Timeline" => "/timeline"
  }.freeze

  PUBLIC_PAGES_WITH_SIDEBAR = [
    "/",
    "/about",
    "/ctf",
    "/blog",
    "/timeline"
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
