# TODOs
- on the very top of each page is some space used for the "taskbar-item" and thus shifting everything down, this is weird
- Add to aboutme a “My Challenges” Section and write which ctf this was published for, short description and the redirect to the writeup - in this case its only the "smile at me" challenge from gpnctf

- Scrape https://dimasc.tf/ for features and make suggestions on what to be added to my website

- Fix the scaling of the terminal for high resolution displays
- Search functionality for ctfs and writeups and blogs
    - make ctf tags for each writeup clickable so you can filter for those writeups containing this tag
    - search filter/option for year/date
- Writeup
    - add a hints section in the metadata of the markdown files and template
    - for the writeup overview list the authors and link their blog/website if they got one

- If pages got the same styling, layout etc they should all share the same files and thus reducing redundancy
- Landing page anpassen für kleine Bildschirme
- Fehler pages custom machen
- Redundantes bzw alles an CSS wie zB für die ganzen Buttons das Hoverzeug custom tailwindcss classes anlegen
    - alle Tailwind classes durchgehen und Redundanzen/Inkonsistenzen entfernen zB abgerundete Ecken immer 3xl bzw custom class anlegen
- single truth of color pattern für tailwindcss vs variables.scss
- SEO (search engine optimization)
- xterm + flowbite css über CDN fetchen anstatt eigene file im repo

- Add for the writeups shiny Contest win labels for the following writeups and apply the links behind these labels so you are able to see the proof
    - [ ] Davor aber die PDF Urkunde downloaden und in public folder stellen
    - UMDCTF: https://discord.com/channels/938193497306067065/938196910039269406/1412823165213605959
    - CSCG: PDF Urkunde mit attachen wie bei https://morrisbe.de/ctf/supercluster

# Content
- Aboutme adds
    - Firedancer Bug Bounty
    - Firedancer Audit Competition
    - Wordpress Bug Bounty + CVE
    - SuiteCRM CVEs
- Blog
    - Java Strings
    - Codewhite bzw Deadsecctf webmiau exploit aufschlüsseln
- Talks held
    - KITCTF web intro
- Upcoming
    - Real World Exploitation (Bug Bounty/CVE)
    - Custom Tools
- Writeups
    - Anstatt Screenshots, Challenge HTML embedden und so aussehen lassen als wäre es wie in einem eigenen Browserfenster
        => https://github.com/felixfbecker/dom-to-svg

# Content Management
- Writeups/Blogs erstellen/editieren/löschen
    - live Rendering des Markdowns

# Nochmal testen
- tailwindcss flowbite plugin fixen
    => evtl neues Setup und dann Code übernehmen
- Scrolling out/in führt dazu dass e.g.
    - ctf overview die Fonts in den vergrößerten Kreise viel zu groß ist
    - writeups overview die Boxen nicht verkleinert werden, aber die Fonts
    - "Table of content" Überschrift zu klein ist/unproportional zum Rest

# Misc
- mathjax aus `application.html.erb` moven in JS file
- `vurlo.de` sichern und DNS einrichten sodass sowohl `adrianjunge.de` als auch `vurlo.de` auf dieselbe IP zeigen
- kompletten boiler plate Code von Rails durchgehen und das rauswerfen was ich nicht brauche
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
