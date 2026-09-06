class PostsController < ApplicationController
  def timeline
    @timeline_items = ContentIndex.new(repository: content_repository).all_items
    @timeline = @timeline_items.group_by { |item| item[:published].year }.sort.reverse
    @filter_years = @timeline_items.map { |item| item[:published].year }.uniq.sort.reverse
    @filter_ctf_labels = filter_ctf_labels
    @filter_repository_labels = filter_repository_labels
    @filter_tags = sorted_filter_values(
      @timeline_items.flat_map { |item| item[:tags] },
      ctf_labels: @filter_ctf_labels,
      repository_labels: @filter_repository_labels
    )
    @filter_tag_groups = filter_tag_groups(
      @filter_tags,
      content_labels: CONTENT_FILTER_KIND_LABELS,
      ctf_labels: @filter_ctf_labels,
      repository_labels: @filter_repository_labels,
      topic_label: "Topics, projects, and sources"
    )
    @initial_query = params[:q].to_s
  end
end
