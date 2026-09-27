require "test_helper"

class ArticleAuthorTest < ActiveSupport::TestCase
  test "missing attribution defaults to the configured site author" do
    [ nil, [], "", [ { name: " " } ] ].each do |value|
      assert_equal [ SiteProfile.author ], ArticleAuthor.normalize(value)
    end
  end

  test "legacy and structured attribution share one normalized shape" do
    assert_equal [ { name: "Guest" } ], ArticleAuthor.normalize("Guest")
    assert_equal [ { name: "Guest", url: "https://example.org/guest" } ],
                 ArticleAuthor.normalize(name: "Guest", urls: [ "https://example.org/guest" ])
    assert_equal [ { name: "Adrian Junge", url: SiteProfile.absolute_url("/about") }, { name: "Guest" } ],
                 ArticleAuthor.normalize([ { "name" => "  Adrian   Junge ", "url" => "/about" }, "Guest", "guest" ])
  end

  test "attribution text is plain and unusable author links become text" do
    authors = ArticleAuthor.normalize([
      { name: "<b>Guest</b>", url: "javascript:alert(1)" },
      { name: "Second", url: "//example.org" },
      { name: "Third", url: "https://user:password@example.org/" }
    ])
    assert_equal %w[Guest Second Third].map { |name| { name: name } }, authors
  end

  test "author links use the same accepted formats as metadata validation" do
    [ " /about", "/guest profile", "https://example.org/guest " ].each do |url|
      assert_equal [ { name: "Guest" } ], ArticleAuthor.normalize(name: "Guest", url: url)
    end
    assert_equal [ { name: "Guest", url: "#{SiteProfile.origin}/#guest" } ], ArticleAuthor.normalize(name: "Guest", url: "#guest")
  end
end
