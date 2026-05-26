module ApplicationHelper
  def parent_path
    current_path = request.path
    return nil if current_path == "/" || current_path == ""
    current_path = current_path.chomp("/")
    parent = File.dirname(current_path)
    parent = "/" if parent == "."
    parent
  end

  def feed_actions_for(scope, feed_url:, atom_url:, label:)
    scope = scope.to_s

    [
      {
        href: feed_url,
        class: "#{scope}-rss-feed ui-hover-lift",
        icon_path: "task-bar/rss.svg",
        icon_class: "#{scope}-rss-icon",
        label: "#{label} RSS feed",
        alt: "RSS Feed Icon"
      },
      {
        href: atom_url,
        class: "#{scope}-atom-feed ui-hover-lift",
        icon_path: "task-bar/atom.svg",
        icon_class: "#{scope}-atom-icon",
        label: "#{label} Atom feed",
        alt: "Atom Feed Icon"
      }
    ]
  end
end
