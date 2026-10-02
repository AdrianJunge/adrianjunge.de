require "test_helper"
require_relative "../../scripts/update_wkd"

class UpdateWkdTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir("wkd-publisher-test-"))
    FileUtils.mkdir_p(@root.join("public"))
    @source = @root.join("public/pgp-vurlo.asc")
    FileUtils.cp(Rails.root.join("public/pgp-vurlo.asc"), @source)
    @publisher = WkdPublisher.new(root: @root)
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  test "the hash follows the specification's reference vector and ASCII case folding" do
    assert_equal "iy9q119eutrkn8s1mk4r39qejnbu3n5q", WkdPublisher.new(root: @root, email: "Joe.Doe@Example.ORG").hash
    assert_equal "53a3k6s45xb3w5niiaq14mjsf1xeuoz3", @publisher.hash
    assert_equal @publisher.hash, WkdPublisher.new(root: @root, email: "STDIN@other.example").hash
  end

  test "a public export generates reproducible WKD files without changing the source" do
    original = @source.binread
    result = @publisher.run
    assert_equal "1C348AC759687D9C32416BCE3CD0CC82CAC02D2F", result[:fingerprint]
    assert_equal result, @publisher.run(check: true)
    assert_equal original, @source.binread
    assert_equal File.binread(Rails.root.join("public/.well-known/openpgpkey/hu", result[:hash])), key_path.binread
    assert_equal key_path.binread, key_path(advanced: true).binread
    [ false, true ].each { |advanced| assert key_path(advanced: advanced).dirname.parent.join("policy").zero? }
  end

  test "checking detects a stale binary or missing policy and regeneration repairs them" do
    @publisher.run
    [ false, true ].each do |advanced|
      path = key_path(advanced: advanced)
      path.binwrite("stale")
      error = assert_raises(WkdPublisher::Failure) { @publisher.run(check: true) }
      assert_includes error.message, "stale"
      @publisher.run
      path.delete
      assert_raises(WkdPublisher::Failure) { @publisher.run(check: true) }
      @publisher.run
      path.dirname.parent.join("policy").delete
      assert_raises(WkdPublisher::Failure) { @publisher.run(check: true) }
      @publisher.run
    end
    assert @publisher.run(check: true)
  end

  test "checking refuses unintended extra public WKD files" do
    @publisher.run
    [ false, true ].each do |advanced|
      extra = key_path(advanced: advanced).dirname.join("unexpected.asc")
      extra.write("unintended public file")
      assert_raises(WkdPublisher::Failure) { @publisher.run(check: true) }
      extra.delete
    end
    @root.join("public/.well-known/openpgpkey/another.example").mkdir
    assert_raises(WkdPublisher::Failure) { @publisher.run(check: true) }
  end

  test "an identity not signed into the source cannot be published" do
    publisher = WkdPublisher.new(root: @root, email: "missing@adrianjunge.de")
    assert_raises(WkdPublisher::Failure) { publisher.run }
    assert_not @root.join("public/.well-known/openpgpkey").exist?
  end

  test "private key armor is refused before any public files are generated" do
    @source.write("-----BEGIN PGP PRIVATE KEY BLOCK-----\n")
    error = assert_raises(WkdPublisher::Failure) { @publisher.run }
    assert_includes error.message, "public key export"
    assert_not @root.join("public/.well-known/openpgpkey").exist?
  end

  private

  def key_path(advanced: false)
    directory = @root.join("public/.well-known/openpgpkey")
    directory = directory.join("adrianjunge.de") if advanced
    directory.join("hu", @publisher.hash)
  end
end
