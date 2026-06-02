class CtfController < ApplicationController
  include ActionView::Helpers::SanitizeHelper
  include MarkdownHelper

  def index
    @ctfs = content_repository.ctf_metadata
    @ctf_filters = @ctfs.to_h do |name, ctf|
      directory = ctf["terminal_path"].presence || name.downcase
      metadata = content_repository.post_metadata(BASE_PATH, directory).values

      [ name, {
        years: metadata.filter_map { |entry| content_repository.metadata_year(entry) }.uniq.sort.reverse,
        tags: sorted_filter_values(metadata.flat_map { |entry| content_repository.metadata_tags(entry) }),
        reading_time_minutes: metadata.sum { |entry| entry["reading_time_minutes"].to_i }
      } ]
    end
    @ctf_years = @ctf_filters.transform_values { |filters| filters[:years] }
    @ctf_tags = @ctf_filters.transform_values { |filters| filters[:tags] }
    @ctf_reading_times = @ctf_filters.transform_values do |filters|
      content_repository.format_reading_time(filters[:reading_time_minutes])
    end
    @filter_years = @ctf_years.values.flatten.uniq.sort.reverse
    @filter_tags = sorted_filter_values(@ctf_tags.values.flatten)
    @filter_tag_groups = filter_tag_groups(@filter_tags, topic_label: "Challenge tags")
  end

  def which
    @ctfs = content_repository.ctf_metadata
    @which = params[:which].gsub("..", "").gsub("/", "")
    return unless sanitize_which(@which)

    @ctf_name, @ctf = ctf_metadata_for(@which, @ctfs)
    @ctf_info = sort_writeups_by_published(content_repository.post_metadata(BASE_PATH, @which))
    @writeups = @ctf_info.keys
    @filter_years = @ctf_info.values.filter_map { |metadata| content_repository.metadata_year(metadata) }.uniq.sort.reverse
    @filter_tags = sorted_filter_values(@ctf_info.values.flat_map { |metadata| content_repository.metadata_tags(metadata) })
    @filter_tag_groups = filter_tag_groups(@filter_tags, topic_label: "Challenge tags")
  end

  def writeup
    @which = params[:which].gsub("..", "").gsub("/", "")
    @writeup = params[:writeup].gsub("..", "").gsub("/", "")
    @ctfs = content_repository.ctf_metadata
    @ctf_name, @ctf = ctf_metadata_for(@which, @ctfs)
    @markdown_content = safe_markdown_content(BASE_PATH, @which, @writeup, render_error: true)
    return unless @markdown_content

    @ctf_info = content_repository.post_metadata_from(parse_markdown_content(@markdown_content))
    return render_error_page(:not_found) if content_repository.hidden_content?(@ctf_info)

    @headings = get_headings_from_content(@markdown_content)
    @html_content = render_markdown(@markdown_content)
    @challenge_file = writeup_public_asset("files", "zip")
    @pdf_writeup = writeup_public_asset("writeups", "pdf")

    @previous_writeup, @next_writeup = get_previous_and_next_writeup(@writeup)
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

  def get_previous_and_next_writeup(writeup)
    slug  = writeup.to_s
    items = content_repository.ctf_posts

    index = items.index { |i| i[:slug].downcase == slug.downcase }
    return [ nil, nil ] unless index.present?

    nxt  = index > 0 ? items[index - 1] : nil   # newer
    prev = index < items.length - 1 ? items[index + 1] : nil  # older

    [ prev, nxt ]
  end

  private

  def ctf_metadata_for(which, ctfs = content_repository.ctf_metadata)
    match = ctfs.find do |name, ctf|
      name.to_s.casecmp?(which.to_s) || ctf["terminal_path"].to_s.casecmp?(which.to_s)
    end

    return [ match.first, match.last ] if match

    [
      which.to_s.upcase,
      {
        "terminal_path" => which,
        "logo" => nil,
        "website" => nil,
        "writeups" => "/ctf/#{which}"
      }
    ]
  end

  def writeup_public_asset(public_dir, extension)
    year = @ctf_info["year"].to_s
    asset_name = @ctf_info["challengefiles"].to_s
    return nil unless year.match?(/\A\d{4}\z/) && safe_public_asset_segment?(asset_name)

    relative_path = File.join(@which, year, "#{asset_name}.#{extension}")
    base_path = Rails.root.join("public", "ctf", public_dir)
    absolute_path = base_path.join(@which, year, "#{asset_name}.#{extension}")
    real_base = base_path.realpath.to_s
    real_file = absolute_path.realpath.to_s

    return nil unless real_file.start_with?(real_base + File::SEPARATOR)
    return nil unless File.file?(real_file)

    {
      basename: File.basename(real_file),
      relative_path: relative_path,
      absolute_path: real_file,
      size: File.size(real_file)
    }
  rescue Errno::ENOENT
    nil
  end

  def safe_public_asset_segment?(value)
    value.match?(/\A[\w.-]+\z/) && !%w[. ..].include?(value)
  end

  def sort_writeups_by_published(writeups_info)
    writeups_info.sort_by do |_, info|
      begin
        -Time.parse(info["published"].to_s).to_i
      rescue StandardError
        0
      end
    end.to_h
  end
end
