# TODOs
- Fix the scaling of the terminal for high resolution displays
- Search functionality for ctfs and writeups and blogs
    - make ctf tags for each writeup clickable so you can filter for those writeups containing this tag
    - search filter/option for year/date
- For the writeup overview list for every single writeup the authors of that challenge (they should be in the metadata of the markdown file) and link their blog/website if they got one

- fix terminal paths: this is not the same as for the sidebar, in the terminal there should only be the subpaths available from the route
- If pages got the same styling, layout etc they should all share the same files and thus reducing redundancy
- Make landing page suited for small displays like smartphones
- Make the error pages custom instead of just using ruby on rails default

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
