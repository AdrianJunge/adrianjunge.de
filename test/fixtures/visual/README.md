# Reviewed viewport references

These six PNGs record the existing Home, Timeline, and Java strings article at 390×1000 and 1440×1000, captured from the disposable production container on 2026-09-27 with Chromium and reduced motion. They were visually inspected during the QA implementation for spacing, readable text, navigation, original cards, and the article/TOC layout.

They replace brittle assertions about individual color/radius tokens with a small appearance reference. Browser tests still enforce actual overflow, focus, filtering, navigation, and disclosure behavior. There is no automatic pixel comparison: fonts, dates, and public content change independently of layout.

`bin/check performance` produces current candidates in `tmp/visual-review`, retained by CI. To capture only these views against a running local server:

```sh
VISUAL_BASE_URL=http://127.0.0.1:3000 node scripts/visual-review.mjs
```

Compare all six candidates with these references when changing shared layout/styles. Review the intended differences before replacing any reference file, and record the date/reason here. A passing screenshot capture is not a visual review or an accessibility certification.
