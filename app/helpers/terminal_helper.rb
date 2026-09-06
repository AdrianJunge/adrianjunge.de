module TerminalHelper
  XTERM_CSS_ASSET = "terminal.css".freeze

  def render_terminal(paths, minimized)
    paths = normalized_terminal_paths(paths)
    terminal_class = "subpixel-antialiased font-mono bg-black"
    terminal_class += " terminal-minimized" if minimized

    content_tag(:div, id: "terminal-container", data: { terminal_text: paths.to_json, terminal_css: asset_path(XTERM_CSS_ASSET) },
      class: terminal_class, hidden: minimized, inert: minimized, role: "region", aria: { label: "Site terminal" }) do
      safe_join([
        content_tag(:div, class: "terminal-header") do
          safe_join([
            content_tag(:button, type: "button", id: "minimize-terminal", class: "terminal-button", aria: { label: "Minimize terminal" }) do
              image_tag("terminal/minimize-icon.svg", alt: "", class: "button-icon", aria: { hidden: true })
            end,
            content_tag(:button, type: "button", id: "maximize-terminal", class: "terminal-button", aria: { label: "Maximize terminal" }) do
              image_tag("terminal/maximize-icon.svg", alt: "", class: "button-icon", aria: { hidden: true })
            end,
            content_tag(:button, type: "button", id: "close-terminal", class: "terminal-button", aria: { label: "Close terminal" }) do
              image_tag("terminal/close-icon.svg", alt: "", class: "button-icon", aria: { hidden: true })
            end
          ])
        end,

        content_tag(:div, "", id: "terminal-link-tooltip")
      ])
    end
  end

  def normalized_terminal_paths(paths)
    ([ terminal_path("~", root_path, "home"), terminal_path(".", terminal_current_path, "current"), terminal_path("..", terminal_parent_path, "parent") ] +
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

  def terminal_current_path
    request.fullpath.presence || root_path
  end

  def terminal_parent_path
    path = request.path.to_s.chomp("/")
    return root_path if path.blank? || path == root_path

    parent = File.dirname(path)
    parent == "." ? root_path : parent
  end
end
