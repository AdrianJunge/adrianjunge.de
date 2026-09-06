require "json_schemer"

class ContentJsonSchemas
  class ValidationError < StandardError
    attr_reader :path, :errors

    def initialize(path, errors)
      @path = path
      @errors = errors
      super("Content JSON schema validation failed for #{path}: #{format_errors(errors)}")
    end

    private

    def format_errors(errors)
      errors.map { |error| "#{error["data_pointer"]}: #{error["type"]}" }.join(", ")
    end
  end

  DATE_PATTERN = "^(?:\\d{4}|\\d{4}\\s*[-–—]\\s*\\d{4}|\\d{4}-\\d{2}-\\d{2}(?:[T ]\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?(?:Z|[+-]\\d{2}:?\\d{2}))?)$"

  STRING = { "type" => "string" }.freeze
  DATE = { "type" => "string", "pattern" => DATE_PATTERN }.freeze

  LINK = {
    "type" => "object",
    "required" => %w[label url],
    "additionalProperties" => false,
    "properties" => {
      "label" => STRING,
      "url" => STRING
    }
  }.freeze

  TAG = {
    "oneOf" => [
      STRING,
      {
        "type" => "object",
        "required" => %w[label],
        "additionalProperties" => false,
        "properties" => {
          "label" => STRING,
          "url" => STRING
        }
      }
    ]
  }.freeze

  ABOUT_TIMELINE_ITEM = {
    "type" => "object",
    "additionalProperties" => false,
    "properties" => {
      "id" => STRING,
      "title" => STRING,
      "date" => DATE,
      "summary" => STRING,
      "url" => STRING,
      "timeline_group" => STRING,
      "hidden" => { "type" => "boolean" }
    }
  }.freeze

  ABOUT_CARD = {
    "type" => "object",
    "required" => %w[id title],
    "additionalProperties" => false,
    "properties" => {
      "id" => STRING,
      "title" => STRING,
      "subtitle" => STRING,
      "icon" => STRING,
      "url" => STRING,
      "summary" => STRING,
      "timeline_group" => STRING,
      "tags" => { "type" => "array", "items" => TAG },
      "links" => { "type" => "array", "items" => LINK },
      "timeline" => { "type" => "array", "items" => ABOUT_TIMELINE_ITEM },
      "hidden" => { "type" => "boolean" },
      "draft" => { "type" => "boolean" }
    }
  }.freeze

  BLOG_ENTRY = {
    "type" => "object",
    "required" => %w[terminal_path logo title category description],
    "additionalProperties" => false,
    "properties" => {
      "terminal_path" => STRING,
      "logo" => STRING,
      "title" => STRING,
      "category" => STRING,
      "description" => STRING,
      "timeline_group" => STRING,
      "hidden" => { "type" => "boolean" }
    }
  }.freeze

  CTF_ENTRY = {
    "type" => "object",
    "required" => %w[terminal_path logo writeups website description],
    "additionalProperties" => false,
    "properties" => {
      "terminal_path" => STRING,
      "logo" => STRING,
      "writeups" => STRING,
      "website" => STRING,
      "description" => STRING,
      "hidden" => { "type" => "boolean" }
    }
  }.freeze

  ARRAY_SCHEMAS = {
    ContentConfiguration::ABOUTME_CVES_PATH.to_s => ABOUT_CARD,
    ContentConfiguration::ABOUTME_BUG_BOUNTIES_PATH.to_s => ABOUT_CARD,
    ContentConfiguration::ABOUTME_CERTIFICATES_PATH.to_s => ABOUT_CARD,
    ContentConfiguration::ABOUTME_CHALLENGES_PATH.to_s => ABOUT_CARD,
    ContentConfiguration::ABOUTME_TALKS_PATH.to_s => ABOUT_CARD,
    ContentConfiguration::ABOUTME_ACHIEVEMENTS_PATH.to_s => ABOUT_CARD
  }.freeze

  OBJECT_SCHEMAS = {
    ContentConfiguration::BLOG_INFO_PATH.to_s => BLOG_ENTRY,
    ContentConfiguration::CTF_INFO_PATH.to_s => CTF_ENTRY
  }.freeze

  def self.validate!(path, data)
    errors = errors_for(path, data)
    raise ValidationError.new(path, errors) if errors.any?

    true
  end

  def self.errors_for(path, data)
    schema = schema_for(path)
    return [] unless schema

    JSONSchemer.schema(schema).validate(data).to_a + metadata_errors(data)
  end

  def self.metadata_errors(data, pointer = "")
    case data
    when Array
      data.each_with_index.flat_map { |item, index| metadata_errors(item, "#{pointer}/#{index}") }
    when Hash
      data.flat_map do |key, value|
        item_pointer = "#{pointer}/#{key}"
        error = if %w[date published updated modified].include?(key) && value.present? && ContentDate.parse(value).nil?
          "unsupported date"
        elsif %w[url website authorlink author_link event_url proof_url].include?(key) && value.present? && !ContentUrl.valid?(value)
          "unsupported URL (use a local path, fragment, or HTTP(S) URL)"
        elsif %w[hidden draft wip has_math].include?(key) && ![ true, false ].include?(value)
          "must be a boolean"
        end

        (error ? [ { "data_pointer" => item_pointer, "type" => error } ] : []) + metadata_errors(value, item_pointer)
      end
    else
      []
    end
  end

  def self.schema_for(path)
    path = path.to_s

    if ARRAY_SCHEMAS.key?(path)
      array_schema(ARRAY_SCHEMAS.fetch(path))
    elsif OBJECT_SCHEMAS.key?(path)
      object_schema(OBJECT_SCHEMAS.fetch(path))
    end
  end

  def self.registered_paths
    (ARRAY_SCHEMAS.keys + OBJECT_SCHEMAS.keys).sort
  end

  def self.array_schema(item_schema)
    {
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "type" => "array",
      "items" => item_schema
    }
  end

  def self.object_schema(value_schema)
    {
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "type" => "object",
      "additionalProperties" => value_schema
    }
  end

  private_class_method :array_schema, :object_schema
end
