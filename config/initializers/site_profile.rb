Rails.application.config.to_prepare do
  Rails.application.routes.default_url_options.merge!(SiteProfile.url_options)
end
