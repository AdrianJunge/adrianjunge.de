class SearchController < ApplicationController
  self.requires_modern_browser = false

  def data
    documents = SiteSearch.new(repository: content_repository).documents
    return unless stale?(etag: [ "site-search", SiteSearch::VERSION, documents ], public: true)

    render json: { version: SiteSearch::VERSION, documents: documents }
  end
end
