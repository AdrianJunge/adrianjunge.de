class ContentFiltersPresenter
  COMMON_TAGS = [ "Blog post", "CTF writeup", "CVE", "Bug bounty", "Certificate", "Talk" ].freeze

  attr_reader :scope, :years, :total, :search_id, :clear_id, :search_value, :placeholder, :year_label,
              :common_group, :additional_groups, :aliases

  def initialize(scope:, years: [], tags: [], tag_groups: [], total: 0, search_id: nil, clear_id: nil,
                 search_value: nil, placeholder: "Search...", year_label: "Year")
    @scope = scope
    @years = clean_values(years).uniq.sort.reverse
    @total = total.to_i
    @search_id = search_id || "#{scope}-search-input"
    @clear_id = clear_id || "#{scope}-search-clear"
    @search_value = search_value
    @placeholder = placeholder
    @year_label = year_label
    @aliases = ContentTagTaxonomy::LABEL_ALIASES

    groups = normalize_groups(tag_groups)
    groups = [ { label: "", tags: sorted_tags(tags) } ] if groups.empty? && clean_values(tags).any?
    first_group = groups.find { |group| group[:label].casecmp?("Content type") } || groups.first
    @additional_groups = []
    return unless first_group

    common_tags = COMMON_TAGS.select { |tag| first_group[:tags].include?(tag) }
    common_tags = first_group[:tags].first(6) if common_tags.empty?
    @common_group = first_group.merge(label: "Common filters", tags: common_tags)
    @additional_groups = [
      first_group.merge(tags: first_group[:tags] - common_tags),
      *groups.reject { |group| group.equal?(first_group) }
    ].reject { |group| group[:tags].empty? }
  end

  private

  def clean_values(values)
    Array(values).compact.map(&:to_s).reject(&:blank?)
  end

  def sorted_tags(tags)
    clean_values(tags).uniq { |tag| tag.downcase }.sort_by { |tag| ContentTagTaxonomy.sort_key(tag) }
  end

  def normalize_groups(groups)
    Array(groups).filter_map do |group|
      next unless group.is_a?(Hash)

      group = group.symbolize_keys
      tags = sorted_tags(group[:tags])
      next if tags.empty?

      { label: group[:label].to_s, sort: group[:sort].to_s, tags: tags }
    end
  end
end
