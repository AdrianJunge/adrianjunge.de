require "test_helper"

class ContentJsonSchemasTest < ActiveSupport::TestCase
  test "all content json assets are registered for schema validation" do
    content_json_paths = Dir.glob(Rails.root.join("app", "assets", "{aboutme,blog,ctf,timeline}", "*.json")).sort

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
    [
      ApplicationController::ABOUTME_CVES_PATH,
      ApplicationController::ABOUTME_CERTIFICATES_PATH,
      ApplicationController::ABOUTME_CHALLENGES_PATH,
      ApplicationController::ABOUTME_TALKS_PATH,
      ApplicationController::ABOUTME_ACHIEVEMENTS_PATH
    ].each do |path|
      parse_content_json(path).each do |entry|
        assert_not entry.key?("date"), "card-level date found in #{path}: #{entry["id"]}"
      end
    end
  end

  test "About timeline events can override inherited tags with explicit or empty arrays" do
    path = ApplicationController::ABOUTME_ACHIEVEMENTS_PATH
    event = { "date" => "2026-04-09", "title" => "Audit", "tags" => [ "Audit Competition", { "label" => "Platform", "url" => "https://example.com" } ] }
    entry = { "id" => "platform", "title" => "Platform", "timeline" => [ event ] }
    assert_empty ContentJsonSchemas.errors_for(path, [ entry ])
    event["tags"] = []
    assert_empty ContentJsonSchemas.errors_for(path, [ entry ])
    event["tags"] = "Audit Competition"
    assert ContentJsonSchemas.errors_for(path, [ entry ]).any? { |error| error["data_pointer"] == "/0/timeline/0/tags" }
  end

  test "standalone timeline events require an identity title and occurrence date" do
    path = ContentConfiguration::TIMELINE_EVENTS_PATH
    event = {
      "id" => "standalone-event", "title" => "Standalone event", "date" => "2026-09-26",
      "summary" => "Only on the timeline.", "tags" => [ "Security Research" ],
      "icon" => "other/achievement.svg", "url" => "https://example.com/event",
      "modified" => "2026-09-27"
    }
    assert_empty ContentJsonSchemas.errors_for(path, [ event ])

    %w[id title date].each do |key|
      errors = ContentJsonSchemas.errors_for(path, [ event.except(key) ])
      assert errors.any? { |error| error["data_pointer"] == "/0/#{key}" }, "missing #{key} was accepted"
    end
    errors = ContentJsonSchemas.errors_for(path, [ event.merge("date" => "2026-02-30") ])
    assert errors.any? { |error| error["data_pointer"] == "/0/date" }
    assert_empty ContentJsonSchemas.errors_for(path, [ event.merge("date" => "2019-09", "display_date" => "Around Sep 2019") ])
    errors = ContentJsonSchemas.errors_for(path, [ event.merge("date" => "2019-13") ])
    assert errors.any? { |error| error["data_pointer"] == "/0/date" }
  end

  test "ctf metadata derives its configured paths" do
    repository = ContentRepository.new
    ctf_metadata = repository.ctf_metadata
    ctf_metadata.each do |_name, entry|
      assert_match %r{\A/ctf/#{Regexp.escape(entry.fetch("directory"))}\z}, entry.fetch("writeups")
    end
  end

  test "standalone timeline titles must contain visible text" do
    path = ContentConfiguration::TIMELINE_EVENTS_PATH
    event = { "id" => "standalone-event", "date" => "2023-10-02" }

    [ "", "   ", "\t\r\n", "\u00a0", "\u2003" ].each do |title|
      errors = ContentJsonSchemas.errors_for(path, [ event.merge("title" => title) ])
      assert errors.any? { |error| error["data_pointer"] == "/0/title" }, "blank title #{title.inspect} was accepted"
    end
    assert_empty ContentJsonSchemas.errors_for(path, [ event.merge("title" => " First steps ") ])
  end

  test "milestone periods validate real dates and chronological endpoint bounds" do
    path = ContentConfiguration::TIMELINE_EVENTS_PATH
    event = { "id" => "period", "title" => "A period" }
    [
      [ "2023-10", "2025" ], [ "2024", "2024-01" ],
      [ "2024-02-29", "2024-02" ], [ "2024-02", "2024-02-01" ],
      [ "2023-12-31T23:30:00-02:00", "2024-01-01T02:00:00Z" ]
    ].each do |first, last|
      errors = ContentJsonSchemas.errors_for(path, [ event.merge("date" => first, "end_date" => last) ])
      assert_empty errors, "#{first} to #{last}: #{errors}"
    end

    [
      [ "2025", "2024" ], [ "2025-03", "2025-02" ],
      [ "2024-03-01", "2024-02" ], [ "2024-02-29", "2024-02-28" ],
      [ "2024-01-01T01:30:00Z", "2023-12-31T23:00:00-02:00" ],
      [ "2023", "2025-02-29" ], [ "2023", "2024-13" ],
      [ "2023", "" ], [ "2023", nil ]
    ].each do |first, last|
      errors = ContentJsonSchemas.errors_for(path, [ event.merge("date" => first, "end_date" => last) ])
      assert errors.any? { |error| error["data_pointer"] == "/0/end_date" }, "#{first} to #{last} was accepted"
    end
  end

  test "milestone periods have one date source and unambiguous endpoints" do
    path = ContentConfiguration::TIMELINE_EVENTS_PATH
    event = { "id" => "period", "title" => "A period", "date" => "2023", "end_date" => "2025" }
    errors = ContentJsonSchemas.errors_for(path, [ event.merge("display_date" => "Some other dates") ])
    assert errors.any? { |error| error["data_pointer"] == "/0/display_date" }

    %w[date end_date].each do |key|
      errors = ContentJsonSchemas.errors_for(path, [ event.merge(key => "2023–2025") ])
      assert errors.any? { |error| error["data_pointer"] == "/0/#{key}" }
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
    parse_content_json(ContentConfiguration::TIMELINE_EVENTS_PATH).each { |event| asset_refs << event["icon"] }

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
      [ ContentConfiguration::TIMELINE_EVENTS_PATH, FixtureContentRepository::TIMELINE_EVENTS_PATH ],
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
