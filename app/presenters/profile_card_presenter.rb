# Findings have disclosure sections and timelines rather than post metadata.
class ProfileCardPresenter
  def initialize(card)
    card = card.symbolize_keys
    @attributes = card.dup
    @attributes[:tags] = Array(card[:tags]).compact.partition { |tag| tag[:url].blank? }.flatten
    %i[body_blocks timeline children].each { |key| @attributes[key] = Array(card[key]).compact }
    @attributes[:collapsible] = card[:collapsible] && %i[body_blocks timeline children].any? { |key| self[key].any? }
    @attributes[:card_url] = self[:collapsible] ? nil : card[:card_url].presence
    @attributes[:reading_time] = card[:reading_time].to_s.presence
    @attributes[:icon] = card[:icon].to_s.presence
    @attributes[:class_name] = [
      "profile-card", "aboutme-card", "ui-card-surface", ("ui-hover-lift" if self[:card_url]), card[:class_name],
      ("aboutme-card-static" unless self[:collapsible]), ("aboutme-card-linked" if self[:card_url]),
      ("aboutme-card-nested" if card[:nested])
    ].compact.join(" ")
    {
      main_class: "aboutme-card-main", title_class: "aboutme-card-title",
      tags_class: "aboutme-card-tags", description_class: "aboutme-card-summary"
    }.each do |key, base|
      @attributes[key] = [ base, card[key] ].compact.join(" ")
    end
    @attributes[:heading_tag] = card[:heading_tag].presence || (card[:nested] ? :h4 : :h3)
  end

  def [](key)
    @attributes[key]
  end
end
