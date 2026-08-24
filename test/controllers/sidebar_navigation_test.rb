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
    repository = production_content_repository
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
    expected_ctf_entries = repository.ctf_events.map do |event|
      { "label" => event.fetch(:slug), "url" => event.fetch(:metadata).fetch("writeups") }
    end
    assert_equal base_terminal_entries("/ctf", "/") + expected_ctf_entries, terminal_entries_for_response

    get "/blog"
    assert_response :success
    assert_equal "/blog", terminal_entry_for(".").fetch("url")
    assert_equal "/", terminal_entry_for("..").fetch("url")
    expected_blog_entries = repository.blog_posts.map do |post|
      { "label" => post[:slug], "url" => post[:link] }
    end
    assert_equal base_terminal_entries("/blog", "/") + expected_blog_entries, terminal_entries_for_response

    event = repository.ctf_events.find { |candidate| repository.ctf_posts_for_event(candidate[:slug]).any? } ||
      flunk("expected at least one public CTF event with writeups")
    event_path = "/ctf/#{event[:slug]}"
    event_posts = repository.ctf_posts_for_event(event[:slug])

    get event_path
    assert_response :success
    assert_equal event_path, terminal_entry_for(".").fetch("url")
    assert_equal "/ctf", terminal_entry_for("..").fetch("url")
    expected_writeup_entries = event_posts.map do |post|
      { "label" => post[:slug], "url" => post[:link] }
    end
    assert_equal base_terminal_entries(event_path, "/ctf") + expected_writeup_entries, terminal_entries_for_response

    writeup = event_posts.first
    get writeup[:link]
    assert_response :success
    assert_equal %w[~ . ..], terminal_labels_for_response
    assert_equal writeup[:link], terminal_entry_for(".").fetch("url")
    assert_equal event_path, terminal_entry_for("..").fetch("url")

    blog_post = repository.blog_posts.first || flunk("expected at least one public blog post")
    get blog_post[:link]
    assert_response :success
    assert_equal %w[~ . ..], terminal_labels_for_response
    assert_equal blog_post[:link], terminal_entry_for(".").fetch("url")
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

  def base_terminal_entries(current, parent)
    [
      { "label" => "~", "url" => "/", "description" => "home" },
      { "label" => ".", "url" => current, "description" => "current" },
      { "label" => "..", "url" => parent, "description" => "parent" }
    ]
  end
end
