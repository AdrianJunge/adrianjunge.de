require "test_helper"

class ContentFiltersPresenterTest < ActiveSupport::TestCase
  test "common filters fill remaining slots after matching preferred tags" do
    presenter = ContentFiltersPresenter.new(scope: "blogs", tag_groups: [
      { label: "Content type", tags: [ "Blog post", "Algorithms", "Security Research" ] },
      { label: "Topics", tags: [ "Web" ] }
    ])

    assert_equal [ "Blog post", "Algorithms", "Security Research" ], presenter.common_group[:tags]
    assert_equal [ "Topics" ], presenter.additional_groups.pluck(:label)
    assert_equal [ "Web" ], presenter.additional_groups.first[:tags]
  end

  test "common filters remain capped without duplicating additional filters" do
    tags = [ "Blog post", "CTF writeup", "CVE", "Certificate", "Talk", "Algorithms", "Security Research", "CTF Competition" ]
    presenter = ContentFiltersPresenter.new(scope: "timeline", tag_groups: [ { label: "Content type", tags: tags } ])

    assert_equal 6, presenter.common_group[:tags].length
    assert_equal [ "Blog post", "CTF writeup", "CVE", "Certificate", "Talk" ], presenter.common_group[:tags].first(5)
    remaining = presenter.additional_groups.flat_map { |group| group[:tags] }
    assert_empty presenter.common_group[:tags] & remaining
    assert_equal tags.sort, (presenter.common_group[:tags] + remaining).sort
  end
end
