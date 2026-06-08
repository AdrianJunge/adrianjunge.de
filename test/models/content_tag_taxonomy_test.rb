require "test_helper"

class ContentTagTaxonomyTest < ActiveSupport::TestCase
  test "canonicalizes redundant public tag labels" do
    assert_equal "Certificate", ContentTagTaxonomy.canonical_label("Certification")
    assert_equal "Web", ContentTagTaxonomy.canonical_label("Web Exploitation")
    assert_equal "Web", ContentTagTaxonomy.canonical_label("web")
    assert_equal "Pwn", ContentTagTaxonomy.canonical_label("PWN")
  end

  test "groups content types competitions repositories and categories separately" do
    groups = ContentTagTaxonomy.filter_groups(
      [ "CTF Competition", "CTF Team", "Security Research", "Slides", "DHM", "GPNCTF 2025", "Joomla CMS", "ChurchCRM", "Web Exploitation" ],
      ctf_labels: [ "DHM", "GPNCTF" ],
      repository_labels: [ "Joomla CMS", "ChurchCRM" ]
    )

    grouped_tags = groups.index_by { |group| group[:label] }.transform_values { |group| group[:tags] }

    assert_equal [ "CTF Competition", "CTF Team", "Security Research", "Slides" ], grouped_tags.fetch("Content type")
    assert_equal [ "DHM", "GPNCTF 2025" ], grouped_tags.fetch("CTF competitions")
    assert_equal [ "ChurchCRM", "Joomla CMS" ], grouped_tags.fetch("Repositories")
    assert_equal [ "Web" ], grouped_tags.fetch("Categories")
  end
end
