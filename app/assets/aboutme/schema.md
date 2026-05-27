# About me content

CVEs live in `cves.json`, disclosed bounty entries live in `bug_bounties.json`, authored challenges live in `challenges.json`, certificates live in `certificates.json`, and achievements live in `achievements.json`.

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

Challenge, certificate, and achievement entries support these fields:

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

Use `summary` for all visible card text. Keep it empty only for TBA milestone cards.

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
