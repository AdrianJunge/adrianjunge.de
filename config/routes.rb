Rails.application.routes.draw do
  root "landing#index"

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
end
