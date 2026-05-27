class CtfFilesController < ApplicationController
  BASE_DIR = Rails.root.join("public", "ctf", "files").to_s.freeze

  def download
    requested = params[:file_path].to_s
    requested = requested.sub(/\A\//, "")

    unless requested.match?(/\A[\w\-.\/]+\z/)
      return head :bad_request
    end

    candidate = File.join(BASE_DIR, requested)

    real_base   = File.expand_path(BASE_DIR)
    real_file   = File.expand_path(candidate)

    unless real_file.start_with?(real_base + File::SEPARATOR) || real_file == real_base
      return head :forbidden
    end

    unless File.exist?(real_file) && File.file?(real_file)
      return head :not_found
    end

    content_type = Rack::Mime.mime_type(File.extname(real_file), "application/octet-stream")

    send_file real_file,
              disposition: "attachment",
              filename: File.basename(real_file),
              type: content_type
  end
end
