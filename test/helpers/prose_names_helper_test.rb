require "test_helper"

class ProseNamesHelperTest < ActionView::TestCase
  test "escapes all input even when a caller incorrectly marks it as safe HTML" do
    input = '<script>alert("KITCTF")</script> & <a href="/">Joomla</a>'.html_safe
    html = italicize_proper_names(input)
    document = Nokogiri::HTML.fragment(html)

    assert html.html_safe?
    assert_equal input, document.text
    assert_empty document.css("script, a")
    assert_equal [ "KITCTF", "Joomla" ], document.css("i.proper-name").map(&:text)
  end

  test "uses whole name boundaries including Unicode letters and combining marks" do
    input = "KITCTF2 preKITCTF _KITCTF KITCTF_extra ÄKITCTF KITCTFé KITCTF\u0301 JavaScript (KITCTF), WordPress-based"
    document = Nokogiri::HTML.fragment(italicize_proper_names(input))

    assert_equal input, document.text
    assert_equal [ "KITCTF", "WordPress" ], document.css("i.proper-name").map(&:text)
  end

  test "prefers full names over overlapping shorter names" do
    input = "KITCTF and KIT at Karlsruhe Institute of Technology; Joomla CMS, Joomla Security Strike Team, and Joomla."
    document = Nokogiri::HTML.fragment(italicize_proper_names(input))

    assert_equal input, document.text
    assert_equal [ "KITCTF", "KIT", "Karlsruhe Institute of Technology", "Joomla CMS", "Joomla Security Strike Team", "Joomla" ],
                 document.css("i.proper-name").map(&:text)
    assert_empty document.css("i i")
  end

  test "preserves possessives punctuation accents and explicitly supported spelling variants" do
    input = "LeetCode's problem, Pascal’s triangle, Docker-compose, ASP .NET Core, ASP.NET Core, SekaiCTF, SEKAICTF, .;,;. and École supérieure d'ingénieurs Léonard-de-Vinci."
    document = Nokogiri::HTML.fragment(italicize_proper_names(input))

    assert_equal input, document.text
    assert_equal [ "LeetCode", "Pascal", "Docker-compose", "ASP .NET Core", "ASP.NET Core", "SekaiCTF", "SEKAICTF", ".;,;.", "École supérieure d'ingénieurs Léonard-de-Vinci" ],
                 document.css("i.proper-name").map(&:text)
  end

  test "leaves ordinary prose and unrelated technical acronyms unstyled" do
    input = "Research on SQL, CVEs, CTF challenges, algorithms, and java beans."
    document = Nokogiri::HTML.fragment(italicize_proper_names(input))

    assert_equal input, document.text
    assert_empty document.css("i")
  end

  test "accepts missing descriptive text" do
    assert_equal "", italicize_proper_names(nil)
  end
end
