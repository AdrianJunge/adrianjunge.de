require "test_helper"

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
end
