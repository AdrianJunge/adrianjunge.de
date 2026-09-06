class FeedsController < ApplicationController
  include ActionView::Helpers::SanitizeHelper

  DESCRIPTION_TAGS = %w[p br strong em a code pre img].freeze
  DESCRIPTION_ATTRIBUTES = %w[href src alt title].freeze

  def show
    @feed_title = "adrianjunge.de"
    @feed_description = "Latest blog posts and CTF writeups from Adrian Junge."
    @feed_alternate_url = root_url

    @items = content_repository.feed_posts.map { |item| normalize_feed_item(item) }
    @feed_updated = @items.map { |item| item[:modified] }.max || ContentDate::EPOCH
    @feed_self_url = feed_self_url
    return unless stale?(etag: [ "feeds-v2", @feed_title, @feed_description, @feed_alternate_url, @feed_self_url, @items, request.format.to_s ], public: true)

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
      authors: [
        {
          name: "Adrian Junge",
          url: about_url
        }
      ],
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
      tags: [ item[:source] ]
    }.compact
  end

  def normalize_feed_item(item)
    link = absolute_feed_link(item[:link])

    {
      source: item[:source_label],
      source_key: item[:source_key],
      title: item[:title],
      description: sanitize(item[:description], tags: DESCRIPTION_TAGS, attributes: DESCRIPTION_ATTRIBUTES),
      link: link,
      pub_date: item[:published] || ContentDate::EPOCH,
      modified: item[:modified] || item[:published] || ContentDate::EPOCH,
      guid: link
    }
  end

  def absolute_feed_link(link)
    raw = link.to_s
    return raw if raw.match?(%r{\Ahttps?://}i)

    path = raw.start_with?("/") ? raw : "/#{raw}"
    path_without_fragment, fragment = path.split("#", 2)
    path_without_query, query = path_without_fragment.split("?", 2)
    encoded_path = path_without_query.split("/", -1).map do |segment|
      ERB::Util.url_encode(CGI.unescape(segment))
    end.join("/")
    encoded_path = "/" if encoded_path.blank?

    suffix = +""
    suffix << "?#{query}" if query.present?
    suffix << "##{fragment}" if fragment.present?

    "#{request.base_url}#{encoded_path}#{suffix}"
  end
end
