# moon_swash_svg_dump

WASI CLI that shapes text with `moon_swash` and dumps composed glyph outlines as a full SVG document.

## Build

```bash
cd /Users/zhengyu/Documents/projects/moon_swash/docs/wasm/moon_swash_svg_dump
moon build --target wasm --release -d
```

## Usage

```bash
cd /Users/zhengyu/Documents/projects/moon_swash
wasmtime run --dir . \
  --preload spectest=docs/wasm/moon_swash_svg_dump/spectest.wasm \
  docs/wasm/moon_swash_svg_dump/_build/wasm/release/build/moon_swash_svg_dump.wasm \
  docs/assets/NotoNaskhArabic-wght.ttf "السَّلَامُ عَلَيْكُمْ" 18 arabic rtl \
  > /tmp/moon_arabic.svg
```

Arguments:

1. `font_path`
2. `text` (supports `@file:<path>`)
3. `size` (optional, default `14`)
4. `script` (optional: `latin|arabic|hebrew`, default `latin`)
5. `direction` (optional: `ltr|rtl`, default `ltr`)

Then open `/tmp/moon_arabic.svg` in a browser.
