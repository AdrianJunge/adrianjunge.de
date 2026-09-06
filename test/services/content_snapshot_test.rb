require "test_helper"
require "tmpdir"

class ContentSnapshotTest < ActiveSupport::TestCase
  test "snapshot growth is bounded and recently accessed entries survive eviction" do
    ContentSnapshot.clear
    Dir.mktmpdir("content-snapshot-limit") do |directory|
      files = (ContentSnapshot::LIMIT + 1).times.map do |index|
        Pathname(directory).join("#{index}.txt").tap { |file| file.write("entry #{index}") }
      end
      load = ->(path) { ContentSnapshot.fetch(path) { |text| text } }
      files.first(ContentSnapshot::LIMIT).each { |path| load.call(path) }
      first = load.call(files.first)
      load.call(files.last)
      assert_equal ContentSnapshot::LIMIT, ContentSnapshot.size
      assert_same first, load.call(files.first)
      rebuilt = false
      ContentSnapshot.fetch(files.second) { |text| rebuilt = true; text }
      assert rebuilt, "least recently used entry should be rebuilt after eviction"
    end
  ensure
    ContentSnapshot.clear
  end

  test "repeated reads reuse immutable documents and edits replace them" do
    Dir.mktmpdir("content-snapshot") do |directory|
      path = Pathname(directory).join("post.md")
      path.write("---\ntitle: First\npublished: '2026-09-05'\n---\nBody\n")
      repository = ContentRepository.new
      first = repository.markdown_document(path)
      assert_same first, ContentRepository.new.markdown_document(path)
      assert_equal "Body\n", first[:body]
      assert_raises(FrozenError) { first[:metadata]["title"].replace("Changed") }

      path.write("---\ntitle: Second\npublished: '2026-09-05'\n---\nRevised\n")
      second = ContentRepository.new.markdown_document(path)
      assert_not_same first, second
      assert_equal "Second", second[:metadata]["title"]
      assert_equal "First", first[:metadata]["title"]

      path.delete
      assert_equal "", ContentSnapshot.fetch(path) { |content| content }
    end
  end

  test "parallel readers share coherent snapshots and JSON consumers receive copies" do
    Dir.mktmpdir("content-snapshot") do |directory|
      path = Pathname(directory).join("metadata.json")
      path.write('{"entry":{"title":"Shared"}}')
      results = 6.times.map do
        Thread.new { ContentRepository.new.read_json_object(path) }
      end.map(&:value)
      assert results.all? { |result| result == { "entry" => { "title" => "Shared" } } }
      results.first["entry"]["title"].replace("Changed")
      assert_equal "Shared", ContentRepository.new.read_json_object(path).dig("entry", "title")
    end
  end
end
