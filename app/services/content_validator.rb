class ContentValidator
  Result = Data.define(:errors, :warnings, :documents) do
    def valid?
      errors.empty?
    end
  end

  def initialize(repository: ContentRepository.new)
    @repository = repository
    @errors = []
    @warnings = []
    @documents = 0
  end

  def call
    validate_catalogs
    validate_documents
    capture("published content catalog") do
      repository.blog_posts
      repository.ctf_posts
      repository.ctf_assets
      ContentIndex.new(repository: repository).all_items
    end
    Result.new(errors: @errors.freeze, warnings: @warnings.freeze, documents: @documents)
  end

  def markdown_image_errors(body, path:)
    html = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new, fenced_code_blocks: true).render(body)
    Nokogiri::HTML.fragment(html).css("img[src]").filter_map do |image|
      reference = image["src"].to_s
      next if reference.start_with?("//") || reference.match?(/\A[a-z][a-z0-9+.-]*:/i)

      pathname = URI::DEFAULT_PARSER.unescape(reference.split(/[?#]/, 2).first.to_s)
      root = pathname.start_with?("/") ? Rails.root.join("public") : Rails.root.join("app/assets/images")
      candidate = root.join(pathname.delete_prefix("/"))
      "#{path}: missing local Markdown image #{reference.inspect}" unless TrustedContentPath.file(root: root, candidate: candidate)
    end
  end

  private

  attr_reader :repository

  def validate_catalogs
    ids = {}
    ContentJsonSchemas.registered_paths.each do |path|
      capture(path) do
        data = JSON.parse(File.read(path), allow_comments: true)
        ContentJsonSchemas.validate!(path, data)
        validate_images(data, path)
        if ContentJsonSchemas::ARRAY_SCHEMAS.key?(path)
          repository.normalize_about_entries(data, path: path).each do |entry|
            [ entry, *Array(entry["timeline"]) ].each do |item|
              id = item.fetch("id")
              @errors << "#{path}: fragment ID #{id.inspect} also occurs in #{ids[id]}" if ids.key?(id)
              ids[id] = path
            end
          end
        else
          data.each do |key, entry|
            slug = entry["terminal_path"]
            if path == ContentConfiguration::BLOG_INFO_PATH.to_s
              @errors << "#{path}: #{key.inspect} must match terminal_path" unless key == slug
              @errors << "#{path}: missing post #{slug.inspect}" unless ContentConfiguration::BLOG_BASE_PATH.join("#{slug}.md").file?
            elsif entry["writeups"] != "/ctf/#{slug}"
              @errors << "#{path}: #{key.inspect} has an inconsistent writeups path"
            end
          end
        end
      end
    end
  end

  def validate_documents
    files = Dir.glob(ContentConfiguration::BLOG_BASE_PATH.join("*.md")) + Dir.glob(ContentConfiguration::BASE_PATH.join("*", "*.md"))
    files.sort.each do |path|
      capture(path) do
        document = repository.markdown_document(path)
        metadata = document[:metadata]
        if File.dirname(path) == ContentConfiguration::BLOG_BASE_PATH.to_s
          catalog_metadata = repository.blog_metadata.fetch(File.basename(path, ".md"), {})
          metadata = catalog_metadata.merge(metadata)
        end
        @documents += 1
        @errors.concat(markdown_image_errors(document[:body], path: path))
        %w[title description published].each do |key|
          @errors << "#{path}: missing required #{key}" if metadata[key].blank?
        end
        ContentJsonSchemas.metadata_errors(metadata).each do |error|
          @errors << "#{path}#{error["data_pointer"]}: #{error["type"]}"
        end
        if metadata["article_authors"].present? && !metadata["article_authors"].is_a?(Array)
          @errors << "#{path}: article_authors must be an array of names or name/url objects"
        end
        Array(metadata["article_authors"]).each do |author|
          name = author.is_a?(Hash) ? author["name"] : author
          @errors << "#{path}: article author must have a name" if name.to_s.strip.blank?
        end
        document[:body].scan(/^\s*`{3,}([^\s`]+).*$/).flatten.uniq.each do |language|
          next if Rouge::Lexer.find(language)

          @warnings << "#{path}: unknown code language #{language.inspect}; rendered as plain text"
        end
      end
    end
  end

  def validate_images(value, path)
    case value
    when Array
      value.each { |entry| validate_images(entry, path) }
    when Hash
      value.each do |key, entry|
        if %w[icon logo].include?(key) && entry.present?
          image = TrustedContentPath.file(root: Rails.root.join("app/assets/images"), candidate: Rails.root.join("app/assets/images", entry))
          @errors << "#{path}: missing local image #{entry.inspect}" unless image
        else
          validate_images(entry, path)
        end
      end
    end
  end

  def capture(path)
    yield
  rescue ContentRepository::InvalidContent, ContentRepository::InvalidContentPath, ContentJsonSchemas::ValidationError, JSON::ParserError, Errno::ENOENT => error
    @errors << "#{path}: #{error.message}"
  end
end
