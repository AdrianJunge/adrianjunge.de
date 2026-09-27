class CtfEventCardPresenter < ContentCardPresenter
  def initialize(name:, event:, filters:, reading_time:)
    tags = Array(filters[:tags])
    count = filters[:writeup_count].to_i
    count_label = "#{count} #{count == 1 ? "writeup" : "writeups"}"
    card_tags = tags.map do |tag|
      {
        label: tag,
        winner: tag == WriteupWinner::FILTER_LABEL,
        authored: tag == AuthoredChallenge::FILTER_LABEL,
        difficulty_filter: WriteupDifficulty.filter_label?(tag),
        difficulty_key: tag,
        category: tag != WriteupWinner::FILTER_LABEL && tag != AuthoredChallenge::FILTER_LABEL && !WriteupDifficulty.filter_label?(tag),
        category_key: tag
      }
    end

    super(
      variant: :event, url: event["writeups"], title: name, description: event["description"],
      media: { image: event["logo"], alt: "#{name} Logo", image_class: "blog-logo" },
      filter_scope: "ctfs", tags: card_tags, date: count_label, reading_time: reading_time,
      data: {
        expandable: false, filter_card: "ctfs",
        filter_text: [ name, event["description"], event["directory"], count_label, tags ].flatten.compact.join(" "),
        filter_tags: tags.join("|"), filter_years: Array(filters[:years]).join("|")
      },
      aria_label: "Open #{name} writeups"
    )
  end
end
