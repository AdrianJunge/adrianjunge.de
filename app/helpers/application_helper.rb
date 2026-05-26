module ApplicationHelper
  def parent_path
    current_path = request.path
    return nil if current_path == "/" || current_path == ""
    current_path = current_path.chomp("/")
    parent = File.dirname(current_path)
    parent = "/" if parent == "."
    parent
  end
end
