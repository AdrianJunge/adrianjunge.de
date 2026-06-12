Rails.application.routes.draw do
  root "landing#index"

  get "/about", to: "aboutme#index", as: :about
  get "/aboutme", to: redirect("/about")
  get "/sitemap.xml", to: "seo#sitemap", defaults: { format: :xml }
  get "/feed", to: "feeds#show", as: :feed, defaults: { format: :rss }
  get "/feed.xml", to: "feeds#show", as: :feed_xml, defaults: { format: :rss }
  get "/feed.atom", to: "feeds#show", defaults: { format: :atom }
  get "/feed.json", to: "feeds#show", as: :feed_json, defaults: { format: :json }

  get "/ctf/files/*file_path", to: "ctf_files#download", as: :ctf_file_download

  get "/ctf/feed.atom", to: redirect("/feed.atom")
  get "/ctf/feed.json", to: redirect("/feed.json")
  get "/ctf/feed.xml", to: redirect("/feed.xml")
  get "/ctf/feed", to: redirect("/feed.xml"), as: :ctf_feed

  get "/ctf", to: "ctf#index"
  get "/ctf/:which", to: "ctf#which"
  get "/ctf/:which/:writeup", to: "ctf#writeup"

  get "/timeline", to: "posts#timeline", as: :timeline
  get "/posts-timeline", to: redirect("/timeline")

  get "/blog/feed.atom", to: redirect("/feed.atom")
  get "/blog/feed.json", to: redirect("/feed.json")
  get "/blog/feed.xml", to: redirect("/feed.xml")
  get "/blog/feed", to: redirect("/feed.xml"), as: :blog_feed

  get "/blog", to: "blog#index", as: :blog
  get "/blog/:which", to: "blog#show", as: :blog_post

  match "/400", to: "errors#bad_request", via: :all
  match "/404", to: "errors#not_found", via: :all
  match "/422", to: "errors#unprocessable_entity", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
  match "*unmatched", to: "errors#not_found", via: :all, constraints: ->(request) { !request.path.start_with?("/rails/") }
end
