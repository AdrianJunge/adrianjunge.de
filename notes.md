# TODOs
- http://127.0.0.1:3000/about => make just like on the landing page the row with the counters each clickable to scroll to that section
- For Redundant CSS create custom tailwindcss classes e.g. for all the button hover stuff etc - thus go through all the available Tailwind css classes and remove redundancies/inconsistencies e.g. for rounded edges it should always be 3xl or create custom classes
- there should only be one single truth of color pattern for tailwindcss vs variables.scss - remove the variable.scss one and fix everything

- Make the page suiting SEO (search engine optimization)
- xterm css should be fetched via CDN instead of having the xterm.css file in the repo

- Add for the writeups shiny Contest win labels for the following writeups and apply the links behind these labels so you are able to see the proof
    - [ ] Davor aber die PDF Urkunde downloaden und in public folder stellen
    - UMDCTF: https://discord.com/channels/938193497306067065/938196910039269406/1412823165213605959
    - CSCG: PDF Urkunde mit attachen wie bei https://morrisbe.de/ctf/supercluster

- Scrape https://dimasc.tf/ for features and make suggestions on what to be added to my website

- remove mathjax from `application.html.erb` into JS file
- review all the boiler plate code from ruby on Rails and remove what is not needed/necessary

- Tim um Feedback bitten

# Nochmal testen
- tailwindcss flowbite plugin fixen
    => evtl neues Setup und dann Code übernehmen
- Scrolling out/in führt dazu dass e.g.
    - ctf overview die Fonts in den vergrößerten Kreise viel zu groß ist
    - writeups overview die Boxen nicht verkleinert werden, aber die Fonts
    - "Table of content" Überschrift zu klein ist/unproportional zum Rest

# Content
- Blog
    - Java Strings
    - Codewhite bzw Deadsecctf webmiau exploit aufschlüsseln aka CTF Writeup schreiben für Deadsecctf 2025
- Aboutme adds
    - Firedancer Bug Bounty
    - Firedancer Audit Competition
    - Wordpress Bug Bounty + CVE
    - SuiteCRM CVEs
- Talks held
    - KITCTF web intro
- Writeups
    - Anstatt Screenshots, Challenge HTML embedden und so aussehen lassen als wäre es wie in einem eigenen Browserfenster
        => https://github.com/felixfbecker/dom-to-svg

# Content Management
- Writeups/Blogs erstellen/editieren/löschen
    - live Rendering des Markdowns

# Misc
- `vurlo.de` sichern und DNS einrichten sodass sowohl `adrianjunge.de` als auch `vurlo.de` auf dieselbe IP zeigen
- Email einrichten für Domaine
    - Forwarding
    - als contact angeben in Terminal + Footer

# Fix
- Writeups und paths für ctf file zips in Datenbank verschieben anstatt .md files einzulesen
    => kein Potenzial mehr für Path Traversals
    => Brakeman ignore Test wieder rausnehmen (config/brakeman.ignore)
    => keine Probleme mehr mit upper/lowercasing um bestimmte writeups zu finden etc
- Pipeline aufsetzen, welche automatisch neue oder edited Markdown Writeups zu HTML parsed, sodass nicht bei jedem Request unnötig neu geparsed wird
- Heroku Warnings durchgehen und evtl fixen

# Latex to Markdown find and replace
## regex
`\\textit\{([^}]+)\}`
`**$1**`
## regex
`\\command\{([^}]+)\}`
`$1`
## regex
`\\href\{([^}]+)\}\{([^}]+)\}`
`[$2]($1)`
## normal
`\`
``
