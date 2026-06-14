# About me content

CVEs live in `cves.json`, disclosed bounty entries live in `bug_bounties.json`, certificates live in `certificates.json`, talks live in `talks.json`, and achievements live in `achievements.json`. Authored challenges are derived from CTF writeup markdown front matter instead of `challenges.json`.

Finding entries support these fields:

```json
{
  "project": "Affected project",
  "project_url": "https://github.com/org/project",
  "icon": "other/project.svg",
  "title": "Linked card title",
  "title_url": "https://example.com/advisory",
  "card_url": "https://example.com/overview",
  "timeline_group": "shared-topic-id",
  "cve_id": "CVE-YYYY-NNNN",
  "cwe_id": "CWE-NNN",
  "severity": "High",
  "short_summary": "One-line vulnerability summary.",
  "summary": "Longer vulnerability summary.",
  "references": [
    { "label": "Report", "url": "https://example.com/report" }
  ],
  "timeline": [
    { "date": "2026-01-01", "event": "Reported to maintainer" }
  ]
}
```

`cve_id` and `cwe_id` render as clickable chips when they contain real IDs. Leave them empty for pending or non-CVE findings.
Finding cards are only collapsible when they contain real detail fields such as `summary` or `timeline`.
Set `"hidden": true` on pending JSON records or achievement events that should remain in source but not render publicly. Markdown posts use `draft: true` in front matter for the same behavior.
Set `timeline_group` on multiple content sources when they should collapse into one `/timeline` card, for example an about entry and a blog post about the same certification.

Authored CTF challenges are listed on `/about` when a writeup has `optional.authored_challenge` in its markdown front matter:

```yaml
event_url: https://gpn24.ctf.kitctf.de/
solves: 5
points: 405
optional:
  authored_challenge:
    event: GPNCTF 2026
    summary: Summary shown on the about card.
```

The `optional` section may be omitted entirely. Use top-level `event_url` for the original event platform shown in writeup titles and authored-challenge badges. Inside `authored_challenge`, `event` and `summary` are optional; missing values fall back to the CTF name plus `ctf_year` and writeup description.

Certificate, talk, and achievement entries support these fields:

```json
{
  "title": "Achievement title",
  "title_url": "https://example.com",
  "icon": "other/achievement.svg",
  "card_url": "https://example.com",
  "timeline_group": "shared-topic-id",
  "category": "Competition",
  "category_url": "https://example.com/category",
  "date": "2026",
  "summary": "Summary shown on the card.",
  "links": [
    { "label": "Reference", "url": "https://example.com" }
  ]
}
```

Use `summary` for all visible card text. Use `category_url` when the category chip should link to a public reference, such as talk slides. Keep pending milestones hidden until they have public summary text.
Use `timeline_group` only for sources that represent the same real item; equal values merge in `/timeline`.
Use `icon` for the transparent asset rendered on `/about`, `/timeline`, and landing featured cards. Prefer an existing project or event logo; otherwise add a small transparent SVG under `app/assets/images/other/`.

Achievement entries can group dated events so every event becomes its own search and timeline item:

```json
{
  "title": "Competition series",
  "title_url": "https://example.com",
  "card_url": "https://example.com",
  "category": "CTF Competition",
  "category_url": "https://example.com/category",
  "summary": "Optional section summary.",
  "links": [
    { "label": "Reference", "url": "https://example.com" }
  ],
  "events": [
    {
      "id": "competition-2026",
      "title": "Competition 2026 #1",
      "date": "2026-01-01",
      "icon": "ctf/example.svg",
      "summary": "Placed first.",
      "url": "https://example.com/event",
      "timeline_group": "shared-event-id"
    }
  ]
}
```

Use event-level `id`, `title`, and `date` for timeline entries. Event `summary`, `card_url`, and `url` are optional.
