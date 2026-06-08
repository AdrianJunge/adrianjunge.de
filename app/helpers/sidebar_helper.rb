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
      image_tag(image_path, alt: alt_text, class: "taskbar-icon-image")
    end
    item_classes = [ "taskbar-item", ("is-active" if active) ].compact.join(" ")
    control_classes = [ (link ? "taskbar-link" : "taskbar-button-container"), ("is-active" if active) ].compact.join(" ")

    content_tag :div, class: item_classes do
      if link
        link_options = { class: control_classes, id: id, target: target }
        link_options[:aria] = { current: "page" } if active

        concat(
          link_to(link, link_options) do
            icon + content_tag(:span, label, class: label_class)
          end
        )
      else
        content_tag(:div, class: control_classes, id: id) do
          concat(icon)
          concat(content_tag(:span, label, class: label_class))
        end
      end
    end
  end

  def render_taskbar_items(taskbar_items = [])
    taskbar_icon_class = "taskbar-icon"
    taskbar_label_class = "taskbar-label"

    concat(taskbar_menu_button("menu-icon-right", "Open sidebar navigation", "task-bar/arrow-right.svg"))
    concat(taskbar_menu_button("menu-icon-left", "Close sidebar navigation", "task-bar/arrow-left.svg"))

    content_tag(:div, id: "taskbar-left", class: "collapsed") do
      rendered_links = []

      (default_taskbar_items + taskbar_items).each do |item|
        link_key = item[:link].to_s.presence || item[:label].to_s
        next if rendered_links.include?(link_key)

        rendered_links << link_key
        concat(taskbar_icon_item(
          image_path: item[:image_path],
          alt_text: item[:alt_text],
          label: item[:label],
          link: item[:link],
          icon_class: taskbar_icon_class,
          label_class: taskbar_label_class,
          target: item[:target],
          active: taskbar_link_active?(item[:link])
        ))
      end

      concat(taskbar_icon_item(
        image_path: "task-bar/timeline.svg",
        alt_text: "Timeline Icon",
        label: "Timeline",
        link: timeline_path,
        icon_class: taskbar_icon_class,
        label_class: taskbar_label_class,
        active: taskbar_link_active?(timeline_path)
      ))

      concat(taskbar_icon_item(
        image_path: "task-bar/terminal-prompt.svg",
        alt_text: "Terminal Icon",
        label: "Terminal navigation",
        icon_class: taskbar_icon_class,
        label_class: taskbar_label_class,
        id: "terminal-taskbar-button"
      ))
    end
  end

  private

  def taskbar_menu_button(id, label, image_path)
    content_tag(:button, type: "button", class: "menu-icon", id: id, aria: { label: label }) do
      image_tag(image_path, alt: "", class: "menu-icon-image", aria: { hidden: true })
    end
  end

  def taskbar_link_active?(link)
    path = link.to_s.split(/[?#]/).first
    return false unless path.start_with?("/")
    return request.path == root_path if path == root_path

    request.path == path || request.path.start_with?("#{path}/")
  end
end
