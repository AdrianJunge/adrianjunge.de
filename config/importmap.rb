# Pin npm packages by running ./bin/importmap

pin "application", preload: true

pin "sidebar", to: "sidebar.js"
pin "landing", to: "landing.js"
pin "terminal", to: "terminal.js"
pin "ctf", to: "ctf.js"
pin "blog", to: "blog.js"

pin "xterm", to: "https://cdn.jsdelivr.net/npm/xterm/lib/xterm.min.js"
pin "xterm-addon-fit", to: "https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0.10.0/lib/addon-fit.min.js"

pin "mathjax", to: "https://cdn.jsdelivr.net/npm/mathjax@3/es5/startup.js", preload: true
pin "mathjax/input/tex-full.js", to: "https://cdn.jsdelivr.net/npm/mathjax@3/es5/input/tex-full.js"
pin "mathjax/output/chtml.js",   to: "https://cdn.jsdelivr.net/npm/mathjax@3/es5/output/chtml.js"

pin "typed.js", to: "https://cdn.jsdelivr.net/npm/typed.js@2.1.0/dist/typed.module.js"
