class CtfController < ApplicationController
  include ActionView::Helpers::SanitizeHelper
  include MarkdownHelper

  def index
    file = File.read(CTF_INFO_PATH)
    @ctfs = JSON.parse(file)
  end

  def which
    file = File.read(CTF_INFO_PATH)
    @ctfs = JSON.parse(file)
    @ctf = @ctfs[params[:which].upcase] if @ctfs.key?(params[:which].upcase)
    @which = params[:which].gsub("..", "").gsub("/", "")
    return unless sanitize_which(@which)

    @ctf_info = sort_writeups_by_published(get_ctf_infos(@which))
    @writeups = @ctf_info.keys
  end

  def writeup
    @which = params[:which].gsub("..", "").gsub("/", "")
    @writeup = params[:writeup].gsub("..", "").gsub("/", "")
    return unless sanitize_writeup(@which, @writeup)

    file_path = BASE_PATH.join(@which, (@writeup + ".md"))

    if file_path.exist? && file_path.file? && file_path.to_s.start_with?(BASE_PATH.to_s)
      @markdown_content = File.read(file_path)
    else
      @markdown_content = "Markdown file not found"
    end
    @ctf_info = get_ctf_info(@markdown_content)
    @headings = get_writeup_headings(@which, @writeup)
    @html_content = render_markdown(@markdown_content)

    @previous_writeup, @next_writeup = get_previous_and_next_writeup(@writeup)
  end

  def feed
    @items = []

    Dir.entries(BASE_PATH).select { |entry|
      File.directory?(BASE_PATH.join(entry)) && !entry.start_with?(".")
    }.each do |which_dir|
      Dir.glob(BASE_PATH.join(which_dir, "*.md")).each do |file_path|
        next unless File.file?(file_path)

        content = File.read(file_path)
        parsed = get_ctf_info(content)
        next unless parsed

        meta = parsed.front_matter || {}
        title = meta["title"].presence || File.basename(file_path, ".md").humanize
        description = (meta["description"].presence || parsed.content.to_s[0, 800]).to_s
        pub_date = begin
                     Time.parse(meta["published"].to_s)
                   rescue StandardError
                     File.ctime(file_path)
                   end

        writeup_slug = File.basename(file_path, ".md")
        link = url_for(controller: "ctf", action: "writeup", which: which_dir, writeup: writeup_slug, only_path: false)

        @items << {
          ctf: which_dir,
          title: sanitize(title),
          description: sanitize(description, tags: %w[p br strong em a code pre img], attributes: %w[href src alt title]),
          link: link,
          pub_date: pub_date,
          guid: link
        }
      end
    end

    @items.sort_by! { |i| -i[:pub_date].to_i }
    respond_to do |format|
      format.rss { render layout: false }
      format.atom { render layout: false }
    end
  end

  def get_previous_and_next_writeup(writeup)
    slug  = writeup.to_s
    items = get_timeline.flat_map { |_, year_items| year_items }

    index = items.index { |i| i[:slug].downcase == slug.downcase }
    return [ nil, nil ] unless index.present?

    nxt  = index > 0 ? items[index - 1] : nil   # newer
    prev = index < items.length - 1 ? items[index + 1] : nil  # older

    [ prev, nxt ]
  end

  private

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
