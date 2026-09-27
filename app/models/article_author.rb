module ArticleAuthor
  module_function

  # Article attribution is separate from the authors of a CTF challenge.
  def normalize(authors)
    entries = authors.is_a?(Hash) ? [ authors ] : Array(authors)
    normalized = entries.filter_map do |entry|
      values = entry.is_a?(Hash) ? entry.stringify_keys : { "name" => entry }
      name = ActionController::Base.helpers.strip_tags(values["name"].to_s).squish
      next if name.blank?

      urls = values["url"].presence || values["urls"]
      url = Array(urls).filter_map { |value| normalized_url(value) }.first
      { name: name, url: url }.compact
    end
    normalized = normalized.uniq { |entry| entry[:name].downcase }
    normalized.presence || [ SiteProfile.author ]
  end

  def normalized_url(value)
    return unless ContentUrl.valid?(value)

    SiteProfile.absolute_url(value)
  end
end
