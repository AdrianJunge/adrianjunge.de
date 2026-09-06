# Pin npm packages by running ./bin/importmap

pin "application", preload: true

pin "sidebar", to: "sidebar.js"
pin "landing", to: "landing.js"
pin "terminal_launcher", to: "terminal_launcher.js"
pin "terminal", to: "terminal.js", preload: false
pin "blog", to: "blog.js"
pin "content_filters", to: "content_filters.js"
pin "aboutme", to: "aboutme.js"
pin "mathjax_loader", to: "mathjax_loader.js"

pin "xterm", to: "https://cdn.jsdelivr.net/npm/@xterm/xterm@6.0.0/lib/xterm.mjs", preload: false
pin "xterm-addon-fit", to: "https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0.11.0/lib/addon-fit.mjs", preload: false

pin "typed.js", to: "https://cdn.jsdelivr.net/npm/typed.js@2.1.0/dist/typed.module.js", preload: false
