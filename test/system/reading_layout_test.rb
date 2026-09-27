require "application_system_test_case"
require_relative "../support/site_page_helpers"

class ReadingLayoutTest < ApplicationSystemTestCase
  include SitePageHelpers

  test "article prose keeps its measure with desktop and compact contents while media stays wide" do
    [ first_blog_post[:link], first_ctf_post[:link] ].each do |path|
      [ 1440, 1280, 390, 320 ].each do |width|
        page.current_window.resize_to(width, 1200)
        visit path
        assert_selector ".writeup-container > .markdown-content"
        # A neutral layout fixture covers every supported prose/media element
        # without depending on which editorial article currently contains them.
        page.execute_script(<<~JS)
          const body = document.querySelector('.writeup-container > .markdown-content');
          body.insertAdjacentHTML('beforeend', '<h2 data-reading-probe>Readable heading</h2><p data-reading-probe>Readable paragraph.</p><ul data-reading-probe><li>Readable list.</li></ul><ol data-reading-probe><li>Readable sequence.</li></ol><blockquote data-reading-probe><p>Readable quotation.</p></blockquote><div class="code-block" data-wide-probe style="width:100%"><pre class="highlight" style="width:100%"><code>Wide code sample.</code></pre></div><table data-wide-probe style="width:100%"><tbody><tr><td>Wide table.</td></tr></tbody></table><figure class="markdown-figure" data-wide-probe style="width:100%"><svg aria-label="Wide diagram" width="100%" height="20"></svg></figure>');
        JS
        assert_reading_measure(width)
        if width > 1400
          find("#toc-toggle").click
          assert_selector ".writeup-wrapper.toc-collapsed"
          assert_reading_measure(width)
        elsif width == 1280
          find(".article-toc-compact > summary").click
          assert_selector ".article-toc-compact[open]"
          assert_reading_measure(width)
        end
      end
    end
  end

  private

  def assert_reading_measure(width)
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const body = document.querySelector('.writeup-container > .markdown-content');
        const context = document.createElement('canvas').getContext('2d');
        context.font = getComputedStyle(body).font;
        const character = context.measureText('0').width;
        const prose = [...body.querySelectorAll(':scope > [data-reading-probe]')].map(node => ({ width: node.getBoundingClientRect().width, left: node.getBoundingClientRect().left }));
        const wide = [...body.querySelectorAll(':scope > [data-wide-probe]')].map(node => node.getBoundingClientRect().width);
        const descriptions = [...document.querySelectorAll('.article-description')].map(section => {
          const style = getComputedStyle(section);
          return { width: section.querySelector('p').getBoundingClientRect().width, available: section.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight) };
        });
        return { prose, wide, character, descriptions, available: body.getBoundingClientRect().width, overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth };
      })()
    JS
    prose_width = metrics["prose"].first.fetch("width")
    metrics["prose"].each do |element|
      assert_operator element["width"], :<=, 90.1 * metrics["character"]
      assert_in_delta prose_width, element["width"], 1
      assert_in_delta metrics["prose"].first.fetch("left"), element["left"], 1
    end
    metrics["wide"].each { |media_width| assert_in_delta metrics["available"], media_width, 1 }
    metrics["descriptions"].each { |description| assert_in_delta description["available"], description["width"], 1 }
    if width >= 1280
      minimum_desktop_width = [ 89 * metrics["character"], metrics["available"] ].min
      assert_operator prose_width, :>=, minimum_desktop_width - 1
    end
    assert_operator metrics["available"], :>, prose_width + 20 if width == 1280
    assert_operator metrics["overflow"], :<=, 1
  end
end
