# About me content

CVEs live in `cves.json`, disclosed bounty entries live in `bug_bounties.json`, authored challenges live in `challenges.json`, certificates live in `certificates.json`, and achievements live in `achievements.json`.

Finding entries support these fields:

```json
{
  "project": "Affected project",
  "project_url": "https://github.com/org/project",
  "title": "Linked card title",
  "title_url": "https://example.com/advisory",
  "cve_id": "CVE-YYYY-NNNN",
  "severity": "High",
  "short_summary": "One-line vulnerability summary.",
  "summary": "Longer vulnerability summary.",
  "tested_version": "1.2.3",
  "impact": "Practical impact.",
  "github_advisories": [
    { "label": "GHSA-...", "url": "https://github.com/advisories/GHSA-..." }
  ],
  "references": [
    { "label": "Report", "url": "https://example.com/report" }
  ],
  "timeline": [
    { "date": "2026-01-01", "event": "Reported to maintainer" }
  ]
}
```

`cve_id` is optional. Use `TBA` for pending CVEs, and omit the field for findings where no CVE is expected.
Finding cards are only collapsible when they contain real detail fields such as `summary`, `tested_version`, `impact`, `github_advisories`, or `timeline`.

Challenge, certificate, and achievement entries support these fields:

```json
{
  "title": "Achievement title",
  "title_url": "https://example.com",
  "category": "Competition",
  "date": "2026",
  "summary": "One-line summary.",
  "details": [
    "Optional detail."
  ],
  "links": [
    { "label": "Reference", "url": "https://example.com" }
  ]
}
```

`summary` and `details` are optional for TBA milestone cards.

Achievement entries can group dated events so every event becomes its own search and timeline item:

```json
{
  "title": "Competition series",
  "title_url": "https://example.com",
  "category": "CTF Competition",
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

Use event-level `id`, `title`, and `date` for timeline entries. Event `summary`, `details`, `links`, and `url` are optional.
