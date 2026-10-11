class SearchController < ApplicationController
  self.requires_modern_browser = false

  def data
    documents = SiteSearch.new(repository: content_repository).documents.map do |document|
      icon = document.fetch(:icon)
      source = ContentImageHelper.image_attributes(icon.fetch(:src)).fetch(:src)
      document.merge(icon: icon.merge(src: helpers.asset_path(source)))
    end
    return unless stale?(etag: [ "site-search", SiteSearch::VERSION, documents ], public: true)

    render json: { version: SiteSearch::VERSION, documents: documents }
  end
end
