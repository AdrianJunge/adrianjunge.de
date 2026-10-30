class TimelinePagePresenter
  def initialize(repository:, order: nil, query: nil, view: nil)
    @repository = repository
    @order = order == "oldest" ? "oldest" : "newest"
    @query = query.to_s
    @view = view == "posts" ? "posts" : "all"
  end

  def assigns
    items = ContentIndex.new(repository: @repository).all_items
    positions = items.each_with_index.to_h { |item, index| [ item[:id], index ] }
    direction = @order == "oldest" ? 1 : -1
    ordered_items = items.sort_by { |item| [ direction * item[:published].to_i, positions.fetch(item[:id]) ] }
    ctf_labels = @repository.ctf_metadata.keys + @repository.about_entries(ContentConfiguration::ABOUTME_ACHIEVEMENTS_PATH).filter_map do |entry|
      entry["title"] if entry["category"].to_s.casecmp?("CTF Competition")
    end
    repository_labels = @repository.about_entries(ContentConfiguration::ABOUTME_CVES_PATH).filter_map { |entry| entry["title"] }
    tags = ContentTagTaxonomy.canonical_values(items.flat_map { |item| item[:tags] }).sort_by do |value|
      ContentTagTaxonomy.sort_key(value, ctf_labels: ctf_labels, repository_labels: repository_labels)
    end

    {
      timeline_items: ordered_items,
      timeline: ordered_items.group_by { |item| item[:published].year }.to_a,
      timeline_positions: positions,
      timeline_order: @order,
      timeline_view: @view,
      timeline_visible_count: ordered_items.count { |item| @view != "posts" || %w[blog writeup].include?(item[:kind]) },
      filter_years: items.flat_map { |item| item[:filter_years].presence || [ item[:published].year ] }.uniq.sort.reverse,
      filter_tags: tags,
      filter_tag_groups: ContentTagTaxonomy.filter_groups(tags,
        ctf_labels: ctf_labels, repository_labels: repository_labels, topic_label: "Topics, projects, and sources"),
      initial_query: @query
    }
  end
end
