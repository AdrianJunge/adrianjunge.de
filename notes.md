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
    - googlectf: writeup für mythos
    - smileyctf: writeup schreiben für teemo-v1
        - **web/Teemo's Secret**
        - Autor: Chara
        - Description: O Teemo i wonder what have u looked at
    - DHM
        - DHM TV
        - Perle einer Website
        - proxy-foo
- Aboutme to add (with specific dates)
    - missing SuiteCRM CVE
    - Wordpress Bug Bounty + CVE

# Content Management
- Writeups/Blogs erstellen/editieren/löschen
    - live Rendering des Markdowns

# Misc
- Implement Webmention.io
- Auf Raspberry Pi Server hosten und bei Heroku canceln (auto build pipeline aufbauen für pushes zu main branch)
- implement that e.g. for referenced codeblocks you can show the real line numbers instead of counting up from 1
- global search e.g. as gear icon drop down together with scroll up/down buttons
    => the problem is should the global search be backend or frontend sided
- Anstatt Screenshots, Challenge HTML embedden und so aussehen lassen als wäre es wie in einem eigenen Browserfenster
    => https://github.com/felixfbecker/dom-to-svg
- Auf Raspberry Pi Server hosten und bei Heroku canceln (auto build pipeline aufbauen für pushes zu main branch)
- `vurlo.de` sichern und DNS einrichten sodass sowohl `adrianjunge.de` als auch `vurlo.de` auf dieselbe IP zeigen
- Email einrichten für Domaine
    - Email redirect von cloud flare
    - referenced emails (todo@adrianjunge.de) replacen
    - obfuscated email (no static email addresses present on the page but instead JS only loads the email address at rendering time - antiscraping)
    - Andere email Adresse auf Website verlinken
    - Forwarding
    - als contact angeben in Terminal + Footer

# Fix
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

# Useful websites
- https://www.magnific.com/search?format=search&iconType=standard&last_filter=query&last_value=web+security+3d&query=web+security+3d&type=icon#uuid=54ee002c-935c-4814-a015-fc1f2278474c
- https://www.remove.bg/
