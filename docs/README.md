# moon_swash Shaping Demo Page

This folder contains a static web demo for `moon_swash` shaping output.

## What it does

- Lets users input text, size, script, and direction.
- Lets users choose bundled fonts from a dropdown.
- Runs `moon_swash_svg_dump.wasm` in-browser via WASI shim.
- Renders the resulting SVG directly on the page.
- Supports custom font upload.
- Includes preset samples across supported formats (`ttf`, `otf`, `ttc`).
- Supports share URLs (query-string encoded text/settings for deep links).

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
- `assets/*-wght.ttf`: bundled TTF fonts
- `assets/*.otf`: bundled OTF fonts
- `assets/*.ttc`: bundled TTC collections
- `assets/*-OFL.txt`: bundled font licenses
- `assets/*-NOTICE.txt`: generated collection/license mapping notes
- `wasm/moon_swash_svg_dump/`: wasm source package (tracked, no private dependency)

## Rebuild wasm asset

From repo root:

```bash
./docs/build-wasm.sh
```

## GitHub Pages

Set repository GitHub Pages source to `master` branch, `/docs` folder.
