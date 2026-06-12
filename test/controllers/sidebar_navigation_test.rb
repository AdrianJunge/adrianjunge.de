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

      assert_select "#top-taskbar details.taskbar-feed-menu", 1
      assert_select "#top-taskbar .taskbar-feed-toggle", { text: /Feeds/, count: 1 },
                    "expected #{path} to include the feeds dropdown"
      assert_select "#top-taskbar .taskbar-feed-option[href=?]", feed_xml_path, { text: /RSS/, count: 1 },
                    "expected #{path} to include the RSS feed link"
      assert_select "#top-taskbar .taskbar-feed-option[href=?]", feed_path(format: :atom), { text: /Atom/, count: 1 },
                    "expected #{path} to include the Atom feed link"
      assert_select "#top-taskbar .taskbar-feed-option[href=?]", feed_json_path, { text: /JSON/, count: 1 },
                    "expected #{path} to include the JSON feed link"
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
      assert_equal path, terminal_entry_for(".").fetch("url"), "unexpected current terminal URL for #{path}"
    end

    get "/ctf"
    assert_response :success
    assert_equal "/ctf", terminal_entry_for(".").fetch("url")
    assert_equal "/", terminal_entry_for("..").fetch("url")
    ctf_labels = terminal_labels_for_response
    assert_includes ctf_labels, "cscg"
    assert_includes ctf_labels, "gpnctf"
    assert_equal "/ctf/cscg", terminal_entry_for("cscg").fetch("url")
    assert_equal "/ctf/gpnctf", terminal_entry_for("gpnctf").fetch("url")
    assert_not_includes ctf_labels, "about"
    assert_not_includes ctf_labels, "blog"

    get "/blog"
    assert_response :success
    assert_equal "/blog", terminal_entry_for(".").fetch("url")
    assert_equal "/", terminal_entry_for("..").fetch("url")
    blog_labels = terminal_labels_for_response
    assert_includes blog_labels, "htb-cpts"
    assert_includes blog_labels, "java-strings"
    assert_equal "/blog/htb-cpts", terminal_entry_for("htb-cpts").fetch("url")
    assert_equal "/blog/java-strings", terminal_entry_for("java-strings").fetch("url")
    assert_not_includes blog_labels, "about"
    assert_not_includes blog_labels, "ctf"

    get "/ctf/cscg"
    assert_response :success
    assert_equal "/ctf/cscg", terminal_entry_for(".").fetch("url")
    assert_equal "/ctf", terminal_entry_for("..").fetch("url")
    writeup_labels = terminal_labels_for_response
    assert_includes writeup_labels, "KDF dream"
    assert_equal "/ctf/cscg/KDF%20dream", terminal_entry_for("KDF dream").fetch("url")
    assert_not_includes writeup_labels, "blog"
    assert_not_includes writeup_labels, "about"

    get "/ctf/cscg/KDF%20dream"
    assert_response :success
    assert_equal %w[~ . ..], terminal_labels_for_response
    assert_equal "/ctf/cscg/KDF%20dream", terminal_entry_for(".").fetch("url")
    assert_equal "/ctf/cscg", terminal_entry_for("..").fetch("url")

    get "/blog/htb-cpts"
    assert_response :success
    assert_equal %w[~ . ..], terminal_labels_for_response
    assert_equal "/blog/htb-cpts", terminal_entry_for(".").fetch("url")
    assert_equal "/blog", terminal_entry_for("..").fetch("url")
  end

  private

  def terminal_entry_for(label)
    terminal_entries_for_response.find { |entry| entry["label"] == label } ||
      flunk("expected terminal entry #{label.inspect}")
  end

  def terminal_labels_for_response
    terminal_entries_for_response.map { |entry| entry["label"] }
  end

  def terminal_entries_for_response
    terminal = css_select("#terminal-container").first
    assert terminal, "expected response to include terminal data"

    JSON.parse(terminal["data-terminal-text"])
  end
end
