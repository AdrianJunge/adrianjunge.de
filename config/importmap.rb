# Pin npm packages by running ./bin/importmap

pin "application", preload: true

pin "sidebar", to: "sidebar.js"
pin "landing", to: "landing.js"
pin "terminal", to: "terminal.js"
pin "ctf", to: "ctf.js"
pin "blog", to: "blog.js"
pin "content_filters", to: "content_filters.js"
pin "aboutme", to: "aboutme.js"
pin "page_background", to: "page_background.js"
pin "mathjax_loader", to: "mathjax_loader.js"

pin "xterm", to: "https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.min.js"
pin "xterm-addon-fit", to: "https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0.10.0/lib/addon-fit.min.js"

pin "typed.js", to: "https://cdn.jsdelivr.net/npm/typed.js@2.1.0/dist/typed.module.js"
