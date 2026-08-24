require "test_helper"

class ContentTagTaxonomyTest < ActiveSupport::TestCase
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
