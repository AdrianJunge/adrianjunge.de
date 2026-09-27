require "test_helper"

class ContentJsonSchemasTest < ActiveSupport::TestCase
  test "all content json assets are registered for schema validation" do
    content_json_paths = Dir.glob(Rails.root.join("app", "assets", "{aboutme,blog,ctf}", "*.json")).sort

    assert_equal content_json_paths, ContentJsonSchemas.registered_paths
  end

  test "all content json files match their json_schemer schemas" do
    ContentJsonSchemas.registered_paths.each do |path|
      data = parse_content_json(path)
      errors = ContentJsonSchemas.errors_for(path, data)

      assert_empty errors, schema_error_message(path, errors)
    end
  end

  test "synthetic fixture json matches the production schemas" do
    fixture_schema_cases.each do |schema_path, fixture_path|
      errors = ContentJsonSchemas.errors_for(schema_path, parse_content_json(fixture_path))

      assert_empty errors, schema_error_message(fixture_path, errors)
    end
  end

  test "about collections keep unique ids" do
    [
      ApplicationController::ABOUTME_CVES_PATH,
      ApplicationController::ABOUTME_CERTIFICATES_PATH,
      ApplicationController::ABOUTME_CHALLENGES_PATH,
      ApplicationController::ABOUTME_TALKS_PATH,
      ApplicationController::ABOUTME_ACHIEVEMENTS_PATH
    ].each do |path|
      ids = parse_content_json(path).map { |entry| entry["id"] }

      assert_equal ids.uniq, ids, "duplicate ids in #{path}"
    end
  end

  test "about card dates live in timeline entries" do
    ContentJsonSchemas::ARRAY_SCHEMAS.each_key do |path|
      parse_content_json(path).each do |entry|
        assert_not entry.key?("date"), "card-level date found in #{path}: #{entry["id"]}"
      end
    end
  end

  test "ctf metadata derives its configured paths" do
    repository = ContentRepository.new
    ctf_metadata = repository.ctf_metadata
    ctf_metadata.each do |_name, entry|
      assert_match %r{\A/ctf/#{Regexp.escape(entry.fetch("directory"))}\z}, entry.fetch("writeups")
    end
  end

  test "ctf catalog schema accepts derived routes" do
    assert_empty ContentJsonSchemas.errors_for(ContentConfiguration::CTF_INFO_PATH, {
      "Event" => { "logo" => "ctf/event.png", "website" => "https://example.com", "description" => "An event" }
    })
  end

  test "About cards and events allow explicit authored modification dates" do
    data = [ {
      "id" => "talk", "title" => "A talk", "modified" => "2026-09-26",
      "timeline" => [ { "date" => "2027-01-01", "updated" => "2026-09-25" } ]
    } ]
    assert_empty ContentJsonSchemas.errors_for(ContentConfiguration::ABOUTME_TALKS_PATH, data)
    data.first["timeline"].first["updated"] = "2026-02-30"
    assert ContentJsonSchemas.errors_for(ContentConfiguration::ABOUTME_TALKS_PATH, data).any? { |error| error["data_pointer"] == "/0/timeline/0/updated" }
  end

  test "content image references point at local assets" do
    asset_refs = []
    repository = ContentRepository.new

    [
      ApplicationController::ABOUTME_CVES_PATH,
      ApplicationController::ABOUTME_CERTIFICATES_PATH,
      ApplicationController::ABOUTME_CHALLENGES_PATH,
      ApplicationController::ABOUTME_TALKS_PATH,
      ApplicationController::ABOUTME_ACHIEVEMENTS_PATH
    ].each do |path|
      parse_content_json(path).each do |entry|
        asset_refs << entry["icon"]
        Array(entry["timeline"]).each { |event| asset_refs << event["icon"] if event.is_a?(Hash) }
      end
    end

    repository.blog_posts.each { |post| asset_refs << post[:logo] }
    repository.ctf_metadata.each_value { |entry| asset_refs << entry["logo"] }
    repository.authored_challenges.each { |entry| asset_refs << entry["icon"] }

    asset_refs.compact_blank.each do |asset_ref|
      assert_no_match %r{\Ahttps?://}, asset_ref
      assert Rails.root.join("app", "assets", "images", asset_ref).exist?, "missing image asset #{asset_ref}"
    end
  end

  test "invalid content json reports useful schema errors" do
    fixture_path = FixtureContentRepository::ABOUT_PATHS.fetch(ApplicationController::ABOUTME_CVES_PATH.to_s)
    data = parse_content_json(fixture_path)
    data.first.delete("title")

    error = assert_raises(ContentJsonSchemas::ValidationError) do
      ContentJsonSchemas.validate!(ApplicationController::ABOUTME_CVES_PATH, data)
    end

    assert_includes error.message, "/0"
    assert_includes error.message, "required"
  end

  test "semantic metadata validation rejects impossible dates and unsupported links" do
    errors = ContentJsonSchemas.metadata_errors({
      "date" => "2025-02-29", "url" => "ftp://example.com/file", "has_math" => "yes"
    })
    assert_equal %w[/date /url /has_math], errors.map { |error| error["data_pointer"] }
    assert_empty ContentJsonSchemas.metadata_errors({
      "date" => "2026-09-05T12:30:00+02:00", "url" => "/about#talk", "has_math" => false
    })
  end

  private

  def fixture_schema_cases
    about_cases = FixtureContentRepository::ABOUT_PATHS.map do |schema_path, fixture_path|
      [ schema_path, fixture_path ]
    end

    about_cases + [
      [ ApplicationController::CTF_INFO_PATH, FixtureContentRepository::ROOT.join("ctf", "ctfs.json") ]
    ]
  end

  def schema_error_message(path, errors)
    formatted = errors.map do |error|
      "#{error["data_pointer"]}: #{error["type"]} #{error["details"]}"
    end.join("\n")

    "schema errors in #{path}:\n#{formatted}"
  end
end
