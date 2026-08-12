class CtfController < ApplicationController
  include ActionView::Helpers::SanitizeHelper
  include MarkdownHelper

  def index
    @ctfs = content_repository.ctf_metadata
    @ctf_filters = @ctfs.to_h do |name, ctf|
      directory = ctf["terminal_path"].presence || name.downcase
      metadata = content_repository.ctf_posts_for_event(directory).map { |post| post[:metadata] }

      [ name, {
        years: metadata.filter_map { |entry| content_repository.metadata_year(entry) }.uniq.sort.reverse,
        tags: sorted_filter_values(metadata.flat_map { |entry| content_repository.metadata_tags(entry) }),
        writeup_count: metadata.length,
        reading_time_minutes: metadata.sum { |entry| entry["reading_time_minutes"].to_i }
      } ]
    end
    @ctf_years = @ctf_filters.transform_values { |filters| filters[:years] }
    @ctf_tags = @ctf_filters.transform_values { |filters| filters[:tags] }
    @ctf_writeup_counts = @ctf_filters.transform_values { |filters| filters[:writeup_count] }
    @ctf_reading_times = @ctf_filters.transform_values do |filters|
      content_repository.format_reading_time(filters[:reading_time_minutes])
    end
    @filter_years = @ctf_years.values.flatten.uniq.sort.reverse
    @filter_tags = sorted_filter_values(@ctf_tags.values.flatten)
    @filter_tag_groups = filter_tag_groups(@filter_tags, topic_label: "Challenge tags")
  end

  def which
    event = content_repository.ctf_event(params[:which])
    return render_error_page(:not_found) unless event

    @ctfs = content_repository.ctf_metadata
    @which = event[:slug]
    @ctf_name = event[:name]
    @ctf = event[:metadata]
    @ctf_info = content_repository.ctf_posts_for_event(@which).to_h do |post|
      [ post[:slug], post[:metadata] ]
    end
    @writeups = @ctf_info.keys
    @filter_years = @ctf_info.values.filter_map { |metadata| content_repository.metadata_year(metadata) }.uniq.sort.reverse
    @filter_tags = sorted_filter_values(@ctf_info.values.flat_map { |metadata| content_repository.metadata_tags(metadata) })
    @filter_tag_groups = filter_tag_groups(@filter_tags, topic_label: "Challenge tags")
  end

  def writeup
    post = content_repository.ctf_post(params[:which], params[:writeup])
    return render_error_page(:not_found) unless post

    event = content_repository.ctf_event(post[:directory])
    return render_error_page(:not_found) unless event

    @which = post[:directory]
    @writeup = post[:slug]
    @ctfs = content_repository.ctf_metadata
    @ctf_name = event[:name]
    @ctf = event[:metadata]
    @markdown_content = post[:content]
    @ctf_info = post[:metadata]

    @headings = []
    @html_content = render_markdown(@markdown_content, headings: @headings)
    @challenge_file = content_repository.ctf_asset_for(post, :challenge)
    @pdf_writeup = content_repository.ctf_asset_for(post, :writeup)

    @previous_writeup, @next_writeup = get_previous_and_next_writeup(@which, @writeup)
  end

  def feed
    @items = content_repository.ctf_posts.map do |item|
      parsed = content_repository.parse_markdown(item[:content])
      description = (item[:description].presence || parsed&.content.to_s[0, 800]).to_s
      link = url_for(controller: "ctf", action: "writeup", which: item[:directory], writeup: item[:slug], only_path: false)

      {
        ctf: item[:directory],
        title: sanitize(item[:title]),
        description: sanitize(description, tags: %w[p br strong em a code pre img], attributes: %w[href src alt title]),
        link: link,
        pub_date: item[:published],
        guid: link
      }
    end

    respond_to do |format|
      format.rss { render layout: false }
      format.atom { render layout: false }
    end
  end

  private

  def get_previous_and_next_writeup(which, writeup)
    adjacent_content_items(content_repository.ctf_posts, writeup, directory: which)
  end
end
