# About me content

All `/about` JSON collections use the same compact card format. CVEs live in
`cves.json`, authored CTF challenges in `challenges.json`, certificates in
`certificates.json`, talks in `talks.json`, and achievements in
`achievements.json`.

```json
{
  "id": "stable-card-id",
  "title": "Card title",
  "subtitle": "Optional short line shown under the title",
  "icon": "other/achievement.svg",
  "url": "/blog/example",
  "summary": "Expanded summary text shown inside the dropdown.",
  "timeline_group": "shared-topic-id",
  "tags": [
    "High",
    { "label": "CVE-2026-48898", "url": "https://www.cve.org/CVERecord?id=CVE-2026-48898" },
    { "label": "CWE-284", "url": "https://cwe.mitre.org/data/definitions/284.html" }
  ],
  "links": [
    { "label": "Repository", "url": "https://github.com/example/project" },
    { "label": "Advisory source", "url": "https://example.com/advisory" }
  ],
  "timeline": [
    {
      "id": "event-id",
      "title": "Published advisory",
      "date": "2026-01-02",
      "summary": "Optional event detail.",
      "url": "https://example.com/event"
    }
  ]
}
```

Only `id` and `title` are required. Omit empty fields instead of storing blank
strings. Hidden or draft entries may stay in the JSON files, but they should
still only contain real values that would be shown once public.

Use `subtitle` for the short line directly below the card title. Use `summary`
for the expanded body text. Cards become dropdowns when they have `summary`,
`links`, or `timeline`.

Use `tags` for every chip shown in the card header. Plain strings link to the
timeline filter; objects with `url` render as direct links. CVE, CWE, severity,
difficulty, and known category labels receive their visual classes from the
shared tag helper, so they do not need special JSON fields.

Use `links` only for references shown inside the expanded card body. A CWE or CVE
chip is just a tag link, not a separate field.

Use `timeline` for both disclosure history and achievement events. Achievement
timeline entries become separate `/timeline` search/index items. Use
`timeline_group` only when two content sources represent the same real item and
should merge in `/timeline`.

Dates belong to `timeline` entries, not to the card itself. For content with a
single relevant date, add one timeline event such as `Published challenge`,
`Earned certificate`, or `Presented talk`.

Authored CTF challenges should be listed in `challenges.json` using the same
card format:

```json
{
  "id": "scanwich-station",
  "title": "Scanwich Station",
  "icon": "ctf/gpnctf.png",
  "url": "/ctf/gpnctf/Scanwich%20Station",
  "summary": "Short description of the challenge.",
  "tags": [
    { "label": "GPNCTF 2026", "url": "https://gpn24.ctf.kitctf.de/" },
    "Hard",
    { "label": "Writeup", "url": "/ctf/gpnctf/Scanwich%20Station" }
  ],
  "timeline": [
    {
      "date": "2026-06-05",
      "title": "Published at GPNCTF 2026."
    }
  ]
}
```

The writeup front matter can still mark the corresponding post with
`optional.authored_challenge`; that drives the CTF/writeup badges and acts as a
fallback source only when `challenges.json` is empty:

```yaml
event_url: https://gpn24.ctf.kitctf.de/
solves: 5
points: 405
optional:
  authored_challenge:
    event: GPNCTF 2026
    # Summary belongs in challenges.json when that file defines the card.
```

The `optional` section may be omitted. `event` inside `authored_challenge` is
optional; a missing value falls back to the CTF name plus `ctf_year`. When
`challenges.json` is empty, authored cards are derived from writeup metadata and
use the writeup description as their summary.
