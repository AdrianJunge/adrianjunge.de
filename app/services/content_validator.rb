class ContentValidator
  Result = Data.define(:errors, :warnings, :documents) do
    def valid?
      errors.empty?
    end
  end

  def initialize(repository: nil, configuration: nil)
    @configuration = configuration || repository&.configuration || ContentConfiguration.new
    @repository = repository || ContentRepository.new(configuration: @configuration)
    reset
  end

  def call
    reset
    validate_catalogs
    validate_documents
    # Invalid input already has source/property diagnostics. Do not feed those
    # invalid shapes into consumers that expect validated content.
    if @errors.empty?
      capture("published content catalog") do
        repository.blog_posts
        repository.ctf_posts
        repository.ctf_assets
        ContentIndex.new(repository: repository).all_items
      end
    end
    Result.new(errors: @errors.freeze, warnings: @warnings.freeze, documents: @documents)
  end

  def reset
    @errors = []
    @warnings = []
    @documents = 0
  end

  def markdown_image_errors(body, path:)
    html = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new, fenced_code_blocks: true).render(body)
    Nokogiri::HTML.fragment(html).css("img[src]").filter_map do |image|
      reference = image["src"].to_s
      next if reference.start_with?("//") || reference.match?(/\A[a-z][a-z0-9+.-]*:/i)

      pathname = URI::DEFAULT_PARSER.unescape(reference.split(/[?#]/, 2).first.to_s)
      root = pathname.start_with?("/") ? configuration.root.join("public") : configuration.root.join("app/assets/images")
      candidate = root.join(pathname.delete_prefix("/"))
      "#{path}: missing local Markdown image #{reference.inspect}" unless TrustedContentPath.file(root: root, candidate: candidate)
    end
  end

  private

  attr_reader :repository, :configuration

  private :reset

  def validate_catalogs
    ids = {}
    ContentJsonSchemas.registered_paths.each do |schema_path|
      path = configuration.resolve(schema_path)
      capture(path) do
        data = JSON.parse(File.read(path), allow_comments: true)
        errors = ContentJsonSchemas.errors_for(schema_path, data)
        report_schema_errors(path, errors)
        next if errors.any?

        validate_images(data, path)
        if ContentJsonSchemas::ARRAY_SCHEMAS.key?(schema_path)
          repository.normalize_about_entries(data, path: path).each do |entry|
            [ entry, *Array(entry["timeline"]) ].each do |item|
              id = item.fetch("id")
              @errors << "#{path}: fragment ID #{id.inspect} also occurs in #{ids[id]}" if ids.key?(id)
              ids[id] = path
            end
          end
        else
          data.each do |key, entry|
            pointer = "/#{ContentJsonSchemas.pointer_key(key)}"
            slug = entry["directory"].presence || key.downcase
            if entry.key?("writeups") && entry["writeups"] != "/ctf/#{slug}"
              @errors << "#{path}#{pointer}/writeups: must match derived path /ctf/#{slug}"
            end
          end
        end
      end
    end
  end

  def validate_documents
    blog_root = configuration.path(:BLOG_BASE_PATH)
    about_path = configuration.path(:ABOUTME_TEXT_PATH)
    files = Dir.glob(blog_root.join("*.md")) + Dir.glob(configuration.path(:BASE_PATH).join("*", "*.md")) + [ about_path.to_s ]
    files.sort.each do |path|
      capture(path) do
        next if File.dirname(path) == blog_root.to_s && !validate_blog_path(path, blog_root)

        document = repository.parse_markdown(File.read(path), path: path)
        metadata = document.front_matter.deep_stringify_keys
        @documents += 1
        report_schema_errors(path, ContentFrontMatterSchemas.errors_for(metadata, about: path == about_path.to_s))
        validate_images(metadata, path)
        @errors.concat(markdown_image_errors(document.content, path: path))
        document.content.scan(/^\s*`{3,}([^\s`]+).*$/).flatten.uniq.each do |language|
          next if Rouge::Lexer.find(language)

          @warnings << "#{path}: unknown code language #{language.inspect}; rendered as plain text"
        end
      end
    end
  end

  def validate_blog_path(path, root)
    slug = File.basename(path, ".md")
    unless ContentRepository::BLOG_SLUG_PATTERN.match?(slug)
      @errors << "#{path}: invalid blog filename slug #{slug.inspect}; use lowercase letters and digits separated by single hyphens"
    end
    unless TrustedContentPath.file(root: root, candidate: path)
      @errors << "#{path}: blog Markdown must be a file within #{root}"
      return false
    end

    true
  end

  def report_schema_errors(path, errors)
    errors.each { |error| @errors << "#{path}#{error['data_pointer']}: #{error['type']}" }
  end

  def validate_images(value, path, pointer = "")
    case value
    when Array
      value.each_with_index { |entry, index| validate_images(entry, path, "#{pointer}/#{index}") }
    when Hash
      value.each do |key, entry|
        entry_pointer = "#{pointer}/#{ContentJsonSchemas.pointer_key(key)}"
        if %w[icon logo].include?(key) && entry.is_a?(String) && entry.present?
          root = configuration.root.join("app/assets/images")
          image = TrustedContentPath.file(root: root, candidate: root.join(entry))
          @errors << "#{path}#{entry_pointer}: missing local image #{entry.inspect}" unless image
        else
          validate_images(entry, path, entry_pointer)
        end
      end
    end
  end

  def capture(path)
    yield
  rescue Errno::ENOENT
    @errors << "#{path}: required content file is missing"
  rescue ContentRepository::InvalidContent, ContentRepository::InvalidContentPath, ContentJsonSchemas::ValidationError, JSON::ParserError => error
    @errors << "#{path}: #{error.message}"
  end
end
