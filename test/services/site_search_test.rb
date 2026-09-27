require "test_helper"
require "tmpdir"

class SiteSearchTest < ActiveSupport::TestCase
  test "ranking across document sections agrees with the shared client contract" do
    cases = JSON.parse(Rails.root.join("test/fixtures/site_search_cases.json").read, symbolize_names: true)
    cases[:queries].each do |example|
      results = SiteSearch.search_documents(cases[:documents], example[:q])
      assert_equal example[:urls], results.pluck(:url), example[:q]
    end
    assert_equal 2, SiteSearch.search_documents(cases[:documents], "needle", limit: 2).length
    assert_equal "", SiteSearch.query([ "unexpected" ])
    assert_equal 200, SiteSearch.query("x" * 300).length
    assert_empty SiteSearch.search_documents(cases[:documents], { q: "needle" })
  end

  test "all matching documents remain available beyond twenty results" do
    documents = Array.new(35) { |index| { title: "Needle #{index}", kind: "Page", url: "/#{index}", tags: [], sections: [ { heading: "", anchor: nil, text: "" } ] } }
    assert_equal 35, SiteSearch.search_documents(documents, "needle").length
    assert_equal 7, SiteSearch.search_documents(documents, "needle", limit: 7).length
  end

  test "metadata-only matches retain a document URL even without an introduction section" do
    document = { title: "Needle", url: "/about#parent", kind: "CVE", tags: [], sections: [ { heading: "Section", anchor: "child", text: "needle body" } ] }
    assert_equal "/about#parent", SiteSearch.search_documents([ document ], "needle").first[:url]
  end

  test "body matches use real duplicate heading anchors and match across sections" do
    repository = fixture_content_repository
    post = repository.blog_posts.first
    post[:body] = "# Repeated heading\n\nOrangeonly.\n\n# Repeated heading\n\nPearonly.\n\n# Legacy heading <a id=\"old-heading\"></a>\n\n```text\ncodeonlyword\n```\n\n![Diagram altneedle](/diagram.png)"
    headings = []
    Object.new.extend(MarkdownHelper).render_markdown(post[:body], headings: headings, parsed: true)
    search = SiteSearch.new(repository: repository)

    assert_equal "#{post[:link]}##{headings[1][:anchor]}", search.search("Pearonly").first[:url]
    assert_equal "#{post[:link]}##{headings[0][:anchor]}", search.search("Orangeonly Pearonly").first[:url]
    assert_equal "#{post[:link]}##{headings[2][:anchor]}", search.search("codeonlyword").first[:url]
    assert_equal "#{post[:link]}##{headings[2][:anchor]}", search.search("altneedle").first[:url]
    assert search.documents.none? { |document| document[:sections].any? { |section| section[:text].include?("Copy code") } }
  end

  test "original prompt hints authors event year difficulty and recognition are searchable" do
    repository = fixture_content_repository
    post = repository.ctf_posts.first
    post[:metadata].merge!(
      "description" => "Originalpromptneedle", "reader_summary" => "Readersummaryneedle",
      "authors" => [ { "name" => "Challengeauthorneedle", "url" => "https://example.com/author" } ],
      "article_authors" => [ { "name" => "Articleauthorneedle" } ],
      "difficulty" => "Hard", "ctf_year" => "2022", "published" => "2025-03-03",
      "optional" => { "hints" => [ "Hintneedle" ], "authored_challenge" => true,
                      "writeup_winner" => { "label" => "Recognitionneedle", "proof_url" => "https://example.com/proof" } }
    )
    search = SiteSearch.new(repository: repository)
    %w[Originalpromptneedle Readersummaryneedle Challengeauthorneedle Articleauthorneedle Hintneedle Hard DEMOCTF 2022 2025-03-03 Recognitionneedle].each do |query|
      assert_includes search.search(query).pluck(:url), post[:link], query
    end
    assert_includes search.search("authored challenge").pluck(:url), post[:link]
    assert_includes search.search("writeup winner").pluck(:url), post[:link]
    document = search.documents.find { |entry| entry[:url] == post[:link] }
    assert_not_includes document.to_json, "https://example.com/proof"
  end

  test "About parent metadata remains alongside milestones without timeline merging" do
    repository = fixture_content_repository
    original = repository.method(:about_entries)
    repository.define_singleton_method(:about_entries) do |path, **options|
      entries = original.call(path, **options)
      if path == ContentConfiguration::ABOUTME_CVES_PATH
        entries.first.merge!("subtitle" => "Subtitleneedle", "summary" => "Parentcontextneedle",
          "links" => [ { "label" => "Referenceneedle", "url" => "https://example.com/reference" } ],
          "timeline" => [ { "id" => "public-event", "title" => "Milestoneneedle", "date" => "2025-06-01", "summary" => "Eventsummaryneedle" } ])
      end
      entries
    end
    search = SiteSearch.new(repository: repository)
    %w[Subtitleneedle Parentcontextneedle Referenceneedle CVE-2099-0001 CWE-787 High].each do |query|
      assert_includes search.search(query).pluck(:url), "/about#fixture-cve", query
    end
    assert_includes search.search("Parentcontextneedle Milestoneneedle").pluck(:url), "/about#public-event"
    assert_includes search.search("Eventsummaryneedle").pluck(:url), "/about#public-event"
    assert search.documents.any? { |entry| entry[:url] == "/about#fixture-certificate" }
    assert search.documents.any? { |entry| entry[:url] == "/blog/alpha-post" }
  end

  test "hidden nested metadata and private paths never enter the payload" do
    repository = fixture_content_repository
    post = repository.ctf_posts.first
    post[:metadata]["optional"] = {
      "hints" => [ { "text" => "Hiddenhintneedle", "hidden" => true }, { "text" => "Publichintneedle" } ],
      "authored_challenge" => { "label" => "Hiddenrecognitionneedle", "hidden" => true },
      "private_notes" => "Privatenotesneedle"
    }
    post[:metadata]["source_path"] = "/home/private/source.txt"
    payload = SiteSearch.new(repository: repository).documents.to_json

    %w[Hiddenhintneedle Hiddenrecognitionneedle Privatenotesneedle fixture-result-hidden fixture-talk-hidden /home/private /ctf/democtf/Hidden /ctf/hiddenctf/Leaked source_path challengefiles].each do |hidden|
      assert_not_includes payload, hidden
    end
    assert_includes payload, "Publichintneedle"
  end

  test "every shipped public source has a unique canonical document" do
    repository = production_content_repository
    documents = SiteSearch.new(repository: repository).documents
    expected = %w[/ /about /blog /ctf /timeline]
    expected.concat((repository.blog_posts + repository.ctf_posts).pluck(:link))
    expected.concat(repository.ctf_events.map { |event| event[:metadata].fetch("writeups") })
    SiteSearch::ABOUT_COLLECTIONS.each do |collection|
      expected << "/about##{collection[:id]}"
      entries = collection[:id] == "my-challenges" ? repository.authored_challenges : repository.about_entries(ContentConfiguration.const_get(collection[:path]))
      expected.concat(entries.map { |entry| "/about##{entry.fetch('id')}" })
      entries.each do |entry|
        indexed = documents.find { |document| document[:url] == "/about##{entry.fetch('id')}" }
        assert indexed, entry["id"]
        Array(entry["timeline"]).each do |event|
          assert indexed[:sections].any? { |section| section[:heading] == event["title"].squish && section[:anchor] == event["id"].presence }, event.inspect
        end
      end
    end
    assert_equal expected.sort, documents.pluck(:url).sort
    assert_equal documents.pluck(:url).uniq, documents.pluck(:url)
    assert documents.all? { |document| document.keys.sort == %i[kind sections tags title url] }
  end

  test "shipped distinctive terms cover every public content class and contact information" do
    search = SiteSearch.new
    {
      "GuardedString" => "/blog/java-strings", "most sacred secrets" => "/ctf/gpnctf/Smile%20at%20me",
      "Forschungszentrum" => "/about", "CVE-2026-97377" => "/about#suitecrm-portal-get-entry-list-sql-injection",
      "GLIBC dynamic symbol poisoning" => "/about#scanwich-station", "first attempt practical exam" => "/about#htb-cpts",
      "homework" => "/about#joomla-sqli", "Deutsche Hacking Meisterschaft" => "/about#dhm",
      "annual German" => "/ctf/cscg", "software confess" => "/", "LeetCode KITCTF" => "/"
    }.each do |query, prefix|
      assert search.search(query).any? { |result| result[:url].start_with?(prefix) }, query
    end
    assert_includes search.search(SiteProfile.email).pluck(:url), "/"
    assert_includes search.search("PGP key").pluck(:url), "/about"
    assert_includes search.search("authored challenge").pluck(:url), "/ctf/gpnctf/Scanwich%20Station"
    assert_includes search.search("writeup winner").pluck(:url), "/ctf/umdctf/A%20Minecraft%20Movie"
    assert_includes search.search("Best web writeup 2025").pluck(:url), "/ctf/umdctf/A%20Minecraft%20Movie"
  end

  test "content and biography edits hiding deletion and profile changes refresh new instances" do
    with_temporary_repository do |configuration, repository_for|
      post = configuration.path(:BLOG_BASE_PATH).join("example.md")
      body = "---\ntitle: Example\ndescription: Example\npublished: '2026-01-01'\n---\n# Section\n\noldneedle"
      post.write(body)
      search = -> { SiteSearch.new(repository: repository_for.call) }
      assert_equal 1, search.call.search("oldneedle").length
      post.write(body.sub("oldneedle", "newneedle"))
      assert_empty search.call.search("oldneedle")
      assert_equal 1, search.call.search("newneedle").length
      configuration.path(:ABOUTME_TEXT_PATH).write("---\ntitle: About\ndescription: Profile\n---\nBiographyneedle")
      assert_equal [ "/about" ], search.call.search("Biographyneedle").pluck(:url)
      post.write(body.sub("title: Example", "title: Example\nhidden: true"))
      assert search.call.documents.none? { |document| document[:url] == "/blog/example" }
      post.delete
      assert search.call.documents.none? { |document| document[:url] == "/blog/example" }

      original_email = SiteProfile.method(:email)
      SiteProfile.define_singleton_method(:email) { "revisionneedle@example.com" }
      assert_includes search.call.search("revisionneedle").pluck(:url), "/"
    ensure
      SiteProfile.define_singleton_method(:email, original_email) if original_email
    end
  end

  test "snippets center matching context without marking text as HTML" do
    text = "Intro. " * 80 + "Needle <em>example</em>. " + "Ending. " * 80
    snippet = SiteSearch.snippet(text, [ "needle" ])
    assert_includes snippet, "Needle <em>example</em>"
    assert snippet.start_with?("…")
    assert snippet.end_with?("…")
    assert_operator snippet.length, :<=, 202
    assert_not snippet.html_safe?
  end

  test "warm caches track About card milestones and event metadata visibility" do
    with_temporary_repository do |configuration, repository_for|
      certificate_path = configuration.path(:ABOUTME_CERTIFICATES_PATH)
      event_path = configuration.path(:CTF_INFO_PATH)
      certificate = { id: "example", title: "Example certificate", summary: "Oldsummaryneedle",
                      timeline: [ { id: "earned", date: "2026-01-01", title: "Oldmilestoneneedle" } ] }
      event = { "ExampleCTF" => { "description" => "Oldeventneedle", "directory" => "examplectf",
                                 "logo" => "fixture.png", "website" => "https://example.com" } }
      certificate_path.write([ certificate ].to_json)
      event_path.write(event.to_json)
      search = -> { SiteSearch.new(repository: repository_for.call) }
      assert_equal [ "/about#example" ], search.call.search("Oldsummaryneedle").pluck(:url)
      assert_equal [ "/about#earned" ], search.call.search("Oldmilestoneneedle").pluck(:url)
      assert_equal [ "/ctf/examplectf" ], search.call.search("Oldeventneedle").pluck(:url)

      certificate[:summary] = "Newsummaryneedle"
      certificate[:timeline].first[:title] = "Newmilestoneneedle"
      certificate_path.write([ certificate ].to_json)
      event["ExampleCTF"]["description"] = "Neweventneedle"
      event_path.write(event.to_json)
      %w[Oldsummaryneedle Oldmilestoneneedle Oldeventneedle].each { |query| assert_empty search.call.search(query), query }
      assert_equal [ "/about#example" ], search.call.search("Newsummaryneedle").pluck(:url)
      assert_equal [ "/about#earned" ], search.call.search("Newmilestoneneedle").pluck(:url)
      assert_equal [ "/ctf/examplectf" ], search.call.search("Neweventneedle").pluck(:url)

      certificate[:timeline].first[:hidden] = true
      certificate_path.write([ certificate ].to_json)
      assert_empty search.call.search("Newmilestoneneedle")
      assert_equal [ "/about#example" ], search.call.search("Newsummaryneedle").pluck(:url)
      certificate[:hidden] = true
      certificate_path.write([ certificate ].to_json)
      event["ExampleCTF"]["hidden"] = true
      event_path.write(event.to_json)
      assert_empty search.call.search("Newsummaryneedle")
      assert_empty search.call.search("Neweventneedle")
      assert search.call.documents.none? { |document| %w[/about#example /ctf/examplectf].include?(document[:url]) }
    end
  end

  private

  def with_temporary_repository
    Dir.mktmpdir("site-search") do |directory|
      configuration = ContentConfiguration.new(root: directory)
      %i[BASE_PATH BLOG_BASE_PATH ABOUTME_BASE_PATH].each { |name| configuration.path(name).mkpath }
      configuration.path(:CTF_INFO_PATH).write("{}")
      SiteSearch::ABOUT_COLLECTIONS.each { |collection| configuration.path(collection[:path]).write("[]") }
      configuration.path(:ABOUTME_TEXT_PATH).write("---\ntitle: About\ndescription: Profile\n---\nFixture biography.")
      yield configuration, -> { ContentRepository.new(configuration: configuration) }
    end
  end
end
