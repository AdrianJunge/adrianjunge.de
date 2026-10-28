require "test_helper"

class SiteSearchPassagesTest < ActiveSupport::TestCase
  test "passages preserve inline text but separate blocks badges and dates" do
    html = <<~HTML
      <h3>Same <i>project</i></h3>
      <span class="aboutme-card-tag">High</span>
      <span class="aboutme-card-tag">CVE-2026-1234</span>
      <p>Look at <code>in_array</code> and <strong>preserve</strong> punctuation.</p>
      <li><time>2026-10-28</time><span class="aboutme-timeline-title">Published</span></li>
      <button>Expose</button><span hidden>Hidden</span><svg><title>Decorative</title></svg>
    HTML
    assert_equal [ "Same project", "High", "CVE-2026-1234", "Look at in_array and preserve punctuation.", "2026-10-28", "Published" ],
      SiteSearchPassages.extract(html)
  end

  test "author links and unlinked names retain their separate flex boundaries and commas" do
    html = <<~HTML
      <div class="article-meta-row-value">
        <a class="blog-post-author-link" href="https://example.com/one">First Author</a>,
        <span class="blog-post-author-name">Second Author</span>,
        <a class="blog-post-author-link" href="https://example.com/three">Third Author</a>
      </div>
    HTML
    assert_equal [ "First Author", ",", "Second Author", ",", "Third Author" ], SiteSearchPassages.extract(html)
  end
end
