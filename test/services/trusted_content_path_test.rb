require "test_helper"
require "tmpdir"

class TrustedContentPathTest < ActiveSupport::TestCase
  test "returns the canonical path for a regular file below the trusted root" do
    Dir.mktmpdir do |directory|
      root = Pathname(directory).join("content")
      file = root.join("nested", "post.md")
      file.dirname.mkpath
      file.write("published content")

      assert_equal file.realpath, TrustedContentPath.file(root: root, candidate: file)
    end
  end

  test "rejects traversal and sibling paths" do
    Dir.mktmpdir do |directory|
      base = Pathname(directory)
      root = base.join("content")
      sibling = base.join("content-private", "secret.md")
      root.mkpath
      sibling.dirname.mkpath
      sibling.write("secret")

      assert_nil TrustedContentPath.file(root: root, candidate: root.join("..", "content-private", "secret.md"))
      assert_nil TrustedContentPath.file(root: root, candidate: sibling)
    end
  end

  test "rejects a symlink that resolves outside the trusted root" do
    Dir.mktmpdir do |directory|
      base = Pathname(directory)
      root = base.join("content")
      secret = base.join("secret.md")
      link = root.join("linked.md")
      root.mkpath
      secret.write("secret")
      File.symlink(secret, link)

      assert_nil TrustedContentPath.file(root: root, candidate: link)
    end
  end

  test "rejects missing files" do
    Dir.mktmpdir do |directory|
      root = Pathname(directory).join("content")
      root.mkpath

      assert_nil TrustedContentPath.file(root: root, candidate: root.join("missing.md"))
    end
  end
end
