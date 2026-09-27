require "test_helper"
require "yaml"

class GithubWorkflowsTest < ActiveSupport::TestCase
  setup do
    @workflows = Dir[Rails.root.join(".github/workflows/*.{yml,yaml}")].to_h do |path|
      [ File.basename(path), YAML.safe_load_file(path) ]
    end
  end

  test "public contributions only run unprivileged CI and releases require manual dispatch" do
    assert_equal %w[ci.yml release.yml], @workflows.keys.sort
    assert_equal %w[pull_request push], events(@workflows.fetch("ci.yml")).keys.sort
    assert_equal [ "main" ], events(@workflows.fetch("ci.yml")).dig("push", "branches")
    assert_equal [ "workflow_dispatch" ], events(@workflows.fetch("release.yml")).keys
    assert_equal({ "contents" => "read" }, @workflows.fetch("ci.yml").fetch("permissions"))
    assert_equal({}, @workflows.fetch("release.yml").fetch("permissions"))
  end

  test "workflows use immutable approved actions and do not persist checkout credentials" do
    allowed_actions = %w[actions/checkout ruby/setup-ruby actions/setup-node actions/setup-python actions/upload-artifact actions/download-artifact]
    @workflows.each_value do |workflow|
      workflow.fetch("jobs").each_value do |job|
        job.fetch("steps").each do |step|
          next unless step["uses"]
          action, revision = step.fetch("uses").split("@", 2)
          assert_includes allowed_actions, action
          assert_match(/\A[0-9a-f]{40}\z/, revision.to_s, "#{action} must be pinned to a full commit")
          if action == "actions/checkout"
            assert_equal false, step.dig("with", "persist-credentials")
            refute step.fetch("with").key?("token"), "Checkout must use the job's restricted token"
          end
        end
      end
    end
  end

  test "jobs use disposable hosted runners and bounded execution time" do
    @workflows.each_value do |workflow|
      workflow.fetch("jobs").each_value do |job|
        assert_equal "ubuntu-24.04", job.fetch("runs-on")
        assert_includes 1..45, job.fetch("timeout-minutes")
      end
    end
  end

  test "only the isolated publisher can write packages and no job can write repository contents" do
    @workflows.each do |filename, workflow|
      workflow.fetch("jobs").each do |job_name, job|
        permissions = job.fetch("permissions", workflow.fetch("permissions"))
        permissions.each do |scope, access|
          if access == "write"
            assert_equal [ "release.yml", "publish", "packages" ], [ filename, job_name, scope ]
          else
            assert_includes %w[read none], access
          end
        end
      end
    end
    publisher = @workflows.fetch("release.yml").fetch("jobs").fetch("publish")
    assert_equal({ "packages" => "write" }, publisher.fetch("permissions"))
    publisher.fetch("steps").each do |step|
      next unless step["uses"]
      assert_includes %w[actions/download-artifact actions/upload-artifact], step.fetch("uses").split("@").first
    end
  end

  test "workflow contexts enter scripts as data and long lived secrets are not required" do
    @workflows.each do |filename, workflow|
      refute_match(/secrets\s*[.\[]/, workflow.to_json, "#{filename} must not expose repository secrets")
      workflow.fetch("jobs").each_value do |job|
        job.fetch("steps").each do |step|
          next unless step["run"]
          refute_includes step.fetch("run"), "${{", "Pass workflow inputs through env, not script interpolation"
        end
      end
    end
  end

  test "Dependabot maintains action pins without executing dependency manifests or bypassing review" do
    configuration = YAML.safe_load_file(Rails.root.join(".github/dependabot.yml"))
    updates = configuration.fetch("updates")
    assert updates.any? { |update| update["package-ecosystem"] == "github-actions" && update["directory"] == "/" }
    updates.each do |update|
      refute_equal "allow", update["insecure-external-code-execution"]
      assert_operator update.fetch("cooldown").fetch("default-days"), :>=, 7
    end
    assert_includes File.read(Rails.root.join(".github/CODEOWNERS")), "* @AdrianJunge"
  end

  test "accessibility evidence is mandatory after an attempted system test run" do
    steps = @workflows.fetch("ci.yml").fetch("jobs").fetch("test").fetch("steps")
    unit_tests = steps.find { |step| step["run"] == "bin/rails content:validate test" }
    system_tests = steps.find { |step| step["id"] == "system_tests" }
    summary = steps.find { |step| step["run"] == "npm run accessibility:summary" }
    evidence = steps.find { |step| step.dig("with", "name") == "accessibility-reports" }

    assert unit_tests, "Unit-test failures must be distinguishable from an attempted browser run"
    assert system_tests
    assert_operator steps.index(unit_tests), :<, steps.index(system_tests)
    assert_equal "bin/rails test:system", system_tests.fetch("run")
    assert_nil system_tests["if"], "System tests use the normal successful-prerequisites guard"
    assert summary, "A complete accessibility summary must remain required"
    assert_operator steps.index(system_tests), :<, steps.index(summary)

    attempted_run = "${{ !cancelled() && (steps.system_tests.outcome == 'success' || steps.system_tests.outcome == 'failure') }}"
    [ summary, evidence ].each do |step|
      assert_equal attempted_run, step.fetch("if"), "Preserve evidence after failures, but skip reports when browsers never ran"
    end
    [ unit_tests, system_tests, summary ].each do |step|
      refute step["continue-on-error"], "Test and evidence failures must fail CI"
    end
  end

  private

  def events(workflow)
    # Psych follows YAML 1.1, where the unquoted GitHub Actions key `on` is boolean.
    workflow.fetch("on") { workflow.fetch(true) }
  end
end
