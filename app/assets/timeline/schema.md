# Timeline milestones

Add an entry to `events.json` for an event that should appear on `/timeline`
without creating a card on `/about`. For example:

```json
{
  "id": "example-milestone",
  "title": "Example milestone",
  "date": "2026-10-29",
  "summary": "One sentence describing what happened.",
  "tags": ["Security Research"],
  "icon": "other/achievement.svg",
  "url": "/blog/example-post",
  "modified": "2026-10-29"
}
```

`id`, `title`, and `date` are required. The title must contain non-whitespace
text. IDs use lowercase letters, digits, and hyphens and must be unique in this
catalog. For a single event, `date` is when it happened and controls sorting.
A month such as `2019-09` sorts at the end of that month; a year such as `2019`
sorts at the end of that year.
The timeline displays exact dates as `29 Oct 2026`, months as `Sep 2019`, and
years as `2019`. These labels do not change the date used for sorting.

Use an optional `display_date` to express approximate timing for a single event:

```json
{
  "id": "early-practice",
  "title": "Early practice",
  "date": "2019-09",
  "display_date": "Around Sep 2019"
}
```

For an activity period, keep its start in `date` and add `end_date`:

```json
{
  "id": "ongoing-practice",
  "title": "Practicing CTF challenges",
  "date": "2023-10",
  "end_date": "2025"
}
```

The visible label is generated from those fields (`Oct 2023–2025`), so do not
also supply `display_date`. Both endpoints can be a year, month, exact date or
timestamp, but cannot themselves be year ranges. An end date cannot precede
the start. A year or month endpoint covers that whole year or month.

Periods sort and group by when they started, using the beginning of an imprecise
start month/year. Year filters include every covered year: the example appears
under 2023, 2024 and 2025 while remaining in the 2023 chronological group. For
March–April 2023, use `date: "2023-03"` and `end_date: "2023-04"`; its generated
label is `Mar–Apr 2023`. Search uses the same visible label, and month starts
retain month precision in the page markup.

`modified` or `updated` is optional and records when the timeline listing was
edited for the sitemap. Do not use the event date as an edit date unless they
really coincide.

The `summary`, `tags`, `icon`, and `url` fields are optional. Tags are plain
strings used by the timeline filters. CVE identifiers appear first in cards and
link directly to their CVE.org records; their filter-panel buttons still filter.
Without `icon`, the card uses a light timeline icon. Without `url`, the card stays static.
Every event has a stable `/timeline#timeline-event-<id>`
anchor for direct links and global search. Use `hidden: true` or `draft: true`
to keep a valid entry out of the published timeline and search.
