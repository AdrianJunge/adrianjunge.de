module SidebarHelper
  def default_taskbar_items
    [
      { image_path: "task-bar/home.svg", alt_text: "Home Icon", label: "Home", link: root_path },
      { image_path: "task-bar/about.svg", alt_text: "About Icon", label: "About me", link: about_path },
      { image_path: "task-bar/flag.svg", alt_text: "CTF Icon", label: "CTF", link: ctf_path },
      { image_path: "task-bar/blog.svg", alt_text: "Blog Icon", label: "Blog", link: blog_path }
    ]
  end

  def taskbar_icon_item(image_path:, alt_text:, label:, link: nil, icon_class:, label_class:, id: nil, target: nil)
    content_tag :div, class: "taskbar-item" do
      if link
        concat(
          link_to(link, target: target, class: "taskbar-link", id: id) do
            image_tag(image_path, alt: alt_text, class: icon_class) +
            content_tag(:span, label, class: label_class)
          end
        )
      else
        content_tag(:div, class: "taskbar-button-container", id: id) do
          concat(image_tag(image_path, alt: alt_text, class: icon_class))
          concat(content_tag(:span, label, class: label_class))
        end
      end
    end
  end

  def render_taskbar_items(taskbar_items = [])
    base_class = "bg-tertiary"
    taskbar_icon_class = base_class + " taskbar-icon"
    taskbar_label_class = "taskbar-label"

    concat(image_tag("task-bar/arrow-right.svg", alt: "Menu Icon", class: base_class + " menu-icon", id: "menu-icon-right"))
    concat(image_tag("task-bar/arrow-left.svg", alt: "Menu Icon", class: base_class + " menu-icon", id: "menu-icon-left"))

    content_tag(:div, id: "taskbar-left", class: "bg-primary collapsed") do
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
          target: item[:target]
        ))
      end

      concat(taskbar_icon_item(
        image_path: "task-bar/post.svg",
        alt_text: "Posts Icon",
        label: "Posts",
        link: posts_path,
        icon_class: taskbar_icon_class,
        label_class: taskbar_label_class,
      ))

      concat(taskbar_icon_item(
        image_path: "task-bar/terminal.svg",
        alt_text: "Terminal Icon",
        label: "Terminal navigation",
        icon_class: taskbar_icon_class,
        label_class: taskbar_label_class,
        id: "terminal-taskbar-button"
      ))
    end
  end
end
