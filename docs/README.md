# moon_swash Shaping Demo Page

This folder contains a static web demo for `moon_swash` shaping output.

## What it does

- Lets users input text, size, script, and direction.
- Lets users choose bundled fonts from a dropdown.
- Runs `moon_swash_svg_dump.wasm` in-browser via WASI shim.
- Renders the resulting SVG directly on the page.
- Supports custom font upload.

## Local preview

From repo root:

```bash
python3 -m http.server 4173 --directory docs
```

Then open:

- `http://127.0.0.1:4173/index.html`

## Files

- `index.html`: demo UI
- `app.js`: in-browser WASI execution and rendering logic
- `assets/moon_swash_svg_dump.wasm`: shaping-to-SVG wasm binary
- `assets/NotoNaskhArabic-wght.ttf`: bundled Arabic font
- `assets/NotoSans-Latin-wght.ttf`: bundled Latin font
- `assets/NotoSansHebrew-wght.ttf`: bundled Hebrew font
- `assets/*-OFL.txt`: bundled font licenses
- `wasm/moon_swash_svg_dump/`: wasm source package (tracked, no private dependency)

## Rebuild wasm asset

From repo root:

```bash
./docs/build-wasm.sh
```

## GitHub Pages

Set repository GitHub Pages source to `master` branch, `/docs` folder.
