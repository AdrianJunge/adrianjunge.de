class FeedsController < ApplicationController
  include ActionView::Helpers::SanitizeHelper

  DESCRIPTION_TAGS = %w[p br strong em a code pre img].freeze
  DESCRIPTION_ATTRIBUTES = %w[href src alt title].freeze

  def show
    @feed_title = "adrianjunge.de"
    @feed_description = "Latest blog posts and CTF writeups from Adrian Junge."
    @feed_alternate_url = root_url
    @feed_self_url = request.format.symbol == :atom ? feed_url(format: :atom) : feed_url

    @items = content_repository.feed_posts.map { |item| normalize_feed_item(item) }
    @feed_updated = @items.first&.dig(:pub_date) || Time.zone.now

    respond_to do |format|
      format.rss { render layout: false }
      format.atom { render layout: false }
    end
  end

  private

  def normalize_feed_item(item)
    link = absolute_feed_link(item[:link])

    {
      source: item[:source_label],
      source_key: item[:source_key],
      title: item[:title],
      description: sanitize(item[:description], tags: DESCRIPTION_TAGS, attributes: DESCRIPTION_ATTRIBUTES),
      link: link,
      pub_date: item[:published] || Time.zone.now,
      guid: link
    }
  end

  def absolute_feed_link(link)
    raw = link.to_s
    return raw if raw.match?(%r{\Ahttps?://}i)

    path = raw.start_with?("/") ? raw : "/#{raw}"
    path_without_fragment, fragment = path.split("#", 2)
    path_without_query, query = path_without_fragment.split("?", 2)
    encoded_path = path_without_query.split("/", -1).map { |segment| ERB::Util.url_encode(segment) }.join("/")
    encoded_path = "/" if encoded_path.blank?

    suffix = +""
    suffix << "?#{query}" if query.present?
    suffix << "##{fragment}" if fragment.present?

    "#{request.base_url}#{encoded_path}#{suffix}"
  end
end
