require "test_helper"
require "tmpdir"

class ContentValidatorTest < ActiveSupport::TestCase
  test "Markdown images report missing local paths without fetching remote sources" do
    validator = ContentValidator.new
    errors = validator.markdown_image_errors(<<~MARKDOWN, path: "sample.md")
      ![Missing](blog/definitely-missing.png)
      ![Existing](other/certificate.svg)
      ![Remote](https://images.example.invalid/never-requested.png)
      <img src="blog/also-missing.png" alt="Raw HTML image">
      ```html
      <img src="example-code-only.png">
      ```
    MARKDOWN
    assert_equal [
      'sample.md: missing local Markdown image "blog/definitely-missing.png"',
      'sample.md: missing local Markdown image "blog/also-missing.png"'
    ], errors
  end

  test "the shipped catalog passes the authoring workflow" do
    result = ContentValidator.new.call
    assert result.valid?, result.errors.join("\n")
    assert_operator result.documents, :>, 0
  end

  test "configuration roots include About and require complete article front matter" do
    with_content_root do |configuration|
      post = configuration.path(:BLOG_BASE_PATH).join("post.md")
      post.write("---\ndescription: Summary\npublished: '2026-09-26'\n---\nBody")
      about = configuration.path(:ABOUTME_TEXT_PATH)
      about.write("---\ntitle: About\n---\n![Missing](about/missing.png)")

      result = ContentValidator.new(configuration: configuration).call
      assert_includes result.errors, "#{post}/title: required"
      assert_includes result.errors, "#{about}/description: required"
      assert_includes result.errors, "#{about}: missing local Markdown image \"about/missing.png\""
    end
  end

  test "missing required documents and catalogs have their actual source paths" do
    with_content_root do |configuration|
      about = configuration.path(:ABOUTME_TEXT_PATH)
      catalog = configuration.path(:ABOUTME_TALKS_PATH)
      about.delete
      catalog.delete

      result = ContentValidator.new(configuration: configuration).call
      assert_includes result.errors, "#{about}: required content file is missing"
      assert_includes result.errors, "#{catalog}: required content file is missing"
    end
  end

  test "invalid optional fields report source properties before indexing" do
    with_content_root do |configuration|
      post = configuration.path(:BLOG_BASE_PATH).join("post.md")
      post.write("---\ntitle: Post\ndescription: Summary\npublished: '2026-09-26'\noptional: []\narticle_authors:\n  - name: 42\n---\nBody")
      result = ContentValidator.new(configuration: configuration).call

      assert result.errors.any? { |error| error.start_with?("#{post}/optional:") }
      assert result.errors.any? { |error| error.start_with?("#{post}/article_authors/0/name:") }
    end
  end

  test "discovered blog articles work without a catalog and CTF legacy paths remain consistent" do
    with_content_root do |configuration|
      repository = ContentRepository.new(configuration: configuration)
      result = ContentValidator.new(repository: repository).call
      assert result.valid?, result.errors.join("\n")
      assert_equal 2, result.documents

      ctf_catalog = configuration.path(:CTF_INFO_PATH)
      ctf_catalog.write(JSON.generate("Event" => {
        "logo" => "event.svg", "website" => "https://example.com", "description" => "Event", "writeups" => "/ctf/wrong"
      }))
      result = ContentValidator.new(configuration: configuration).call
      assert_includes result.errors, "#{ctf_catalog}/Event/writeups: must match derived path /ctf/event"
    end
  end

  test "all discovered blog filenames and draft front matter are validated" do
    with_content_root do |configuration|
      root = configuration.path(:BLOG_BASE_PATH)
      draft = root.join("draft-post.md")
      draft.write("---\ntitle: Draft\ndescription: Work in progress\ndraft: true\n---\nBody")
      invalid_name = root.join("Draft Notes.md")
      invalid_name.write("---\ntitle: Draft\ndescription: Work in progress\npublished: '2026-09-26'\nhidden: true\n---\nBody")

      result = ContentValidator.new(configuration: configuration).call
      assert_includes result.errors, "#{draft}/published: required"
      assert result.errors.any? { |error| error.start_with?("#{invalid_name}: invalid blog filename slug") }
      assert_equal 4, result.documents
    end
  end

  test "a Markdown directory is reported before attempting to parse it" do
    with_content_root do |configuration|
      root = configuration.path(:BLOG_BASE_PATH)
      directory = root.join("not-a-post.md")
      directory.mkpath

      result = ContentValidator.new(configuration: configuration).call
      assert_includes result.errors, "#{directory}: blog Markdown must be a file within #{root}"
      assert_equal 2, result.documents
    end
  end

  test "local image checks use the configured root and validation can be repeated" do
    with_content_root do |configuration|
      post = configuration.path(:BLOG_BASE_PATH).join("post.md")
      post.write("---\ntitle: Post\ndescription: Summary\npublished: '2026-09-26'\nlogo: custom/logo.svg\n---\n![Example](custom/logo.svg)")
      validator = ContentValidator.new(configuration: configuration)
      result = validator.call
      assert_includes result.errors, "#{post}/logo: missing local image \"custom/logo.svg\""
      image = configuration.root.join("app/assets/images/custom/logo.svg")
      image.dirname.mkpath
      image.write('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>')
      result = validator.call
      assert result.valid?, result.errors.join("\n")
      assert_equal 2, result.documents
    end
  end

  private

  def with_content_root
    Dir.mktmpdir("content-validation") do |root|
      configuration = ContentConfiguration.new(root: root)
      %i[ABOUTME_BASE_PATH BLOG_BASE_PATH BASE_PATH CTF_CHALLENGE_FILES_PATH CTF_PDF_WRITEUPS_PATH].each do |name|
        configuration.path(name).mkpath
      end
      ContentJsonSchemas.registered_paths.each do |schema_path|
        path = configuration.resolve(schema_path)
        path.dirname.mkpath
        path.write(ContentJsonSchemas::ARRAY_SCHEMAS.key?(schema_path) ? "[]" : "{}")
      end
      configuration.path(:BLOG_BASE_PATH).join("post.md").write("---\ntitle: Post\ndescription: Summary\npublished: '2026-09-26'\n---\nBody")
      configuration.path(:ABOUTME_TEXT_PATH).write("---\ntitle: About\ndescription: Profile\n---\nBiography")
      yield configuration
    end
  end
end
