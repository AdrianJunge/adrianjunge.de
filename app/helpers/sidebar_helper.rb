module SidebarHelper
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

  def render_taskbar_items(taskbar_items)
    base_class = "bg-tertiary"
    taskbar_icon_class = base_class + " taskbar-icon"
    taskbar_label_class = "taskbar-label"

    concat(content_tag(:div, class: "taskbar-item") do
      image_tag("task-bar/arrow-right.svg", alt: "Menu Icon", class: base_class + " menu-icon", id: "menu-icon-right")
    end)
    concat(content_tag(:div, class: "taskbar-item") do
      image_tag("task-bar/arrow-left.svg", alt: "Menu Icon", class: base_class + " menu-icon", id: "menu-icon-left")
    end)

    content_tag(:div, id: "taskbar-left", class: "bg-primary collapsed") do
      concat(taskbar_icon_item(
        image_path: "task-bar/home.svg",
        alt_text: "Home Icon",
        label: "Home",
        link: root_path,
        icon_class: taskbar_icon_class,
        label_class: taskbar_label_class
        ))
      taskbar_items.each do |item|
        concat(taskbar_icon_item(
          image_path: item[:image_path],
          alt_text: item[:alt_text],
          label: item[:label],
          link: item[:link],
          icon_class: taskbar_icon_class,
          label_class: taskbar_label_class
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
