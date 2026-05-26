Rails.application.routes.draw do
  root "landing#index"

  get "/about", to: "aboutme#index", as: :about
  get "/aboutme", to: redirect("/about")

  get "/ctf/files/*file_path", to: "ctf_files#download", as: :ctf_file_download

  get "/ctf/feed", to: "ctf#feed", as: :ctf_feed, defaults: { format: :rss }
  get "/ctf/feed.atom", to: "ctf#feed", defaults: { format: :atom }

  get "/ctf", to: "ctf#index"
  get "/ctf/:which", to: "ctf#which"
  get "/ctf/:which/:writeup", to: "ctf#writeup"

  get "/posts-timeline", to: "posts#timeline", as: :posts

  get "/blog/feed", to: "blog#feed", as: :blog_feed, defaults: { format: :rss }
  get "/blog/feed.atom", to: "blog#feed", defaults: { format: :atom }

  get "/blog", to: "blog#index", as: :blog
  get "/blog/:which", to: "blog#show", as: :blog_post

  match "/400", to: "errors#bad_request", via: :all
  match "/404", to: "errors#not_found", via: :all
  match "/422", to: "errors#unprocessable_entity", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
  match "*unmatched", to: "errors#not_found", via: :all, constraints: ->(request) { !request.path.start_with?("/rails/") }
end
