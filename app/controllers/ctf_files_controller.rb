class CtfFilesController < ApplicationController
  def download
    requested_id = params[:id].to_s
    return head :not_found unless requested_id.match?(ContentRepository::CTF_ASSET_ID_PATTERN)

    asset = content_repository.ctf_assets.find { |candidate| candidate[:id] == requested_id }
    return head :not_found unless asset

    response.headers["X-Content-Type-Options"] = "nosniff"
    send_file asset[:path],
              disposition: asset[:disposition],
              filename: asset[:basename],
              type: asset[:content_type]
  end
end
