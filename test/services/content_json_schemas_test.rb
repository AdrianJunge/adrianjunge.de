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

  test "about collections keep unique ids" do
    [
      ApplicationController::ABOUTME_CVES_PATH,
      ApplicationController::ABOUTME_BUG_BOUNTIES_PATH,
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

  test "ctf and blog metadata keys point at their configured paths" do
    ctf_metadata = parse_content_json(ApplicationController::CTF_INFO_PATH)
    ctf_metadata.each do |_name, entry|
      assert_match %r{\A/ctf/#{Regexp.escape(entry.fetch("terminal_path"))}\z}, entry.fetch("writeups")
    end

    blog_metadata = parse_content_json(ApplicationController::BLOG_INFO_PATH)
    blog_metadata.each do |slug, entry|
      assert_equal slug, entry.fetch("terminal_path")
    end
  end

  test "content image references point at local assets" do
    asset_refs = []
    repository = ContentRepository.new

    [
      ApplicationController::ABOUTME_CVES_PATH,
      ApplicationController::ABOUTME_BUG_BOUNTIES_PATH,
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

    repository.blog_metadata.each_value { |entry| asset_refs << entry["logo"] }
    repository.ctf_metadata.each_value { |entry| asset_refs << entry["logo"] }
    repository.authored_challenges.each { |entry| asset_refs << entry["icon"] }

    asset_refs.compact_blank.each do |asset_ref|
      assert_no_match %r{\Ahttps?://}, asset_ref
      assert Rails.root.join("app", "assets", "images", asset_ref).exist?, "missing image asset #{asset_ref}"
    end
  end

  test "invalid content json reports useful schema errors" do
    data = parse_content_json(ApplicationController::ABOUTME_CVES_PATH)
    data.first.delete("title")

    error = assert_raises(ContentJsonSchemas::ValidationError) do
      ContentJsonSchemas.validate!(ApplicationController::ABOUTME_CVES_PATH, data)
    end

    assert_includes error.message, "/0"
    assert_includes error.message, "required"
  end

  private

  def schema_error_message(path, errors)
    formatted = errors.map do |error|
      "#{error["data_pointer"]}: #{error["type"]} #{error["details"]}"
    end.join("\n")

    "schema errors in #{path}:\n#{formatted}"
  end
end
