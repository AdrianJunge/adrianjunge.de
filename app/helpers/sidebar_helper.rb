module SidebarHelper
  def default_taskbar_items
    [
      { image_path: "task-bar/home.svg", alt_text: "Home Icon", label: "Home", link: root_path },
      { image_path: "task-bar/about.svg", alt_text: "About Icon", label: "About me", link: about_path },
      { image_path: "task-bar/flag.svg", alt_text: "CTF Icon", label: "CTF", link: ctf_path },
      { image_path: "task-bar/blog.svg", alt_text: "Blog Icon", label: "Blog", link: blog_path }
    ]
  end

  def taskbar_icon_item(image_path:, alt_text:, label:, link: nil, icon_class:, label_class:, id: nil, target: nil, active: false)
    icon = content_tag(:span, class: icon_class) do
      image_tag(image_path, alt: "", width: 32, height: 32, class: "taskbar-icon-image", aria: { hidden: true })
    end
    item_classes = [ "taskbar-item", ("taskbar-item-terminal" if id == "terminal-taskbar-button"), ("is-active" if active) ].compact.join(" ")
    control_classes = [ (link ? "taskbar-link" : "taskbar-button-container"), ("is-active" if active) ].compact.join(" ")

    content_tag :div, class: item_classes do
      if link
        link_options = { class: control_classes, id: id, target: target, aria: { label: label } }
        link_options[:aria][:current] = "page" if active

        concat(
          link_to(link, link_options) do
            icon + content_tag(:span, label, class: label_class)
          end
        )
      else
        aria = { label: label }
        aria.merge!(controls: "terminal-container", expanded: false) if id == "terminal-taskbar-button"
        content_tag(:button, type: "button", class: control_classes, id: id, aria: aria) do
          concat(icon)
          concat(content_tag(:span, label, class: label_class))
        end
      end
    end
  end

  def taskbar_feed_item(icon_class:, label_class:)
    content_tag(:details, class: "taskbar-item taskbar-feed-menu") do
      concat(content_tag(:summary, class: "taskbar-button-container taskbar-feed-toggle", aria: { label: "Feeds" }) do
        concat(content_tag(:span, class: icon_class) do
          image_tag("task-bar/feed.svg", alt: "", width: 32, height: 32, class: "taskbar-icon-image", aria: { hidden: true })
        end)
        concat(content_tag(:span, "Feeds", class: label_class))
      end)

      concat(content_tag(:div, class: "taskbar-feed-dropdown") do
        safe_join(feed_dropdown_items)
      end)
    end
  end

  def render_taskbar_items(taskbar_items = [])
    taskbar_icon_class = "taskbar-icon"
    taskbar_label_class = "taskbar-label"

    content_tag(:nav, id: "top-taskbar", class: "top-taskbar", aria: { label: "Primary navigation" }) do
      concat(content_tag(:div, class: "top-taskbar-inner") do
        safe_join(top_taskbar_nodes(taskbar_items, taskbar_icon_class, taskbar_label_class))
      end)
    end
  end

  private

  def top_taskbar_nodes(taskbar_items, taskbar_icon_class, taskbar_label_class)
    rendered_links = []
    nodes = []

    (default_taskbar_items + Array(taskbar_items)).each do |item|
      link_key = item[:link].to_s.presence || item[:label].to_s
      next if rendered_links.include?(link_key)

      rendered_links << link_key
      nodes << taskbar_icon_item(
        image_path: item[:image_path],
        alt_text: item[:alt_text],
        label: item[:label],
        link: item[:link],
        icon_class: taskbar_icon_class,
        label_class: taskbar_label_class,
        target: item[:target],
        active: taskbar_link_active?(item[:link])
      )
    end

    nodes << taskbar_icon_item(
      image_path: "task-bar/timeline.svg",
      alt_text: "Timeline Icon",
      label: "Timeline",
      link: timeline_path,
      icon_class: taskbar_icon_class,
      label_class: taskbar_label_class,
      active: taskbar_link_active?(timeline_path)
    )

    nodes << taskbar_feed_item(
      icon_class: taskbar_icon_class,
      label_class: taskbar_label_class
    )

    nodes << taskbar_icon_item(
      image_path: "task-bar/terminal-prompt.svg",
      alt_text: "Terminal Icon",
      label: "Terminal",
      icon_class: taskbar_icon_class,
      label_class: taskbar_label_class,
      id: "terminal-taskbar-button"
    )

    nodes
  end

  def feed_dropdown_items
    [
      { href: feed_xml_path, icon: "task-bar/feed-rss.svg", alt: "RSS Feed Icon", label: "RSS" },
      { href: feed_path(format: :atom), icon: "task-bar/feed-atom.svg", alt: "Atom Feed Icon", label: "Atom" },
      { href: feed_json_path, icon: "task-bar/feed-json.svg", alt: "JSON Feed Icon", label: "JSON" }
    ].map do |item|
      link_to(
        item[:href],
        class: "taskbar-feed-option",
        title: "#{item[:label]} feed",
        aria: { label: "#{item[:label]} feed" }
      ) do
        image_tag(item[:icon], alt: "", width: 24, height: 24, class: "taskbar-feed-option-icon", aria: { hidden: true }) +
          content_tag(:span, item[:label], class: "taskbar-feed-option-label")
      end
    end
  end

  def taskbar_link_active?(link)
    path = link.to_s.split(/[?#]/).first
    return false unless path.start_with?("/")
    return request.path == root_path if path == root_path

    request.path == path || request.path.start_with?("#{path}/")
  end
end
