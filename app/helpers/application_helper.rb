module ApplicationHelper
  def timeline_filter_path(tag: nil, tags: nil, q: nil, year: nil)
    tag_values = Array(tags.presence || tag).compact.map(&:to_s).map(&:strip).reject(&:blank?)
    params = {}
    params[:q] = q.to_s.strip if q.present?
    params[:year] = year.to_s.strip if year.present?
    canonical_tags = tag_values.map { |tag_value| ContentTagTaxonomy.canonical_label(tag_value) }
    params[:tag] = canonical_tags.first if canonical_tags.one?
    params[:tags] = canonical_tags.join("|") if canonical_tags.many?

    timeline_path(params)
  end

  def parent_path
    current_path = request.path
    return nil if current_path == "/" || current_path == ""
    current_path = current_path.chomp("/")
    parent = File.dirname(current_path)
    parent = "/" if parent == "."
    parent
  end
end
