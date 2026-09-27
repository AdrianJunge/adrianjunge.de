require "test_helper"
require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require "yaml"

class ReleaseWorkflowTest < ActiveSupport::TestCase
  setup do
    @workflow = YAML.safe_load_file(Rails.root.join(".github/workflows/release.yml"))
    @directory = Dir.mktmpdir("release-workflow-test-")
    @commit = "a" * 40
    @image_id = "sha256:#{'b' * 64}"
    @image = "ghcr.io/adrianjunge/adrianjunge.de:sha-#{@commit}-12-1"
    @digest = "ghcr.io/adrianjunge/adrianjunge.de@sha256:#{'c' * 64}"
    @archive = File.join(@directory, "release-candidate/image.tar")
    FileUtils.mkdir_p(File.dirname(@archive))
    File.write(@archive, "Benign candidate archive fixture\n")
    @environment = {
      "GITHUB_REPOSITORY" => "AdrianJunge/adrianjunge.de",
      "GITHUB_SHA" => @commit, "GITHUB_REF" => "refs/heads/main",
      "GITHUB_EVENT_NAME" => "workflow_dispatch", "GITHUB_ACTOR" => "AdrianJunge",
      "GITHUB_TRIGGERING_ACTOR" => "AdrianJunge", "GITHUB_RUN_ID" => "12",
      "GITHUB_RUN_ATTEMPT" => "1", "BUILD_ATTEMPT" => "1",
      "RUNNER_TEMP" => @directory, "EXPECTED_IMAGE_ID" => @image_id,
      "EXPECTED_ARCHIVE_SHA256" => Digest::SHA256.file(@archive).hexdigest,
      "GITHUB_ENV" => File.join(@directory, "github-env"),
      "GITHUB_STEP_SUMMARY" => File.join(@directory, "summary"),
      "RELEASE_IMAGE" => @image
    }
    @inspection = [ {
      "Id" => @image_id, "RepoTags" => [ @image ], "RepoDigests" => [ @digest ],
      "Config" => { "Labels" => {
        "org.opencontainers.image.source" => "https://github.com/AdrianJunge/adrianjunge.de",
        "org.opencontainers.image.revision" => @commit
      } }
    } ]
    @run = {
      "id" => 50, "head_sha" => @commit, "head_branch" => "main", "event" => "push",
      "path" => ".github/workflows/ci.yml", "status" => "completed", "conclusion" => "success",
      "repository" => { "full_name" => "AdrianJunge/adrianjunge.de" },
      "head_repository" => { "full_name" => "AdrianJunge/adrianjunge.de" }
    }
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test "gate accepts the exact successful main push run" do
    assert_success execute_python("gate", /Require the latest/, runs: [ @run ])
    assert_empty docker_calls
  end

  test "gate refuses older success when the latest run failed or is unfinished" do
    [ { "status" => "completed", "conclusion" => "failure" },
      { "status" => "in_progress", "conclusion" => nil } ].each do |state|
      assert_failure execute_python("gate", /Require the latest/, runs: [ @run.merge("id" => 49), @run.merge(state) ])
    end
    assert_failure execute_python("gate", /Require the latest/, runs: [])
  end

  test "gate rejects CI evidence from the wrong source event workflow or repository" do
    [ { "head_sha" => "d" * 40 }, { "head_branch" => "other" }, { "event" => "pull_request" },
      { "path" => ".github/workflows/other.yml" }, { "repository" => { "full_name" => "example/site" } },
      { "head_repository" => { "full_name" => "example/site" } }, { "id" => "50" } ].each do |change|
      assert_failure execute_python("gate", /Require the latest/, runs: [ @run.merge(change) ])
    end
  end

  test "gate requires an owner dispatch and owner rerun on the original main branch" do
    { "GITHUB_REPOSITORY" => "example/site", "GITHUB_REF" => "refs/heads/other",
      "GITHUB_EVENT_NAME" => "pull_request", "GITHUB_ACTOR" => "dependabot[bot]",
      "GITHUB_TRIGGERING_ACTOR" => "another-user" }.each do |key, value|
      assert_failure execute_python("gate", /Require the latest/, runs: [ @run ], environment: { key => value })
    end
  end

  test "artifact download requires exactly one positive numeric ID" do
    script = step("publish", /Require one immutable/).fetch("run")
    [ [ "123", true ], [ "", false ], [ "0", false ], [ "1,2", false ], [ "unknown", false ] ].each do |value, valid|
      _output, error, status = Open3.capture3({ "ARTIFACT_ID" => value }, "bash", "-euo", "pipefail", "-c", script)
      assert_equal valid, status.success?, error
    end
  end

  test "candidate verification loads only the matching archive and records the expected tag" do
    assert_success execute_python("publish", /Verify the archive/)
    assert_equal [ "load", "inspect" ], docker_calls.map { |call| call[2] }
    assert_equal "RELEASE_IMAGE=#{@image}\n", File.read(@environment.fetch("GITHUB_ENV"))
  end

  test "archive corruption and malformed build identities fail before loading an image" do
    [ { "EXPECTED_ARCHIVE_SHA256" => "d" * 64 }, { "EXPECTED_ARCHIVE_SHA256" => "missing" },
      { "EXPECTED_IMAGE_ID" => "missing" }, { "GITHUB_SHA" => "short" },
      { "GITHUB_REPOSITORY" => "example/site" } ].each do |environment|
      assert_failure execute_python("publish", /Verify the archive/, environment: environment)
      assert_empty docker_calls
    end
  end

  test "candidate verification rejects a missing or symlinked archive" do
    File.rename(@archive, "#{@archive}.saved")
    assert_failure execute_python("publish", /Verify the archive/)
    File.symlink("#{@archive}.saved", @archive)
    assert_failure execute_python("publish", /Verify the archive/)
    assert_empty docker_calls
  end

  test "candidate verification rejects image tag identity and label mismatches" do
    original = @inspection.deep_dup
    [ { "Id" => "sha256:#{'d' * 64}" }, { "RepoTags" => [ "ghcr.io/example/site:latest" ] },
      { "Config" => { "Labels" => {} } },
      { "Config" => { "Labels" => original.first.fetch("Config").fetch("Labels").merge("org.opencontainers.image.revision" => "d" * 40) } },
      { "Config" => { "Labels" => original.first.fetch("Config").fetch("Labels").merge("org.opencontainers.image.source" => "https://github.com/example/site") } } ].each do |change|
      @inspection = [ original.first.merge(change) ]
      assert_failure execute_python("publish", /Verify the archive/)
      assert_not File.exist?(@environment.fetch("GITHUB_ENV"))
    end
    @inspection = []
    assert_failure execute_python("publish", /Verify the archive/)
  end

  test "publication retry preserves the tested build identity and records both attempts" do
    environment = { "GITHUB_RUN_ATTEMPT" => "2" }
    assert_success execute_python("publish", /Verify the archive/, environment: environment)
    assert_success execute_python("publish", /Publish the tested/, environment: environment)
    manifest = JSON.parse(File.read(File.join(@directory, "release-manifest/release.json")))
    assert_equal @image, manifest.fetch("image_tag")
    assert_equal @digest, manifest.fetch("image_digest")
    assert_equal @image_id, manifest.fetch("image_id")
    assert_equal @commit, manifest.fetch("source_commit")
    assert_equal @environment.fetch("EXPECTED_ARCHIVE_SHA256"), manifest.fetch("candidate_archive_sha256")
    assert_match %r{/runs/12/attempts/1\z}, manifest.fetch("workflow_run")
    assert_match %r{/runs/12/attempts/2\z}, manifest.fetch("publication_workflow_run")
    assert_match /```json/, File.read(@environment.fetch("GITHUB_STEP_SUMMARY"))
  end

  test "future and invalid build attempts fail before loading an image" do
    [ "2", "0", "", "one" ].each do |attempt|
      assert_failure execute_python("publish", /Verify the archive/, environment: { "BUILD_ATTEMPT" => attempt })
      assert_empty docker_calls
    end
  end

  test "release identity requires one valid pushed digest from the expected repository" do
    [ [], [ "ghcr.io/example/site@sha256:#{'c' * 64}" ], [ "ghcr.io/adrianjunge/adrianjunge.de@sha256:invalid" ],
      [ @digest, "ghcr.io/adrianjunge/adrianjunge.de@sha256:#{'d' * 64}" ] ].each do |digests|
      @inspection.first["RepoDigests"] = digests
      assert_failure execute_python("publish", /Publish the tested/)
      assert_not File.exist?(File.join(@directory, "release-manifest/release.json"))
    end
  end

  test "release identity rejects a changed image or release tag" do
    @inspection.first["Id"] = "sha256:#{'d' * 64}"
    assert_failure execute_python("publish", /Publish the tested/)
    @inspection.first["Id"] = @image_id
    assert_failure execute_python("publish", /Publish the tested/, environment: { "RELEASE_IMAGE" => "ghcr.io/example/site:latest" })
  end

  private

  def step(job, name)
    @workflow.fetch("jobs").fetch(job).fetch("steps").find { |entry| name.match?(entry.fetch("name", "")) } || raise("Missing #{job} step #{name}")
  end

  def execute_python(job, name, runs: [], environment: {})
    File.write(File.join(@directory, "release-ci-runs.json"), JSON.generate("workflow_runs" => runs))
    script = step(job, name).fetch("run").match(/python3 - <<'PY'\n(.*?)\nPY\n?\z/m)&.[](1) || raise("Missing Python block")
    # Execute the workflow's actual validation logic, replacing every Docker
    # subprocess with bounded fixtures. No image is loaded, run, or published.
    harness = <<~PYTHON
      import json, os, subprocess
      from unittest.mock import patch

      def record(arguments):
          with open(os.environ["TEST_DOCKER_CALLS"], "a") as output:
              output.write(json.dumps(arguments) + "\\n")

      def load(arguments, check):
          assert arguments == ["docker", "image", "load", "--input", os.environ["TEST_ARCHIVE"]]
          assert check is True
          record(arguments)
          return subprocess.CompletedProcess(arguments, 0)

      def inspect(arguments, text):
          assert arguments == ["docker", "image", "inspect", os.environ["TEST_IMAGE"]]
          assert text is True
          record(arguments)
          return os.environ["TEST_INSPECTION"]

      with patch("subprocess.run", side_effect=load), patch("subprocess.check_output", side_effect=inspect):
          exec(#{script.to_json})
    PYTHON
    variables = @environment.merge(
      "TEST_DOCKER_CALLS" => File.join(@directory, "docker-calls.jsonl"),
      "TEST_ARCHIVE" => @archive, "TEST_IMAGE" => @image,
      "TEST_INSPECTION" => JSON.generate(@inspection)
    ).merge(environment)
    Open3.capture3(variables, "python3", "-", stdin_data: harness)
  end

  def docker_calls
    path = File.join(@directory, "docker-calls.jsonl")
    File.exist?(path) ? File.readlines(path).map { |line| JSON.parse(line) } : []
  end

  def assert_success(result)
    output, error, status = result
    assert status.success?, "#{output}\n#{error}"
  end

  def assert_failure(result)
    output, error, status = result
    assert_not status.success?, "Unexpected success: #{output}\n#{error}"
  end
end
