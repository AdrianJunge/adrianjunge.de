require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class CiImageChangesTest < ActiveSupport::TestCase
  setup do
    @temporary = Dir.mktmpdir("ci-image-changes-")
    @repository = File.join(@temporary, "repository")
    @output = File.join(@temporary, "output")
    FileUtils.mkdir_p(@repository)
    git("init", "--quiet")
    @base = commit("README.md", "Initial content\n")
  end

  teardown do
    FileUtils.remove_entry(@temporary) if @temporary
  end

  test "skips image work for unrelated changes and unchanged commits" do
    refute images_changed(@base, @base)
    refute images_changed(@base, commit("README.md", "Updated content\n"))
    # A newline within one filename must not be treated as a second path.
    refute images_changed(@base, commit("notes\npackage.json", "An unrelated fixture\n"))
  end

  test "checks all image inputs and workflow changes including unusual filenames" do
    paths = [
      "scripts/images/export.py", "content/images/originals/logo.svg",
      "app/assets/images/diagram\nrevision.svg", "app/assets/images/a logo.svg",
      ".github/workflows/ci.yml", ".github/workflows/release.yml", ".node-version",
      "config/image_variants.json", "package.json", "package-lock.json", "scripts/ci_image_changes.py"
    ]
    base = @base
    paths.each do |path|
      head = commit(path, "Changed fixture\n")
      assert images_changed(base, head), "#{path.inspect} must trigger image checks"
      base = head
    end
  end

  test "deleted and renamed image inputs still trigger checks" do
    base = commit("app/assets/images/logo.svg", "Image fixture\n")
    git("mv", "app/assets/images/logo.svg", "former-logo.svg")
    git("commit", "--quiet", "-m", "Rename fixture")
    head = git("rev-parse", "HEAD").strip
    assert images_changed(base, head)

    base = commit("content/images/originals/logo.svg", "Image fixture\n")
    git("rm", "--quiet", "content/images/originals/logo.svg")
    git("commit", "--quiet", "-m", "Delete fixture")
    assert images_changed(base, git("rev-parse", "HEAD").strip)
  end

  test "missing or unavailable commit metadata conservatively runs image checks" do
    [ "", "0" * 40, "1" * 40, "main" ].each do |base|
      assert images_changed(base, @base), "#{base.inspect} must fall back to image checks"
    end
    [ "", "0" * 40, "1" * 40 ].each do |head|
      assert images_changed(@base, head), "#{head.inspect} must fall back to image checks"
    end
  end

  private

  def git(*arguments)
    environment = {
      "GIT_CONFIG_NOSYSTEM" => "1", "GIT_CONFIG_GLOBAL" => File::NULL,
      "GIT_AUTHOR_NAME" => "CI Fixture", "GIT_AUTHOR_EMAIL" => "fixture@example.invalid",
      "GIT_COMMITTER_NAME" => "CI Fixture", "GIT_COMMITTER_EMAIL" => "fixture@example.invalid"
    }
    output, error, status = Open3.capture3(environment, "git", *arguments, chdir: @repository)
    assert status.success?, "git #{arguments.inspect}: #{error}"
    output
  end

  def commit(path, content)
    destination = File.join(@repository, path)
    FileUtils.mkdir_p(File.dirname(destination))
    File.write(destination, content)
    git("add", "--", path)
    git("commit", "--quiet", "-m", "Update fixture")
    git("rev-parse", "HEAD").strip
  end

  def images_changed(base, head)
    File.write(@output, "existing=value\n")
    output, error, status = Open3.capture3(
      { "DIFF_BASE" => base, "DIFF_HEAD" => head, "GITHUB_OUTPUT" => @output },
      "python3", Rails.root.join("scripts/ci_image_changes.py").to_s, chdir: @repository
    )
    assert status.success?, "#{output}\n#{error}"
    contents = File.read(@output)
    assert_match(/\Aexisting=value\nimages=(true|false)\n\z/, contents)
    contents.end_with?("images=true\n")
  end
end
