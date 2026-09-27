require "test_helper"
require "tmpdir"

class ArticleDetoursTest < ActiveSupport::TestCase
  test "a mistyped article path suggests its real title and published URL" do
    service = service_for(blogs: [ article("Java Strings", "java-strings"), article("Climbing Stairs", "climbing-stairs") ])

    assert_equal [ { title: "Java Strings", url: "/blog/java-strings" } ], service.call("/blog/jvaa-strngs")[:suggestions]
    assert_equal "/blog/climbing-stairs", service.call("/blog/climbng-stairs")[:suggestions].first[:url]
    assert_equal "/blog/java-strings", service.call("/blog/j%C3%A1va-strings")[:suggestions].first[:url]
    long_title = article("A lengthy article title with enough separate words to fill the title budget", "fibonacci")
    assert_equal "/blog/fibonacci", service_for(blogs: [ long_title ]).call("/blog/fibonaci")[:suggestions].first[:url]
  end

  test "suggestions use only titles and slugs and stay bounded and deterministically ranked" do
    posts = [ article("An unrelated article", "unrelated", body: "quasarneedle") ] +
      Array.new(5) { |index| article("Quasar #{index}", "quasar-#{index}") }
    result = service_for(blogs: posts).call("/blog/quasar")

    assert_equal [ "Quasar 0", "Quasar 1", "Quasar 2" ], result[:suggestions].pluck(:title)
    assert_empty service_for(blogs: posts).call("/blog/quasarneedle")[:suggestions]
    assert result[:suggestions].all? { |suggestion| suggestion.keys.sort == %i[title url] }
  end

  test "an unrelated path or explicit 404 has only the random published article fallback" do
    writeup = article("A CTF puzzle", "puzzle", url: "/ctf/demo/puzzle", type: "ctf")
    service = service_for(blogs: [ article("Java Strings", "java-strings") ], writeups: [ writeup ])

    [ "/missing-constellation", "/404", "/unknown?java=strings#java" ].each do |path|
      result = service.call(path)
      assert_empty result[:suggestions], path
      assert_includes [ "/blog/java-strings", "/ctf/demo/puzzle" ], result[:random_article][:url]
    end
  end

  test "every published blog post and CTF writeup has one slot in the same random pool" do
    blogs = [ article("Java Strings", "java-strings"), article("Climbing Stairs", "climbing-stairs") ]
    writeups = [ article("A CTF puzzle", "puzzle", url: "/ctf/demo/puzzle", type: "ctf") ]
    repository = Struct.new(:blog_posts, :ctf_posts).new(blogs, writeups)
    pool = blogs + writeups

    pool.each_with_index do |post, index|
      limits = []
      random = Object.new
      random.define_singleton_method(:rand) { |limit| limits << limit; index }

      result = ArticleDetours.new(repository: repository, random: random).call("/404")

      assert_equal [ pool.length ], limits
      assert_equal({ title: post[:metadata]["title"], url: post[:link], type: post[:type] }, result[:random_article])
    end
  end

  test "empty collections and unexpected path values have an empty recovery result" do
    service = service_for
    [ nil, [], {}, "", "/", "/%", "/\xFF".b, "/" + "a" * 50_000 ].each do |path|
      assert_equal({ suggestions: [], random_article: nil }, service.call(path))
    end
    service = service_for(blogs: [ article("Java Strings", "java-strings") ])
    assert_empty service.call("/" + "a" * 512 + "/java-strings")[:suggestions]
  end

  test "hidden writeups and hidden parent events never become recovery destinations" do
    repository = fixture_content_repository
    service = ArticleDetours.new(repository: repository, random: Random.new(42))
    public_urls = (repository.blog_posts + repository.ctf_posts).pluck(:link)

    %w[/ctf/democtf/Hidden /ctf/hiddenctf/Leaked].each do |path|
      result = service.call(path)
      assert_empty result[:suggestions]
      assert_includes public_urls, result[:random_article][:url]
      assert_not_includes result.to_json, "Hidden"
      assert_not_includes result.to_json, "Leaked"
    end
  end

  test "a requested draft filename cannot bypass the published repository collections" do
    Dir.mktmpdir("article-detours") do |directory|
      blogs = Pathname(directory).join("blog").tap(&:mkpath)
      writeups = Pathname(directory).join("ctf").tap(&:mkpath)
      blogs.join("private-draft.md").write("---\ntitle: Private draft\ndraft: true\n---\nUnpublished notes.")
      repository = ContentRepository.new(blog_base_path: blogs, ctf_base_path: writeups, ctf_metadata_data: {})
      repository.define_singleton_method(:blog_post) { |*| raise "Recovery must not look up the requested file" }

      result = ArticleDetours.new(repository: repository).call("/blog/private-draft")
      assert_equal({ suggestions: [], random_article: nil }, result)
    end
  end

  private

  def service_for(blogs: [], writeups: [])
    repository = Struct.new(:blog_posts, :ctf_posts).new(blogs, writeups)
    ArticleDetours.new(repository: repository, random: Random.new(42))
  end

  def article(title, slug, url: "/blog/#{slug}", body: "", type: "blog")
    { slug: slug, link: url, metadata: { "title" => title }, body: body, type: type }
  end
end
