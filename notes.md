# TODOs
- On small displays like a smarthphone, the font size in codeblocks is a bit too big (it should be equal or a bit smaller than the normal text font size). Moreover the Download button at the top of a post e.g. a writeup, should have more space to the first title.

- Is the "year" attribute in the markdown headers obsolete because of the "publisehd" attribute?

- Add new section "Talks" to the /about page and a new counter at the top
    - The cards should be generic with "title", "date", "link to slides" etc
    - KITCTF web intro 07.05.2026 (https://kitctf.de/intro/)
        => link to slides (https://kitctf.de/talks/2026-05-07-web/web-26-ss.pdf)

- If some writeup got multiple CTF challenge categories then the image icon should be displayed as a circle divided equally by the number of different categories (e.g. having a challenge with web & pwn means the left half is the left half of the web icon and the same for the right have with the pwn icon - same for 3 so every icon got a third of the circle)

- Make the whole design of the sidebar more fitting to the whole website. Currently the sidebar looks too "easy" compared to the rest of the website

- If there is a line wrap (e.g. for the CVE Proof links on the landing page for the Joomla CVE), there shouldn't be a new "line" at the start of the newline. Moreover when hovering the yellow at this line looks weird, use a different color that suits the color pallet and the context

- Reduce the counters on the landing page so there are only “Posts, CVEs, bounties, & more...". I think this reduces the impression of me just wanting "to show off" or whats your opinion on this? What do you think could I change on my website to its not arrogant or superior of me showing what I've done so far? Or is it good how it currently is? Make suggestions what we could improve on my website

- Anstatt Screenshots, Challenge HTML embedden und so aussehen lassen als wäre es wie in einem eigenen Browserfenster
    => https://github.com/felixfbecker/dom-to-svg

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
