# TODOs
- Add to landing page more counters like CVEs, Bug Bounties, Certificates, Achievements but in their own clickable area
    - change title from "Welcome to my flag collection - CTF writeups & more" to something more fitting, this is not only about ctfs anymore
- Adde Features und Info tables wie bei https://dimasc.tf/ zu meiner Website wie zB die Blog Übersicht und die Filter die man applyen kann
- Nur die skallierung vom Terminal kommt nicht so gut auf hochauflösenden Display - wenn man die seite auf 200% skalliert gehts aber sehr gut.
- Writeup shiny Contest win Label adden zB für umdctf, cscg etc und verlinken
    - UMDCTF: https://discord.com/channels/938193497306067065/938196910039269406/1412823165213605959
    - CSCG: PDF Urkunde mit attachen wie bei https://morrisbe.de/ctf/supercluster
- Search functionality for ctfs and writeups and blogs
    - ctf tags bei den einzelnen Writeups clickable machen sodass gefiltert wird nach dem tag unter den writeups
    - Suchfilter und Filteroption nach Jahr/Datum
- “My Challenges” Section adden zu CTF (unter Angabe bei welchem CTF das veröffentlicht wurde und Link zu meinem Writeup dazu)
    => Übersicht über meine Challenges
    => jeweils redirect zu bereits published Post
- Writeup
    - hints anzeigen über die Metadaten und Template erweitern
    - Autoren auflisten evtl auch deren Blog verlinken
    - Hintergrund Image des CTFs
- If pages got the same styling, layout etc they should all share the same files and thus reducing redundancy
- Landing page anpassen für kleine Bildschirme
- Fehler pages custom machen
- Redundantes bzw alles an CSS wie zB für die ganzen Buttons das Hoverzeug custom tailwindcss classes anlegen
    - alle Tailwind classes durchgehen und Redundanzen/Inkonsistenzen entfernen zB abgerundete Ecken immer 3xl bzw custom class anlegen
- single truth of color pattern für tailwindcss vs variables.scss
- SEO (search engine optimization)
- xterm + flowbite css über CDN fetchen anstatt eigene file im repo

# Content
- Aboutme adds
    - Firedancer Bug Bounty
    - Firedancer Audit Competition
    - Wordpress Bug Bounty + CVE
    - Joomla CVEs
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
