module TerminalHelper
  XTERM_CSS_CDN_URL = "https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css".freeze

  def render_terminal(paths, minimized)
    paths = normalized_terminal_paths(paths)
    terminal_class = "subpixel-antialiased font-mono bg-black"
    terminal_class += " terminal-minimized" if minimized

    content_tag(:div, id: "terminal-container", data: { terminal_text: paths.to_json }, class: terminal_class) do
      safe_join([
        content_tag(:div, class: "terminal-header") do
          safe_join([
            content_tag(:div, id: "minimize-terminal", class: "terminal-button") do
              image_tag("terminal/minimize-icon.svg", alt: "Minimize", class: "button-icon")
            end,
            content_tag(:div, id: "maximize-terminal", class: "terminal-button") do
              image_tag("terminal/maximize-icon.svg", alt: "Maximize", class: "button-icon")
            end,
            content_tag(:div, id: "close-terminal", class: "terminal-button") do
              image_tag("terminal/close-icon.svg", alt: "Close", class: "button-icon")
            end
          ])
        end,

        content_tag(:div, "", id: "terminal-link-tooltip")
      ])
    end
  end

  def normalized_terminal_paths(paths)
    ([ terminal_path("~", root_path, "home"), terminal_path(".", nil, "current"), terminal_path("..", nil, "parent") ] +
      Array(paths).map { |path| normalize_terminal_path(path) })
      .uniq { |path| path[:label] }
  end

  def terminal_path(label, url = nil, description = nil)
    { label: label.to_s, url: url, description: description }.compact
  end

  def normalize_terminal_path(path)
    return terminal_path(path) unless path.is_a?(Hash)

    label = path[:label] || path["label"] || path[:path] || path["path"]
    url = path[:url] || path["url"]
    description = path[:description] || path["description"]
    terminal_path(label, url, description)
  end
end
