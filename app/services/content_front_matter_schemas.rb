class ContentFrontMatterSchemas
  TEXT = { "type" => "string", "pattern" => "\\S" }.freeze
  NULLABLE_TEXT = { "type" => [ "string", "null" ] }.freeze
  BOOLEAN = { "type" => "boolean" }.freeze
  DATE = { "oneOf" => [ ContentJsonSchemas::DATE, { "type" => "integer", "minimum" => 1000, "maximum" => 9999 } ] }.freeze

  AUTHOR = {
    "oneOf" => [
      TEXT,
      {
        "type" => "object", "required" => [ "name" ], "additionalProperties" => false,
        "properties" => {
          "name" => TEXT, "url" => TEXT,
          "urls" => { "type" => "array", "items" => TEXT }
        }
      }
    ]
  }.freeze
  CHALLENGE_AUTHOR = {
    "oneOf" => [
      AUTHOR,
      # Older writeups explicitly record an unknown challenge author this way.
      {
        "type" => "object", "required" => [ "name" ], "additionalProperties" => false,
        "properties" => { "name" => { "type" => "null" }, "url" => { "type" => "null" } }
      },
      {
        "type" => "object", "required" => %w[name url], "additionalProperties" => false,
        "properties" => { "name" => TEXT, "url" => { "type" => "null" } }
      }
    ]
  }.freeze

  def self.named_value(keys)
    {
      "type" => "object", "additionalProperties" => false,
      "properties" => keys.to_h { |key| [ key, TEXT ] },
      "anyOf" => keys.map { |key| { "required" => [ key ] } }
    }
  end

  HINT = { "oneOf" => [ TEXT, named_value(%w[text hint value]) ] }.freeze
  HINTS = { "oneOf" => [ HINT, { "type" => "array", "items" => HINT } ] }.freeze
  DIFFICULTY = { "oneOf" => [ TEXT, named_value(%w[label name value difficulty]) ] }.freeze
  AUTHORED_CHALLENGE = {
    "oneOf" => [
      BOOLEAN, TEXT,
      {
        "type" => "object", "additionalProperties" => false,
        "properties" => %w[label title event category event_url category_url url summary description id].to_h { |key| [ key, TEXT ] }
          .merge("date" => DATE, "published" => DATE)
      }
    ]
  }.freeze
  WINNER = {
    "oneOf" => [
      TEXT,
      {
        "type" => "object", "additionalProperties" => false,
        "properties" => %w[label title proof_url proof url].to_h { |key| [ key, TEXT ] }
      }
    ]
  }.freeze
  OPTIONAL_PROPERTIES = {
    "difficulty" => DIFFICULTY, "challenge_difficulty" => DIFFICULTY, "challenge-difficulty" => DIFFICULTY,
    "hint" => HINTS, "hints" => HINTS,
    "authored_challenge" => AUTHORED_CHALLENGE, "authored-challenge" => AUTHORED_CHALLENGE, "challenge_author" => AUTHORED_CHALLENGE,
    "writeup_winner" => WINNER, "writeup-winner" => WINNER, "winner" => WINNER
  }.freeze
  PROPERTIES = OPTIONAL_PROPERTIES.merge(
    "title" => TEXT, "description" => TEXT, "reader_summary" => TEXT, "published" => DATE, "updated" => DATE, "modified" => DATE,
    "logo" => TEXT, "icon" => TEXT, "category" => TEXT, "timeline_group" => TEXT,
    "categories" => { "type" => "array", "items" => TEXT },
    "author" => TEXT, "author_url" => NULLABLE_TEXT,
    "author_urls" => { "type" => "object", "additionalProperties" => NULLABLE_TEXT },
    "author_links" => { "type" => "object", "additionalProperties" => NULLABLE_TEXT },
    "authors" => { "type" => "array", "items" => CHALLENGE_AUTHOR },
    "article_authors" => { "oneOf" => [ AUTHOR, { "type" => "array", "items" => AUTHOR } ] },
    "hidden" => BOOLEAN, "draft" => BOOLEAN, "wip" => BOOLEAN, "has_math" => BOOLEAN,
    "optional" => { "type" => "object", "properties" => OPTIONAL_PROPERTIES }
  ).freeze

  def self.errors_for(metadata, about: false, required: true)
    schema = {
      "type" => "object",
      "properties" => PROPERTIES
    }
    schema["required"] = about ? %w[title description] : %w[title description published] if required
    ContentJsonSchemas.validation_errors(schema, metadata) + ContentJsonSchemas.metadata_errors(metadata) + author_url_errors(metadata)
  end

  def self.author_url_errors(metadata, pointer = "")
    case metadata
    when Array
      metadata.each_with_index.flat_map { |entry, index| author_url_errors(entry, "#{pointer}/#{index}") }
    when Hash
      metadata.flat_map do |key, value|
        location = "#{pointer}/#{ContentJsonSchemas.pointer_key(key)}"
        urls = if %w[author_urls author_links].include?(key) && value.is_a?(Hash)
          value.map { |name, url| [ "#{location}/#{ContentJsonSchemas.pointer_key(name)}", url ] }
        elsif key == "urls" && value.is_a?(Array)
          value.each_with_index.map { |url, index| [ "#{location}/#{index}", url ] }
        else
          []
        end
        urls.filter_map do |url_pointer, url|
          next if url.blank? || ContentUrl.valid?(url)

          { "data_pointer" => url_pointer, "type" => "unsupported URL (use a local path, fragment, or HTTP(S) URL)" }
        end + author_url_errors(value, location)
      end
    else
      []
    end
  end
end
