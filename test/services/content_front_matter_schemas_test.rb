require "test_helper"

class ContentFrontMatterSchemasTest < ActiveSupport::TestCase
  test "accepts documented and legacy author hint difficulty and optional formats" do
    cases = [
      { "authors" => [ "Name", { "name" => "Other", "url" => "https://example.com" }, { "name" => nil, "url" => nil } ] },
      { "author" => "First, Second", "author_urls" => { "First" => "/about", "Second" => nil } },
      { "article_authors" => [ "Writer", { "name" => "Coauthor", "urls" => [ "https://example.com", "/about" ] } ] },
      { "article_authors" => { "name" => "Writer", "url" => "/about" } },
      { "article_authors" => "Writer" },
      { "hints" => "A single hint", "difficulty" => "unknown difficulty" },
      { "optional" => { "hints" => [ "A hint", { "text" => "Another" }, { "hint" => "Third" } ], "difficulty" => { "label" => "Hard" } } },
      { "optional" => { "authored_challenge" => true, "writeup_winner" => { "label" => "Winner", "proof_url" => "/proof.pdf" } } },
      { "authored-challenge" => { "event" => "ExampleCTF", "published" => 2025 }, "winner" => "https://example.com/proof" }
    ]
    cases.each { |values| assert_empty errors(values), values.inspect }
  end

  test "reports malformed nested fields instead of coercing them into display strings" do
    {
      { "authors" => "Name" } => "/authors",
      { "authors" => [ { "name" => 42 } ] } => "/authors/0/name",
      { "article_authors" => [ { "name" => " " } ] } => "/article_authors/0/name",
      { "optional" => [] } => "/optional",
      { "optional" => { "hints" => [ { "text" => 42 } ] } } => "/optional/hints/0/text",
      { "optional" => { "difficulty" => { "label" => [] } } } => "/optional/difficulty/label",
      { "categories" => [ { "name" => "Web" } ] } => "/categories/0",
      { "author_links" => [] } => "/author_links"
    }.each do |values, pointer|
      assert_includes errors(values).map { |error| error["data_pointer"] }, pointer, values.inspect
    end
  end

  test "author URL maps and arrays use the same URL policy as direct links" do
    values = {
      "author_links" => { "First/Name" => "ftp://example.com" },
      "article_authors" => [ { "name" => "Writer", "urls" => [ "data:text/plain,hello" ] } ]
    }
    pointers = errors(values).map { |error| error["data_pointer"] }
    assert_includes pointers, "/author_links/First~1Name"
    assert_includes pointers, "/article_authors/0/urls/0"
  end

  test "article requirements are independent of catalogs and About does not need publication date" do
    pointers = ContentFrontMatterSchemas.errors_for({}).map { |error| error["data_pointer"] }
    assert_equal %w[/title /description /published], pointers
    assert_empty ContentFrontMatterSchemas.errors_for({ "title" => "About", "description" => "Profile" }, about: true)
  end

  test "reader summaries remain optional plain text metadata" do
    assert_empty errors("reader_summary" => "Notes on a challenge and its solution.")
    assert_includes errors("reader_summary" => []).pluck("data_pointer"), "/reader_summary"
    assert_includes errors("reader_summary" => " ").pluck("data_pointer"), "/reader_summary"
  end

  private

  def errors(values)
    ContentFrontMatterSchemas.errors_for({ "title" => "A post", "description" => "Summary", "published" => "2026-09-26" }.merge(values))
  end
end
