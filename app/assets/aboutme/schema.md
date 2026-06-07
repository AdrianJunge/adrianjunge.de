# About me content

CVEs live in `cves.json`, disclosed bounty entries live in `bug_bounties.json`, certificates live in `certificates.json`, and achievements live in `achievements.json`. Authored challenges are derived from CTF writeup markdown front matter instead of `challenges.json`.

Finding entries support these fields:

```json
{
  "project": "Affected project",
  "project_url": "https://github.com/org/project",
  "title": "Linked card title",
  "title_url": "https://example.com/advisory",
  "card_url": "https://example.com/overview",
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

Authored CTF challenges are listed on `/about` when a writeup has `optional.authored_challenge` in its markdown front matter:

```yaml
optional:
  authored_challenge:
    event: GPNCTF 2026
    event_url: https://ctftime.org/event/3041
    summary: Summary shown on the about card.
```

The `optional` section may be omitted entirely. Inside `authored_challenge`, `event`, `event_url`, and `summary` are optional; missing values fall back to the CTF name/year, configured CTF website, and writeup description.

Certificate and achievement entries support these fields:

```json
{
  "title": "Achievement title",
  "title_url": "https://example.com",
  "card_url": "https://example.com",
  "category": "Competition",
  "category_url": "https://example.com/category",
  "date": "2026",
  "summary": "Summary shown on the card.",
  "links": [
    { "label": "Reference", "url": "https://example.com" }
  ]
}
```

Use `summary` for all visible card text. Keep pending milestones hidden until they have public summary text.

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
      "summary": "Placed first.",
      "url": "https://example.com/event"
    }
  ]
}
```

Use event-level `id`, `title`, and `date` for timeline entries. Event `summary`, `card_url`, and `url` are optional.
