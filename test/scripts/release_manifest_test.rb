require "test_helper"
require_relative "../../scripts/release_manifest"

class ReleaseManifestTest < ActiveSupport::TestCase
  setup do
    @commit = "a" * 40
    @image = "ghcr.io/example/site:sha-#{@commit}-12-2"
    @run_url = "https://github.com/example/site/actions/runs/12/attempts/2"
    @inspection = [ {
      "Id" => "sha256:#{'b' * 64}", "RepoDigests" => [ "ghcr.io/example/site@sha256:#{'c' * 64}" ],
      "Config" => { "Labels" => { "org.opencontainers.image.revision" => @commit, "org.opencontainers.image.source" => "https://github.com/Example/Site" } }
    } ]
  end

  test "records pushed digest source identity and unique release tag" do
    manifest = build
    assert_equal "ghcr.io/example/site@sha256:#{'c' * 64}", manifest[:image_digest]
    assert_equal @image, manifest[:image_tag]
    assert_equal @commit, manifest[:source_commit]
    assert_equal @run_url, manifest[:workflow_run]
    assert_equal "2026-09-27T12:00:00Z", manifest[:created_at]
  end

  test "rejects unpublished wrong repository ambiguous or invalid digests" do
    [ [], [ "ghcr.io/other/site@sha256:#{'c' * 64}" ], [ "ghcr.io/example/site@sha256:bad" ], [ "ghcr.io/example/site@sha256:#{'c' * 64}", "ghcr.io/example/site@sha256:#{'d' * 64}" ] ].each do |digests|
      @inspection.first["RepoDigests"] = digests
      assert_raises(ArgumentError) { build }
    end
  end

  test "rejects mutable tags and inconsistent source or workflow identity" do
    assert_raises(ArgumentError) { build(image: "ghcr.io/example/site:latest") }
    assert_raises(ArgumentError) { build(commit: "b" * 40) }
    assert_raises(ArgumentError) { build(run_url: "https://github.com/example/site/actions/runs/13/attempts/2") }
    @inspection.first["Config"]["Labels"]["org.opencontainers.image.revision"] = "d" * 40
    assert_raises(ArgumentError) { build }
  end

  private

  def build(**overrides)
    ReleaseManifest.build(**{ image: @image, commit: @commit, run_url: @run_url, inspection: @inspection, now: Time.utc(2026, 9, 27, 12) }.merge(overrides))
  end
end
