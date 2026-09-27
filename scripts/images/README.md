# Image Badge Scripts

These helpers generate the circular black-rim badges used by the site image assets.

Install the pinned Python dependency and the locked SVG optimizer (Node version
from `.node-version`). Linux also needs the `fonts-dejavu-core` system package:

```bash
python -m venv .venv-images
. .venv-images/bin/activate
python -m pip install -r scripts/images/requirements.txt
npm ci
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

`python scripts/images/export.py --check` regenerates all exports into a temporary
directory and compares every manifest descriptor and export with the committed
files. PNGs are checked for identical pixels, dimensions, color mode, palette,
and metadata; other formats must match byte for byte. Different Pillow wheels
can use zlib or zlib-ng and produce different PNG compression for the same image.
It catches missing manifest entries, changed originals with
stale exports (even at identical dimensions), missing variants, orphan variants,
and incorrect image formats. It never modifies sources or published files.
This can take several minutes because screenshot WebP encoding is lossless.
Use the locked Pillow/SVGO versions and DejaVu Sans fonts for reproducible output;
updates to the encoders may require regenerating the committed exports.
Normal Rails builds consume the committed exports; Python/Pillow and SVGO are
authoring-only dependencies.

Run `python -m unittest discover -s scripts/images -p 'test_*.py'` for authoring
regressions covering JPEG fallback, source preservation, transparency, sizing,
manifest completeness and stale/missing/orphan outputs.
SVG originals under `content/images/originals` are optimized automatically with
the locked SVGO version during export. Keep new vector originals there, mirroring
their intended public paths. A normal export also removes unused generated
variants; authoring originals remain unchanged.

AVIF is deferred: these small logos already compress well with WebP, and screenshots prioritize
lossless text. The social card uses installed DejaVu Sans; pass `--font-dir` if
its directory differs from `/usr/share/fonts/truetype/dejavu`.
