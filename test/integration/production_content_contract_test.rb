require "test_helper"

class ProductionContentContractTest < ActionDispatch::IntegrationTest
  test "blog catalog and Markdown files have consistent identities" do
    repository = production_content_repository
    metadata_slugs = repository.blog_metadata.keys.sort
    visible_metadata_slugs = repository.blog_metadata.reject do |_slug, metadata|
      repository.hidden_content?(metadata)
    end.keys.sort
    markdown_paths = trusted_markdown_paths(ApplicationController::BLOG_BASE_PATH, "*.md")
    markdown_slugs = markdown_paths.map { |path| File.basename(path, ".md") }.sort

    assert_empty markdown_slugs - metadata_slugs, "Markdown files without blog metadata"
    assert_empty visible_metadata_slugs - markdown_slugs, "visible blog metadata without Markdown files"
    expected_public_slugs = markdown_paths.filter_map do |path|
      slug = File.basename(path, ".md")
      metadata = parsed_markdown_metadata(path, repository)
      next if repository.hidden_content?(metadata) || repository.hidden_content?(repository.blog_metadata.fetch(slug))

      slug
    end

    assert_equal expected_public_slugs.sort, repository.blog_posts.map { |post| post[:slug] }.sort
  end

  test "every CTF Markdown file belongs to a configured event" do
    repository = production_content_repository
    raw_metadata = parse_content_json(ApplicationController::CTF_INFO_PATH)
    raw_event_pairs = raw_metadata.map do |name, metadata|
      [ metadata["terminal_path"].presence || name.downcase, metadata ]
    end
    event_slugs = raw_event_pairs.map(&:first)
    assert_equal event_slugs.uniq.length, event_slugs.length
    raw_events_by_slug = raw_event_pairs.to_h
    expected_public_event_slugs = raw_events_by_slug.reject do |_slug, metadata|
      repository.hidden_content?(metadata)
    end.keys
    markdown_paths = trusted_markdown_paths(ApplicationController::BASE_PATH, "*/*.md")
    markdown_event_slugs = markdown_paths.map { |path| Pathname(path).dirname.basename.to_s }.uniq

    assert_empty markdown_event_slugs - event_slugs
    assert_equal expected_public_event_slugs.sort, repository.ctf_events.map { |event| event[:slug] }.sort
    expected_public_paths = markdown_paths.reject do |path|
      event_metadata = raw_events_by_slug.fetch(path.dirname.basename.to_s)
      repository.hidden_content?(event_metadata) || repository.hidden_content?(parsed_markdown_metadata(path, repository))
    end.map(&:to_s).sort

    assert_equal expected_public_paths,
                 repository.ctf_posts.map { |post| post[:source_path].realpath.to_s }.sort
  end

  test "published Markdown front matter satisfies semantic contracts" do
    repository = production_content_repository

    repository.blog_posts.each do |post|
      assert post[:title].present?, "missing title for #{post[:link]}"
      assert post[:description].present?, "missing description for #{post[:link]}"
      assert post[:metadata]["published"].present?, "missing publication date for #{post[:link]}"
      assert repository.parsed_time(post[:metadata]["published"], fallback: nil), "invalid publication date for #{post[:link]}"
      assert post[:word_count].positive?, "empty Markdown body for #{post[:link]}"
    end

    repository.ctf_posts.each do |post|
      metadata = post[:metadata]

      assert post[:title].present?, "missing title for #{post[:link]}"
      assert post[:description].present?, "missing description for #{post[:link]}"
      assert metadata["published"].present?, "missing publication date for #{post[:link]}"
      assert repository.parsed_time(metadata["published"], fallback: nil), "invalid publication date for #{post[:link]}"
      assert Array(metadata["categories"]).any?, "missing categories for #{post[:link]}"
      assert post[:word_count].positive?, "empty Markdown body for #{post[:link]}"
    end
  end

  test "private CTF resources are referenced and only public references are catalogued" do
    repository = production_content_repository
    raw_metadata = parse_content_json(ApplicationController::CTF_INFO_PATH)
    raw_events_by_slug = raw_metadata.to_h do |name, metadata|
      [ metadata["terminal_path"].presence || name.downcase, metadata ]
    end
    referenced_paths = []
    expected_public_paths = []

    trusted_markdown_paths(ApplicationController::BASE_PATH, "*/*.md").each do |path|
      event_metadata = raw_events_by_slug.fetch(path.dirname.basename.to_s)
      post_metadata = parsed_markdown_metadata(path, repository)
      resource_paths = existing_resource_paths(path.dirname.basename.to_s, post_metadata, repository)
      referenced_paths.concat(resource_paths)

      next if repository.hidden_content?(event_metadata) || repository.hidden_content?(post_metadata)

      expected_public_paths.concat(resource_paths)
    end

    shipped_paths = [
      ApplicationController::CTF_CHALLENGE_FILES_PATH,
      ApplicationController::CTF_PDF_WRITEUPS_PATH
    ].flat_map do |root|
      Dir.glob(root.join("**", "*")).filter_map do |candidate|
        next unless File.file?(candidate)

        canonical = TrustedContentPath.file(root: root, candidate: candidate)
        assert canonical, "untrusted private CTF resource #{candidate}"
        canonical.to_s
      end
    end
    catalogued_paths = repository.ctf_assets.map { |asset| asset[:path].realpath.to_s }

    assert_equal shipped_paths.sort, referenced_paths.uniq.sort
    assert_equal expected_public_paths.uniq.sort, catalogued_paths.sort
  end

  test "public post identities are unique and collections are newest first" do
    repository = production_content_repository
    blog_posts = repository.blog_posts
    ctf_posts = repository.ctf_posts

    assert_equal blog_posts.map { |post| post[:slug] }.uniq.length, blog_posts.length
    assert_equal ctf_posts.map { |post| [ post[:directory], post[:slug] ] }.uniq.length, ctf_posts.length
    assert_equal blog_posts.map { |post| post[:link] }.uniq.length, blog_posts.length
    assert_equal ctf_posts.map { |post| post[:link] }.uniq.length, ctf_posts.length
    assert_equal blog_posts.sort_by { |post| -post[:published].to_i }.map { |post| post[:link] }, blog_posts.map { |post| post[:link] }
    assert_equal ctf_posts.sort_by { |post| -post[:published].to_i }.map { |post| post[:link] }, ctf_posts.map { |post| post[:link] }
  end

  test "collection pages render exact repository URL sets" do
    repository = production_content_repository

    get blog_path
    assert_response :success
    assert_equal repository.blog_posts.map { |post| post[:link] }.sort,
                 css_select(".blog-posts-container .blog-post-card-hitbox").map { |node| node["href"] }.sort

    get ctf_path
    assert_response :success
    assert_equal repository.ctf_events.map { |event| event[:metadata]["writeups"] }.sort,
                 css_select(".ctf-cards-container .blog-post-card-hitbox").map { |node| node["href"] }.sort

    repository.ctf_events.each do |event|
      get event[:metadata]["writeups"]
      assert_response :success
      assert_equal repository.ctf_posts_for_event(event[:slug]).map { |post| post[:link] }.sort,
                   css_select(".writeup-overview .blog-post-card-hitbox").map { |node| node["href"] }.sort,
                   "writeup card mismatch for #{event[:slug]}"
    end
  end

  private

  def trusted_markdown_paths(root, relative_pattern)
    Dir.glob(root.join(relative_pattern)).sort.map do |candidate|
      canonical = TrustedContentPath.file(root: root, candidate: candidate)
      assert canonical, "untrusted Markdown path #{candidate}"
      canonical
    end
  end

  def parsed_markdown_metadata(path, repository)
    parsed = repository.parse_markdown(File.read(path))
    assert parsed, "invalid Markdown front matter in #{path}"
    parsed.front_matter || {}
  end

  def existing_resource_paths(event_slug, metadata, repository)
    asset_name = metadata["challengefiles"].to_s
    year = repository.ctf_event_year(metadata).to_s
    return [] unless year.match?(/\A\d{4}\z/)
    return [] unless asset_name.match?(ContentRepository::CTF_ASSET_NAME_PATTERN)
    return [] if %w[. ..].include?(asset_name)

    [
      [ ApplicationController::CTF_CHALLENGE_FILES_PATH, "zip" ],
      [ ApplicationController::CTF_PDF_WRITEUPS_PATH, "pdf" ]
    ].filter_map do |root, extension|
      candidate = root.join(event_slug, year, "#{asset_name}.#{extension}")
      TrustedContentPath.file(root: root, candidate: candidate)&.to_s
    end
  end
end
