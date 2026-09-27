# The card variants own layout; callers supply content and interaction settings.
# Keep CSS and wrapper choices here so the shared template only renders markup.
class ContentCardPresenter
  POST_STYLE = {
    class_name: "blog-post-card", hitbox_class: "blog-post-card-hitbox",
    content_class: "blog-post-card-content", body_class: "blog-post-card-details",
    title_tag: :h3, title_class: "blog-post-title", description_tag: :p,
    description_class: "blog-post-description", date_class: "blog-post-date",
    date_text_class: "blog-post-date-text", reading_time_class: "blog-post-reading-time",
    meta_item_class: "blog-post-reading-time", tags_outer_class: "blog-post-meta",
    tags_class: "blog-post-meta-row", authors_class: "blog-post-authors",
    media_wrapper_class: "blog-post-card-logo"
  }.freeze

  VARIANTS = {
    post: POST_STYLE,
    writeup: POST_STYLE.merge(
      class_name: "blog-post-card writeup-post-card",
      media_wrapper_class: "blog-post-card-logo writeup-post-card-logo"
    ).freeze,
    event: POST_STYLE.merge(
      class_name: "blog-post-card ctf-card", body_class: "blog-post-card-details ctf-details",
      text_class: "ctf-text", title_class: "ctf-name font-bold", description_class: "ctf-description",
      date_class: "blog-post-date ctf-event-summary", date_text_class: "blog-post-date-text ctf-writeup-count-text",
      reading_time_class: "blog-post-reading-time ctf-total-reading-time"
    ).freeze,
    timeline: {
      class_name: "timeline-content timeline-content-with-media", hitbox_class: "timeline-card-hitbox",
      content_class: "blog-post-card-content timeline-card-content", body_class: "blog-post-card-details timeline-card-details",
      title_tag: :span, title_class: "timeline-title", description_tag: :span,
      description_class: "timeline-meta", date_class: "content-card-date",
      date_text_class: "content-card-date-text", reading_time_class: "timeline-reading-time",
      meta_item_class: "content-card-meta-item", tags_class: "timeline-tags",
      authors_class: "content-card-authors", media_wrapper_class: "blog-post-card-logo timeline-card-logo"
    }.freeze
  }.freeze

  CONTENT_KEYS = %i[
    id title url description date date_datetime reading_time tags meta_items authors authors_label
    source media media_html section_link filter_scope interactive_tags data aria aria_label
  ].freeze

  attr_reader :variant

  def initialize(variant:, **content)
    @variant = variant.to_sym
    style = VARIANTS.fetch(@variant)
    content.assert_valid_keys(*CONTENT_KEYS)
    @attributes = style.merge(content)
    @attributes[:url] = content[:url].presence
    @attributes[:tags] = Array(content[:tags]).compact
    @attributes[:authors] = Array(content[:authors]).compact
    @attributes[:interactive_tags] = content.fetch(:interactive_tags, true)
    @attributes[:aria_label] = content[:aria_label].presence || content[:title].presence || "Open item"
    @attributes[:source_class] = "content-card-source"
    @attributes[:media] = { wrapper_class: style[:media_wrapper_class] }.merge(content.fetch(:media, {}).symbolize_keys)
    @attributes[:meta_items] = normalize_meta_items(content[:meta_items])
    @attributes[:section_link] = normalize_section_link(content[:section_link])
    @attributes[:hitbox_class] = [ "content-card-hitbox", style[:hitbox_class] ].join(" ")
    @attributes[:root_attributes] = {
      class: [ "content-card", "ui-card-surface", ("ui-hover-lift" if self[:url]),
               ("content-card-with-section-link" if self[:section_link]), style[:class_name] ].compact.join(" "),
      id: content[:id].presence, data: content[:data], aria: content[:aria]
    }.compact
  end

  def [](key)
    @attributes[key]
  end

  private

  def normalize_meta_items(items)
    Array(items).filter_map do |item|
      item = item.is_a?(Hash) ? item.symbolize_keys : { label: item }
      label = item[:label].to_s.presence
      next unless label

      { label: label, class_name: [ self[:meta_item_class], item[:class_name] ].compact.join(" ") }
    end
  end

  def normalize_section_link(link)
    return unless link

    link = link.symbolize_keys
    return unless link[:url].present? && link[:icon].present?

    kind = link[:kind].to_s.parameterize.presence
    label = link[:label].presence || "Browse related posts"
    link.merge(
      label: label, title: link[:title].presence || label,
      class_name: [ "content-card-section-link", ("content-card-section-link-#{kind}" if kind), link[:class_name] ].compact.join(" "),
      data: kind ? { content_section: kind } : nil
    )
  end
end
