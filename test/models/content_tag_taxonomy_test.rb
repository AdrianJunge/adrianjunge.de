require "test_helper"

class ContentTagTaxonomyTest < ActiveSupport::TestCase
  test "typed severity and difficulty retain distinct identities and readable labels" do
    assert_equal "Medium", ContentTagTaxonomy.canonical_label("difficulty:medium")
    assert_equal "Medium", ContentTagTaxonomy.canonical_label("severity:medium")
    assert_equal "difficulty:medium", ContentTagTaxonomy.canonical_value("Medium")
    assert_equal "severity:medium", ContentTagTaxonomy.canonical_value("Medium", type: :severity)
    assert_equal [ "difficulty:medium", "severity:medium" ], ContentTagTaxonomy.canonical_values([ "Medium", "difficulty:medium", "severity:medium" ])
    groups = ContentTagTaxonomy.filter_groups([ "difficulty:medium", "severity:medium" ]).index_by { |group| group[:sort] }
    assert_equal [ "difficulty:medium" ], groups.fetch("difficulty")[:tags]
    assert_equal [ "severity:medium" ], groups.fetch("severity")[:tags]
  end

  test "canonicalizes redundant public tag labels" do
    assert_equal "Certificate", ContentTagTaxonomy.canonical_label("Certification")
    assert_equal "Algorithms", ContentTagTaxonomy.canonical_label("Algorithm")
    assert_equal "Web", ContentTagTaxonomy.canonical_label("Web Exploitation")
    assert_equal "Web", ContentTagTaxonomy.canonical_label("web")
    assert_equal "Pwn", ContentTagTaxonomy.canonical_label("PWN")
  end

  test "groups content types competitions repositories and categories separately" do
    groups = ContentTagTaxonomy.filter_groups(
      [ "CTF Competition", "CTF Team", "Security Research", "Algorithms", "Slides", "Alpha League", "BetaCTF 2099", "Repository One", "Repository Two", "Web Exploitation" ],
      ctf_labels: [ "Alpha League", "BetaCTF" ],
      repository_labels: [ "Repository One", "Repository Two" ]
    )

    grouped_tags = groups.index_by { |group| group[:label] }.transform_values { |group| group[:tags] }

    assert_equal [ "Algorithms", "CTF Competition", "CTF Team", "Security Research", "Slides" ], grouped_tags.fetch("Content type")
    assert_equal [ "Alpha League", "BetaCTF 2099" ], grouped_tags.fetch("CTF competitions")
    assert_equal [ "Repository One", "Repository Two" ], grouped_tags.fetch("Repositories")
    assert_equal [ "Web" ], grouped_tags.fetch("Categories")
  end
end
