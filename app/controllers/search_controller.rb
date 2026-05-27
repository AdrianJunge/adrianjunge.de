class SearchController < ApplicationController
  def index
    @search_items = ContentIndex.new.all_items
    @filter_years = @search_items.map { |item| item[:published].year }.uniq.sort.reverse
    @filter_tags = sorted_filter_values(@search_items.flat_map { |item| item[:tags] })
    @filter_tag_groups = filter_tag_groups(
      @filter_tags,
      content_labels: CONTENT_FILTER_KIND_LABELS,
      topic_label: "Topics, projects, and sources"
    )
    @initial_query = params[:q].to_s
  end
end
