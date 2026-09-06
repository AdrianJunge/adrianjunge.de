Rails.application.routes.draw do
  content_slug = /[a-z0-9]+(?:-[a-z0-9]+)*/
  writeup_slug = /[A-Za-z0-9]+(?:(?:%20|[ _-])[A-Za-z0-9]+)*/i
  asset_id = /[0-9a-f]{64}/

  root "landing#index"
  get "/up", to: "rails/health#show", as: :rails_health_check

  get "/about", to: "aboutme#index", as: :about
  get "/aboutme", to: redirect("/about")
  get "/sitemap.xml", to: "seo#sitemap", defaults: { format: :xml }
  get "/feed", to: "feeds#show", as: :feed, defaults: { format: :rss }
  get "/feed.xml", to: "feeds#show", as: :feed_xml, defaults: { format: :rss }
  get "/feed.atom", to: "feeds#show", defaults: { format: :atom }
  get "/feed.json", to: "feeds#show", as: :feed_json, defaults: { format: :json }

  get "/ctf/resources/:id",
      to: "ctf_files#download",
      as: :ctf_file_download,
      constraints: { id: asset_id },
      format: false

  get "/ctf/feed.atom", to: redirect("/feed.atom")
  get "/ctf/feed.json", to: redirect("/feed.json")
  get "/ctf/feed.xml", to: redirect("/feed.xml")
  get "/ctf/feed", to: redirect("/feed.xml"), as: :ctf_feed

  get "/ctf", to: "ctf#index"
  get "/ctf/:which", to: "ctf#which", constraints: { which: content_slug }, format: false
  get "/ctf/:which/:writeup",
      to: "ctf#writeup",
      constraints: { which: content_slug, writeup: writeup_slug },
      format: false

  get "/timeline", to: "posts#timeline", as: :timeline
  get "/posts-timeline", to: redirect("/timeline")

  get "/blog/feed.atom", to: redirect("/feed.atom")
  get "/blog/feed.json", to: redirect("/feed.json")
  get "/blog/feed.xml", to: redirect("/feed.xml")
  get "/blog/feed", to: redirect("/feed.xml"), as: :blog_feed

  get "/blog", to: "blog#index", as: :blog
  get "/blog/:which", to: "blog#show", as: :blog_post, constraints: { which: content_slug }, format: false

  match "/400", to: "errors#bad_request", via: :all
  match "/404", to: "errors#not_found", via: :all
  match "/422", to: "errors#unprocessable_entity", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
  match "*unmatched", to: "errors#not_found", via: :all, constraints: ->(request) { !request.path.start_with?("/rails/") }
end
