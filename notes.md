- for some reason the /about page has less space towards the header bar and the icon at the top at the very start got a darker background than the icons on e.g. /blog or /timeline - there should be only one single source of truth for all the headings of the different pages
- add telegram contact
- replace all adjun37 emails with a placeholder email like todo@adrianjunge.de

# Content
- Next Blog
    - Firedancer Bug Bounty overrun race condition
        - verify every single statement
            - e.g. via debugging with GDB etc
        - what exactly was the fix for this vuln?
        - update date to real publish date
        - received money from bug bounty or audit competition pod?
- Writeup
    - Codewhite bzw Deadsecctf webmiau exploit aufschlüsseln aka CTF Writeup schreiben für Deadsecctf 2025
- Blog
    - Post zu meinen Erfahrungen mit CVE und Bug Bounty Hunting in 2026
        - Projekte die fully vibe coded sind (ChurchCRM)
        - lange triage Zeit zB wordpress 8.5 Monate - suitecrm und joomla auch sehr lange
        - Joomla dafür ziemlich sorgfältig, haben auch interessantes severity system (kein CVSS score sondern was custom) und duplicates zählen vermutlich auch solange der bug noch nicht triaged wurde
            - hatte andere SQLI reported, die aber abgelehnt wurde wegen duplicate aber trotzdem stehen bei 2 meiner 3 CVEs noch weitere Leute mit dabei
- Aboutme to add (with specific dates)
    - Firedancer Bug Bounty
    - Firedancer Audit Competition
    - SuiteCRM CVEs
    - Wordpress Bug Bounty + CVE

# Content Management
- Writeups/Blogs erstellen/editieren/löschen
    - live Rendering des Markdowns

# Misc
- Anstatt Screenshots, Challenge HTML embedden und so aussehen lassen als wäre es wie in einem eigenen Browserfenster
    => https://github.com/felixfbecker/dom-to-svg
- Implement Webmention.io
- Auf Raspberry Pi Server hosten und bei Heroku canceln (auto build pipeline aufbauen für pushes zu main branch)
- `vurlo.de` sichern und DNS einrichten sodass sowohl `adrianjunge.de` als auch `vurlo.de` auf dieselbe IP zeigen
- Email einrichten für Domaine
    - Email redirect von cloud flare
    - referenced emails (todo@adrianjunge.de) replacen
    - Andere email Adresse auf Website verlinken
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
