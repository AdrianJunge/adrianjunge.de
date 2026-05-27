# Image Badge Scripts

These helpers generate the circular black-rim badges used by the site image assets.

Install the only dependency:

```bash
python -m pip install Pillow
```

Render a logo on a white inner circle:

```bash
python app/assets/images/scripts/render_badge.py source.png app/assets/images/ctf/example.png
```

Render a full-background logo with a tight rim:

```bash
python app/assets/images/scripts/render_badge.py source.png app/assets/images/ctf/example.png \
  --mode full \
  --inner-margin 24
```

Render a logo while removing a light rectangular background connected to the image edges:

```bash
python app/assets/images/scripts/render_badge.py source.png app/assets/images/ctf/example.png \
  --background edge \
  --logo-scale 0.58
```

Create a quick visual comparison sheet:

```bash
python app/assets/images/scripts/contact_sheet.py /tmp/badges.png app/assets/images/ctf/*.png
```
