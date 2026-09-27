# A single post contract shared by blog, CTF, cards, feeds and the timeline.
# The repository returns a request-local hash so presentation code can safely
# decorate it without mutating a cached document or another request's record.
class ContentPost < Data.define(
  :type, :which, :item, :directory, :slug, :title, :published, :modified, :link,
  :description, :topic, :categories, :logo, :content, :body, :source_path,
  :word_count, :word_count_label, :reading_time_minutes, :reading_time_label,
  :authors, :metadata
)
  def self.from_document(type:, source:, slug:, link:, source_path:, document:, metadata:, published:, directory: nil)
    new(
      type: type,
      which: source,
      item: type == "ctf" ? source : slug,
      directory: directory,
      slug: slug,
      title: metadata["title"].presence || slug.humanize,
      published: published,
      modified: ContentDate.parse(metadata["updated"].presence || metadata["modified"], fallback: published),
      link: link,
      description: (metadata["reader_summary"].presence || metadata["description"]).to_s,
      topic: metadata["topic"].to_s,
      categories: Array(metadata["categories"]),
      logo: metadata["logo"],
      content: document[:content],
      body: document[:body],
      source_path: source_path,
      word_count: metadata["word_count"],
      word_count_label: metadata["word_count_label"],
      reading_time_minutes: metadata["reading_time_minutes"],
      reading_time_label: metadata["reading_time_label"],
      authors: ArticleAuthor.normalize(metadata["article_authors"]),
      metadata: metadata
    )
  end
end
