# TODOs
- remove mathjax from `application.html.erb` into JS file
- review all the boiler plate code from ruby on Rails and remove what is not needed/necessary

- the background is already turning from dark blue to very dark blue, but I think it could be even better having the transition stretched over every page dynamically depending on how long the page is and reaching the very dark blue at the end of the page

- Scrape https://dimasc.tf/ for features and make suggestions on what to be added to my website

- thoroughly review and test every single feature and page - is there anything that could be made much easier by using ruby or node packages?

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
