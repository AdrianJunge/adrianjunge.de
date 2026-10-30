require "application_system_test_case"

class ChallengeAuthorsTest < ApplicationSystemTestCase
  test "multi-author challenge credit stays centered between title and details at mobile and desktop widths" do
    [ 320, 390, 1440 ].each do |width|
      page.current_window.resize_to(width, 1000)

      visit "/ctf/ehax"
      assert_author_layout(:card, width)

      visit "/ctf/ehax/Fantastic%20Doom"
      assert_author_layout(:article, width)
    end
  end

  test "writeups without a challenge author omit the credit on cards and articles" do
    with_stubbed_content_repository(fixture_content_repository) do
      visit "/ctf/democtf"
      within find(".writeup-post-card", text: "Middle Writeup") do
        assert_no_selector ".blog-post-authors"
      end

      visit "/ctf/democtf/Middle"
      assert_selector ".writeup-title", text: "Middle Writeup"
      assert_no_selector ".writeup-authors-article"
    end
  end

  private

  def assert_author_layout(surface, width)
    card = surface == :card
    selector = card ? ".writeup-overview .writeup-post-card" : ".writeup-container"
    assert_selector "#{selector} .blog-post-authors", text: /Challenge by\s+nrg\s*,\s*the_moon_guy/

    layout = page.evaluate_script(<<~JS)
      (() => {
        const card = #{card};
        const panel = card
          ? [...document.querySelectorAll(".writeup-overview .writeup-post-card")]
              .find(node => node.querySelector(".blog-post-title")?.textContent.trim() === "Fantastic Doom")
          : document.querySelector(".writeup-container");
        const title = panel.querySelector(card ? ".blog-post-title" : ".writeup-title");
        const authors = panel.querySelector(".blog-post-authors");
        const following = panel.querySelector(card ? ".blog-post-meta-row" : ".post-meta-line");
        const authorList = authors.querySelector(".content-author-list");
        const links = [...authorList.querySelectorAll("a")];
        authors.scrollIntoView({ block: "center", inline: "nearest" });

        const textRange = document.createRange();
        textRange.selectNodeContents(authors);
        const textRect = textRange.getBoundingClientRect();
        const panelRect = panel.getBoundingClientRect();
        const titleRect = title.getBoundingClientRect();
        const authorsRect = authors.getBoundingClientRect();
        const followingRect = following.getBoundingClientRect();
        const commaNode = [...authorList.childNodes]
          .find(node => node.nodeType === Node.TEXT_NODE && node.textContent.includes(","));
        const commaRange = document.createRange();
        const commaOffset = commaNode.textContent.indexOf(",");
        commaRange.setStart(commaNode, commaOffset);
        commaRange.setEnd(commaNode, commaOffset + 1);

        return {
          text: authors.textContent.replace(/\\s+/g, " ").trim(),
          centeredBy: (textRect.left + textRect.right - panelRect.left - panelRect.right) / 2,
          titleBeforeAuthors: Boolean(title.compareDocumentPosition(authors) & Node.DOCUMENT_POSITION_FOLLOWING),
          authorsBeforeDetails: Boolean(authors.compareDocumentPosition(following) & Node.DOCUMENT_POSITION_FOLLOWING),
          titleToAuthors: authorsRect.top - titleRect.bottom,
          authorsToDetails: followingRect.top - authorsRect.bottom,
          commaGap: commaRange.getBoundingClientRect().left - links[0].getBoundingClientRect().right,
          links: links.map(link => {
            const rect = link.getBoundingClientRect();
            return {
              name: link.textContent.trim(),
              href: link.href,
              height: rect.height,
              hit: document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2)?.closest("a") === link
            };
          }),
          horizontalOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth
        };
      })()
    JS

    context = "#{surface} at #{width}px"
    assert_equal "Challenge by nrg, the_moon_guy", layout["text"], context
    assert_in_delta 0, layout["centeredBy"], 2, "#{context}: center the full credit text in its card/article"
    assert_equal true, layout["titleBeforeAuthors"], context
    assert_equal true, layout["authorsBeforeDetails"], context
    assert_operator layout["titleToAuthors"], :>=, -1, context
    assert_operator layout["titleToAuthors"], :<, 32, context
    assert_operator layout["authorsToDetails"], :>=, -1, context
    assert_operator layout["authorsToDetails"], :<, 32, context
    assert_operator layout["commaGap"], :>, 3, "#{context}: retain the spacing before the comma"
    assert_equal [ "nrg", "the_moon_guy" ], layout["links"].map { |link| link["name"] }, context
    assert_equal [ "https://app.intigriti.com/profile/nrg", "https://github.com/mayank-jangid-moon" ],
                 layout["links"].map { |link| link["href"] }, context
    assert layout["links"].all? { |link| link["height"] >= 32 && link["hit"] },
           "#{context}: both author links need clickable 32px hitboxes"
    assert_equal false, layout["horizontalOverflow"], context
  end
end
