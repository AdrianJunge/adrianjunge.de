# Image Badge Scripts

These helpers generate the circular black-rim badges used by the site image assets.

Install the only dependency:

```bash
python -m venv .venv-images
. .venv-images/bin/activate
python -m pip install -r scripts/images/requirements.txt
```

Render a logo on a white inner circle:

```bash
python scripts/images/render_badge.py source.png content/images/originals/ctf/example.png
```

Render a full-background logo with a tight rim:

```bash
python scripts/images/render_badge.py source.png content/images/originals/ctf/example.png \
  --mode full \
  --inner-margin 24
```

Render a logo while removing a light rectangular background connected to the image edges:

```bash
python scripts/images/render_badge.py source.png content/images/originals/ctf/example.png \
  --background edge \
  --logo-scale 0.58
```

Create a quick visual comparison sheet:

```bash
python scripts/images/contact_sheet.py /tmp/badges.png app/assets/images/ctf/*.png
```

## Web exports

Run `python scripts/images/export.py` after changing a source. This reproducibly
generates 96/192/384px WebP logo variants, compact PNG fallbacks, a dedicated
1200×630 social card, and `config/image_variants.json`. Article screenshots stay
at their original resolution; lossless WebP is selected only when smaller.
The manifest supplies intrinsic dimensions, including SVG view boxes, to Rails.
New originals belong under `content/images/originals`, mirroring their intended
logical asset paths. The export script never overwrites these originals.

`python scripts/images/export.py --check` verifies all manifest files, dimensions,
and actual formats without modifying them. Normal Rails builds consume the
committed exports; Python/Pillow are authoring-only dependencies.

Run `python -m unittest discover -s scripts/images -p 'test_*.py'` for authoring
regressions covering JPEG fallback, source preservation, transparency and sizing.
Optimize vectors with `npm exec -- svgo INPUT.svg -o OUTPUT.svg`, preserving a
copy under `content/images/originals` first, then rebuild the image manifest.

The previous category artwork and unused profile exports are retained in
`content/images/archive`, outside Rails' public asset paths. AVIF is deferred:
these small logos already compress well with WebP, and screenshots prioritize
lossless text. The social card uses installed DejaVu Sans; pass `--font-dir` if
its directory differs from `/usr/share/fonts/truetype/dejavu`.
