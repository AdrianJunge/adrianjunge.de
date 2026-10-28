# Preserve the text boundaries and order that text fragments see in the page.
# In particular, never fabricate neighboring text by joining metadata fields.
class SiteSearchPassages
  BLOCK_ELEMENTS = %w[p h1 h2 h3 h4 h5 h6 li dt dd td th pre blockquote figcaption summary time].freeze
  SEPARATE_CLASSES = %w[
    aboutme-card-tag aboutme-card-summary aboutme-card-kicker aboutme-card-reading-time
    aboutme-timeline-title aboutme-timeline-summary aboutme-timeline-event-link
    code-line post-meta-item blog-post-author-link blog-post-author-name
    writeup-hints-title writeup-hints-count
  ].freeze
  EXCLUDED = "script, style, svg, button, textarea, [hidden], [aria-hidden='true'], .copy-status, .sr-only, .visually-hidden, .aboutme-card-link-label".freeze

  def self.extract(root)
    root = root.is_a?(String) ? Nokogiri::HTML.fragment(root) : root.dup
    root.css(EXCLUDED).remove
    passages = []
    previous = nil
    root.xpath(".//text()").each do |node|
      next if node.text.empty?

      container = node.ancestors.find do |ancestor|
        BLOCK_ELEMENTS.include?(ancestor.name) || (ancestor["class"].to_s.split & SEPARATE_CLASSES).any?
      end || root
      if container == previous
        passages[-1] << node.text
      else
        passages << node.text.dup
        previous = container
      end
    end
    passages.map(&:squish).reject(&:blank?)
  end

  def self.section(passages, heading: "", anchor: nil)
    passages = Array(passages).map { |text| text.to_s.squish }.reject(&:blank?)
    { heading: heading, anchor: anchor, text: passages.join(" "), passages: passages }
  end
end
