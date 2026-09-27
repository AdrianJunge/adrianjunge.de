# Pin npm packages by running ./bin/importmap

pin "application", preload: true

pin "sidebar", to: "sidebar.js"
pin "landing", to: "landing.js"
pin "blog", to: "blog.js"
pin "content_filters", to: "content_filters.js"
pin "aboutme", to: "aboutme.js"
pin "mathjax_loader", to: "mathjax_loader.js"

pin "site_search", to: "site_search.js", preload: false
pin "site_search_launcher", to: "site_search_launcher.js", preload: false
