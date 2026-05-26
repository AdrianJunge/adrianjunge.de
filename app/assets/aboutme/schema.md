# About me content

CVEs live in `cves.json`, disclosed bounty entries live in `bug_bounties.json`, certificates live in `certificates.json`, and achievements live in `achievements.json`.

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

Certificate and achievement entries support these fields:

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
