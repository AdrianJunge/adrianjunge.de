require "uri"

class ArticleDetours
  MAX_PATH_BYTES = 512
  MAX_TOKENS = 8
  MAX_TOKEN_LENGTH = 32
  MAX_SUGGESTIONS = 3
  ROUTE_WORDS = %w[blog ctf 404].freeze

  def initialize(repository: ContentRepository.new, random: Random.new)
    @repository = repository
    @random = random
  end

  def call(path)
    # These collections already apply article and parent-event publication rules.
    articles = @repository.blog_posts + @repository.ctf_posts
    query = path_tokens(path)
    suggestions = if query.empty?
      []
    else
      articles.filter_map do |post|
        words = (tokens(post.dig(:metadata, "title")) + tokens(post[:slug])).uniq
        score = query.sum { |word| words.map { |candidate| word_score(word, candidate) }.max.to_i }
        [ score, destination(post) ] if score.positive?
      end.sort_by { |score, post| [ -score, post[:title].downcase, post[:url] ] }
        .first(MAX_SUGGESTIONS).map(&:last)
    end

    sampled = articles.sample(random: @random)
    { suggestions: suggestions, random_article: sampled && destination(sampled).merge(type: sampled[:type]) }
  end

  private

  def destination(post)
    { title: post.dig(:metadata, "title").presence || post[:slug], url: post[:link] }
  end

  def path_tokens(path)
    return [] unless path.is_a?(String)

    bounded = path.byteslice(0, MAX_PATH_BYTES).force_encoding(Encoding::UTF_8).scrub.split(/[?#]/, 2).first.to_s
    tokens(URI::DEFAULT_PARSER.unescape(bounded)).reject { |word| ROUTE_WORDS.include?(word) }
  end

  def tokens(value)
    value.to_s.byteslice(0, MAX_PATH_BYTES).force_encoding(Encoding::UTF_8).scrub
      .unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.scan(/[a-z0-9]+/)
      .select { |word| word.length.between?(3, MAX_TOKEN_LENGTH) && word.match?(/[a-z]/) }
      .uniq.first(MAX_TOKENS)
  end

  def word_score(word, candidate)
    return 8 if word == candidate
    return 4 if word.length >= 4 && candidate.start_with?(word)
    return 0 if word.length < 4 || candidate.length < 4

    tolerance = word.length >= 8 ? 2 : 1
    return 0 if (word.length - candidate.length).abs > tolerance

    edit_distance(word, candidate) <= tolerance ? 3 : 0
  end

  # Bounded tokens keep the typo comparison small; adjacent swaps count once.
  def edit_distance(left, right)
    rows = Array.new(left.length + 1) { Array.new(right.length + 1, 0) }
    (0..left.length).each { |index| rows[index][0] = index }
    (0..right.length).each { |index| rows[0][index] = index }
    (1..left.length).each do |i|
      (1..right.length).each do |j|
        cost = left[i - 1] == right[j - 1] ? 0 : 1
        rows[i][j] = [ rows[i - 1][j] + 1, rows[i][j - 1] + 1, rows[i - 1][j - 1] + cost ].min
        if i > 1 && j > 1 && left[i - 1] == right[j - 2] && left[i - 2] == right[j - 1]
          rows[i][j] = [ rows[i][j], rows[i - 2][j - 2] + 1 ].min
        end
      end
    end
    rows.last.last
  end
end
