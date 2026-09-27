require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class UpdateCommandTest < ActiveSupport::TestCase
  REQUIREMENTS = "# Image authoring dependencies\n\nPillow==12.3.0 # Keep this explanation\n"

  setup do
    @temporary = Dir.mktmpdir("update-command-")
    @repository = File.join(@temporary, "repository")
    @executables = File.join(@temporary, "executables")
    @fonts = File.join(@temporary, "image fonts")
    @log = File.join(@temporary, "commands.jsonl")
    FileUtils.mkdir_p([ @executables, @fonts, File.join(@repository, "bin") ])
    %w[DejaVuSans.ttf DejaVuSans-Bold.ttf].each { |font| FileUtils.touch(File.join(@fonts, font)) }
    FileUtils.cp(Rails.root.join("bin/update"), File.join(@repository, "bin/update"))
    write_file(".ruby-version", "#{RUBY_VERSION}\n")
    write_file(".bundle/config", "---\nBUNDLE_FROZEN: 'true'\nBUNDLE_DEPLOYMENT: 'true'\nBUNDLE_WITHOUT: 'development:test'\n")
    write_file("package.json", JSON.generate(dependencies: { "runtime-tool" => "1.0.0" }, devDependencies: { "@scope/qa-tool" => "2.0.0" }))
    write_file("config/mathjax/package.json", JSON.generate(dependencies: { "mathjax" => "4.0.0" }))
    write_file("scripts/images/requirements.txt", REQUIREMENTS)
    [ "node", "npm", "bundle", "python3" ].each { |name| write_stub(File.join(@executables, name)) }
    [ "bin/rails", "bin/check", "node_modules/.bin/playwright" ].each { |path| write_stub(File.join(@repository, path)) }
  end

  teardown do
    FileUtils.remove_entry(@temporary) if @temporary
  end

  test "upgrades every dependency inventory and rebuilds artifacts when invoked outside the repository" do
    bundler_configuration = File.read(File.join(@repository, ".bundle/config"))
    output, error, status = invoke
    assert status.success?, "#{output}\n#{error}"
    assert_includes output, "Dependencies upgraded and installed"
    assert calls.all? { |call| call.fetch("cwd") == @repository }

    bundle = calls.find { |call| call.fetch("command") == [ "bundle", "update", "--all" ] }
    assert bundle, "Gem dependencies must be upgraded"
    assert_equal "false", bundle.dig("env", "BUNDLE_FROZEN")
    assert_equal "false", bundle.dig("env", "BUNDLE_DEPLOYMENT")
    assert_equal "", bundle.dig("env", "BUNDLE_WITHOUT")
    assert_equal bundler_configuration, File.read(File.join(@repository, ".bundle/config"))
    assert_includes commands, [ "npm", "install", "--prefix", ".", "--include=dev", "--save-prod", "--save-exact", "runtime-tool@latest" ]
    assert_includes commands, [ "npm", "install", "--prefix", ".", "--include=dev", "--save-dev", "--save-exact", "@scope/qa-tool@latest" ]
    assert_includes commands, [ "npm", "update", "--prefix", ".", "--include=dev", "--save-exact" ]
    cdn_commands = commands.select { |command| command.include?("config/mathjax") }
    assert_equal 2, cdn_commands.size
    assert cdn_commands.all? { |command| command.include?("--package-lock-only") && command.include?("--ignore-scripts") }
    assert_includes cdn_commands.first, "mathjax@latest"
    assert_includes cdn_commands.first, "--save-exact"

    assert_includes commands, [ "python3", "-m", "venv", ".venv-images" ]
    assert_includes commands, [ "image-python", "-m", "pip", "install", "--upgrade", "--upgrade-strategy", "eager", "Pillow" ]
    assert_equal REQUIREMENTS.sub("12.3.0", "12.4.0"), requirements
    assert_equal [
      [ "playwright", "install", "chromium", "firefox", "webkit" ],
      [ "image-python", "scripts/images/export.py", "--font-dir", @fonts ],
      [ "rails", "tailwindcss:build" ],
      [ "check" ]
    ], commands.last(4)
    assert_equal File.join(@repository, ".venv-images/bin/python"), calls.last.dig("env", "IMAGE_PYTHON")
    assert_equal @fonts, calls.last.dig("env", "IMAGE_FONT_DIR")
    assert_equal bundle.fetch("env").slice("BUNDLE_FROZEN", "BUNDLE_DEPLOYMENT", "BUNDLE_WITHOUT"), calls.last.fetch("env").slice("BUNDLE_FROZEN", "BUNDLE_DEPLOYMENT", "BUNDLE_WITHOUT")
  end

  test "help and invalid arguments never install or change dependencies" do
    [ [ "--help" ], [ "-h" ], [ "--unknown" ], [ "--help", "extra" ] ].each do |arguments|
      output, error, status = invoke(*arguments)
      assert_equal arguments.length == 1 && arguments.first != "--unknown", status.success?
      assert_includes output + error, "Usage: bin/update"
      assert_empty calls
      assert_equal REQUIREMENTS, requirements
    end
  end

  test "incorrect Ruby stops before invoking any dependency tools" do
    write_file(".ruby-version", "0.0.0\n")
    _output, error, status = invoke
    refute status.success?
    assert_includes error, "Activate Ruby 0.0.0"
    assert_empty calls
    assert_equal REQUIREMENTS, requirements
  end

  test "failed prerequisites stop before package upgrades" do
    [ [ "node" ], [ "npm", "--version" ], [ "bundle", "--version" ], [ "python3", "-c" ], [ "image-python", "-m", "pip", "--version" ] ].each do |failure|
      FileUtils.rm_f(@log)
      output, error, status = invoke(failure: failure)
      refute status.success?, failure.inspect
      assert_includes error, "Update stopped:"
      refute commands.any? { |command| command.include?("update") || command.include?("install") }, failure.inspect
      refute_includes output, "Dependencies upgraded and installed"
      assert_equal REQUIREMENTS, requirements
    end
  end

  test "a missing prerequisite stops before upgrading dependencies" do
    FileUtils.rm(File.join(@executables, "npm"))
    output, error, status = invoke
    refute status.success?
    assert_includes error, "Update stopped: npm --version"
    assert_equal [ "node" ], commands.map(&:first)
    refute_includes output, "Dependencies upgraded and installed"
  end

  test "missing image fonts stop before any dependency upgrade" do
    FileUtils.rm(File.join(@fonts, "DejaVuSans-Bold.ttf"))
    output, error, status = invoke
    refute status.success?
    assert_includes error, "Install DejaVu Sans fonts or set IMAGE_FONT_DIR"
    refute commands.any? { |command| command.include?("update") || command.include?("install") }
    assert_equal REQUIREMENTS, requirements
    refute_includes output, "Dependencies upgraded and installed"
  end

  test "failed installs or version discovery leave the image pin unchanged and stop subsequent work" do
    [ [ "bundle", "update" ], [ "npm", "install" ], [ "image-python", "-m", "pip", "install" ], [ "image-python", "-c", "import importlib.metadata" ] ].each do |failure|
      FileUtils.rm_f(@log)
      output, error, status = invoke(failure: failure)
      refute status.success?, failure.inspect
      assert_includes error, "Update stopped:"
      assert_equal REQUIREMENTS, requirements
      refute commands.any? { |command| [ "playwright", "rails", "check" ].include?(command.first) }
      refute_includes output, "Dependencies upgraded and installed"
    end
  end

  test "failed artifact generation prevents checks and a misleading success message" do
    output, error, status = invoke(failure: [ "image-python", "scripts/images/export.py" ])
    refute status.success?
    assert_includes error, "Update stopped:"
    assert_equal REQUIREMENTS.sub("12.3.0", "12.4.0"), requirements
    refute commands.any? { |command| [ "rails", "check" ].include?(command.first) }
    refute_includes output, "Dependencies upgraded and installed"
  end

  private

  def write_file(path, content)
    destination = File.join(@repository, path)
    FileUtils.mkdir_p(File.dirname(destination))
    File.write(destination, content)
  end

  def requirements
    File.read(File.join(@repository, "scripts/images/requirements.txt"))
  end

  def calls
    File.exist?(@log) ? File.readlines(@log).map { |line| JSON.parse(line) } : []
  end

  def commands
    calls.map { |call| call.fetch("command") }
  end

  def invoke(*arguments, failure: [])
    environment = {
      "PATH" => @executables, "IMAGE_PYTHON" => "python3", "IMAGE_FONT_DIR" => @fonts,
      "BUNDLE_FROZEN" => "true", "BUNDLE_DEPLOYMENT" => "true", "BUNDLE_WITHOUT" => "development:test",
      "UPDATE_TEST_LOG" => @log, "UPDATE_TEST_FAILURE" => JSON.generate(failure)
    }
    Bundler.with_unbundled_env do
      Open3.capture3(environment, RbConfig.ruby, File.join(@repository, "bin/update"), *arguments, chdir: @temporary)
    end
  end

  def write_stub(path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!#{RbConfig.ruby}\n" + <<~'RUBY')
      require "json"
      require "fileutils"
      tool = __FILE__.include?(".venv-images/") ? "image-python" : File.basename(__FILE__)
      command = [tool, *ARGV]
      File.open(ENV.fetch("UPDATE_TEST_LOG"), "a") do |file|
        file.puts JSON.generate(command: command, cwd: Dir.pwd, env: ENV.to_h.slice("BUNDLE_FROZEN", "BUNDLE_DEPLOYMENT", "BUNDLE_WITHOUT", "IMAGE_PYTHON", "IMAGE_FONT_DIR"))
      end
      failure = JSON.parse(ENV.fetch("UPDATE_TEST_FAILURE"))
      exit 1 if !failure.empty? && failure.each_with_index.all? { |argument, index| command[index]&.start_with?(argument) }
      if tool == "python3" && ARGV[0, 2] == ["-m", "venv"]
        destination = File.join(ARGV.fetch(2), "bin/python")
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(__FILE__, destination)
        File.chmod(0o755, destination)
      end
      puts JSON.generate("Pillow" => "12.4.0") if tool == "image-python" && ARGV.fetch(1, "").include?("importlib.metadata")
    RUBY
    File.chmod(0o755, path)
  end
end
