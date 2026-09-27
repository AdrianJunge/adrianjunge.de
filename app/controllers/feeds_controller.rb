class FeedsController < ApplicationController
  self.requires_modern_browser = false

  include ActionView::Helpers::SanitizeHelper

  DESCRIPTION_TAGS = %w[p br strong em a code pre img].freeze
  DESCRIPTION_ATTRIBUTES = %w[href src alt title].freeze

  def show
    @feed_title = SiteProfile.feed_title
    @feed_description = "Latest blog posts and CTF writeups from #{SiteProfile.name}."
    @feed_alternate_url = root_url

    @items = content_repository.feed_posts.map { |item| normalize_feed_item(item) }
    @feed_updated = @items.map { |item| item[:modified] }.max || ContentDate::EPOCH
    @feed_self_url = feed_self_url
    return unless stale?(etag: [ "feeds-v3", SiteProfile.author, @feed_title, @feed_description, @feed_alternate_url, @feed_self_url, @items, request.format.to_s ], public: true)

    respond_to do |format|
      format.rss do
        response.content_type = "application/xml" if request.path.end_with?(".xml")
        render layout: false
      end
      format.xml { render :show, formats: :rss, layout: false, content_type: "application/xml" }
      format.atom { render layout: false }
      format.json { render json: json_feed_payload, content_type: "application/feed+json" }
    end
  end

  private

  def feed_self_url
    case request.format.symbol
    when :atom
      feed_url(format: :atom)
    when :json
      feed_json_url
    else
      feed_xml_url
    end
  end

  def json_feed_payload
    {
      version: "https://jsonfeed.org/version/1.1",
      title: @feed_title,
      home_page_url: @feed_alternate_url,
      feed_url: feed_json_url,
      description: @feed_description,
      language: "en",
      authors: [ SiteProfile.author ],
      items: @items.map { |item| json_feed_item(item) }
    }
  end

  def json_feed_item(item)
    {
      id: item[:guid],
      url: item[:link],
      title: item[:title],
      content_html: item[:description],
      summary: strip_tags(item[:description]).squish,
      date_published: item[:pub_date].iso8601,
      date_modified: item[:modified].iso8601,
      tags: [ item[:source] ],
      authors: item[:authors]
    }.compact
  end

  def normalize_feed_item(item)
    link = SiteProfile.absolute_url(item[:link])

    {
      source: item[:source_label],
      source_key: item[:source_key],
      title: item[:title],
      description: sanitize(item[:description], tags: DESCRIPTION_TAGS, attributes: DESCRIPTION_ATTRIBUTES),
      link: link,
      pub_date: item[:published] || ContentDate::EPOCH,
      modified: item[:modified] || item[:published] || ContentDate::EPOCH,
      guid: link,
      authors: item[:authors] || ArticleAuthor.normalize(item.dig(:metadata, "article_authors"))
    }
  end
end
