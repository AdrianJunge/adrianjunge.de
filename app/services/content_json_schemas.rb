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

  DATE_PATTERN = "^(?:\\d{4}|\\d{4}-\\d{2}-\\d{2})$"
  OPTIONAL_DATE_PATTERN = "^(?:|\\d{4}|\\d{4}-\\d{2}-\\d{2})$"

  STRING = { "type" => "string" }.freeze
  OPTIONAL_DATE = { "type" => "string", "pattern" => OPTIONAL_DATE_PATTERN }.freeze
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

  FINDING = {
    "type" => "object",
    "required" => %w[
      id project project_url title title_url cve_id severity short_summary summary
      timeline references
    ],
    "additionalProperties" => false,
    "properties" => {
      "id" => STRING,
      "project" => STRING,
      "project_url" => STRING,
      "icon" => STRING,
      "title" => STRING,
      "title_url" => STRING,
      "card_url" => STRING,
      "timeline_group" => STRING,
      "cve_id" => STRING,
      "cwe_id" => STRING,
      "severity" => STRING,
      "short_summary" => STRING,
      "summary" => STRING,
      "hidden" => { "type" => "boolean" },
      "timeline" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "required" => %w[date event],
          "additionalProperties" => false,
          "properties" => {
            "date" => OPTIONAL_DATE,
            "event" => STRING
          }
        }
      },
      "references" => { "type" => "array", "items" => LINK }
    }
  }.freeze

  MILESTONE = {
    "type" => "object",
    "required" => %w[id title title_url category date summary links],
    "additionalProperties" => false,
    "properties" => {
      "id" => STRING,
      "title" => STRING,
      "title_url" => STRING,
      "icon" => STRING,
      "card_url" => STRING,
      "timeline_group" => STRING,
      "category" => STRING,
      "category_url" => STRING,
      "date" => DATE,
      "summary" => STRING,
      "hidden" => { "type" => "boolean" },
      "links" => { "type" => "array", "items" => LINK }
    }
  }.freeze

  ACHIEVEMENT = {
    "type" => "object",
    "required" => %w[id title title_url category links events],
    "additionalProperties" => false,
    "properties" => {
      "id" => STRING,
      "title" => STRING,
      "title_url" => STRING,
      "icon" => STRING,
      "card_url" => STRING,
      "timeline_group" => STRING,
      "category" => STRING,
      "category_url" => STRING,
      "summary" => STRING,
      "hidden" => { "type" => "boolean" },
      "links" => { "type" => "array", "items" => LINK },
      "events" => {
        "type" => "array",
        "minItems" => 1,
        "items" => {
          "type" => "object",
          "required" => %w[id title date],
          "additionalProperties" => false,
          "properties" => {
            "id" => STRING,
            "title" => STRING,
            "date" => DATE,
            "icon" => STRING,
            "summary" => STRING,
            "url" => STRING,
            "card_url" => STRING,
            "timeline_group" => STRING,
            "hidden" => { "type" => "boolean" }
          }
        }
      }
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
    ApplicationController::ABOUTME_CVES_PATH.to_s => FINDING,
    ApplicationController::ABOUTME_BUG_BOUNTIES_PATH.to_s => FINDING,
    ApplicationController::ABOUTME_CERTIFICATES_PATH.to_s => MILESTONE,
    ApplicationController::ABOUTME_CHALLENGES_PATH.to_s => MILESTONE,
    ApplicationController::ABOUTME_TALKS_PATH.to_s => MILESTONE,
    ApplicationController::ABOUTME_ACHIEVEMENTS_PATH.to_s => ACHIEVEMENT
  }.freeze

  OBJECT_SCHEMAS = {
    ApplicationController::BLOG_INFO_PATH.to_s => BLOG_ENTRY,
    ApplicationController::CTF_INFO_PATH.to_s => CTF_ENTRY
  }.freeze

  def self.validate!(path, data)
    errors = errors_for(path, data)
    raise ValidationError.new(path, errors) if errors.any?

    true
  end

  def self.errors_for(path, data)
    schema = schema_for(path)
    return [] unless schema

    JSONSchemer.schema(schema).validate(data).to_a
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
