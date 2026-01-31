# Milky2018/moon_swash

MoonBit port of the Rust `swash` reference implementation.

This repo provides:
- Font metadata APIs (`FontRef`, attributes, localized strings, variation axes/instances, metrics, palettes, strikes).
- Text shaping (`Milky2018/moon_swash/shape`).
- Scaling and rendering (`Milky2018/moon_swash/scale`).

## Install

Add dependencies in your `moon.pkg.json`:

```json
{
  "import": [
    { "path": "Milky2018/moon_swash", "alias": "swash" },
    { "path": "Milky2018/moon_swash/shape", "alias": "swash_shape" },
    { "path": "Milky2018/moon_swash/scale", "alias": "swash_scale" },

    // Optional: API parity with upstream swash module paths
    { "path": "Milky2018/moon_swash/iter", "alias": "swash_iter" },
    { "path": "Milky2018/moon_swash/proxy", "alias": "swash_proxy" }
  ]
}
```

## Quickstart

Load a font:

```moonbit
let data : Bytes = ...
let font = @swash.FontRef::from_offset(data, 0).unwrap()
```

Shape a string:

```moonbit
let cx = @swash_shape.ShapeContext::new()
let shaper = cx.builder(font).size(14.0).build()
shaper.add_str("Hello, world!")
shaper.shape_with(fn(cluster) {
  // cluster.glyphs() / cluster.source() ...
  cluster |> ignore
})
```

Scale and render a glyph:

```moonbit
let gid = font.charmap().map(('Q').to_int().reinterpret_as_uint())
let scx = @swash_scale.ScaleContext::new()
let scaler = scx.builder(font).size(14.0).hint(true).build()

let render = @swash_scale.Render::new([@swash_scale.Source::Outline])
let img = render.render(scaler, gid).unwrap()

// Zero-copy pixel access:
let pixels = img.data_view()
pixels |> ignore

// GPU-friendly RGBA8 (premultiplied):
let white = [(255).to_byte(), (255).to_byte(), (255).to_byte(), (255).to_byte()]
img.to_rgba8(white) |> ignore
let rgba8 = img.data_view()
rgba8 |> ignore
```

## SubpixelMask Notes

- `Content::SubpixelMask` stores per-channel coverage in RGB; the alpha channel is unused by the rasterizer.
- `Image::to_rgba8(base_color)` converts `Mask` / `SubpixelMask` into **premultiplied** RGBA8 and sets alpha to `max(r, g, b)` coverage (modulated by `base_color[3]`).
- Use premultiplied-alpha blending when compositing (`src = 1`, `dst = 1 - srcA`).

## API Compatibility Notes

- `Milky2018/moon_swash/iter` and `Milky2018/moon_swash/proxy` exist for API parity with upstream swash module paths.
- They currently provide stable type aliases (so downstream import paths match), while the underlying implementations live in the main packages.

## Verify It Works

Basic:

```bash
moon test
moon check
```

Diff against an external reference dumper (requires `wasmtime`):

```bash
python3 tools/verify_reference.py --font /path/to/font.ttf --ref-cmd /path/to/reference_dump_json
```

Notes:
- The verifier uses a numeric tolerance (default `--tol 0.02`) because outline floats may differ by ~1/64 between MoonBit and Rust due to fixed-point rounding details in the outline scaler.
- For stricter float comparison, try `--tol 0.001` (may fail on some fonts).

## Development

- `moon check` - lint/type-check
- `moon test` - run tests
- `moon fmt` - format
- `moon info` - regenerate `.mbti` interface files

Standard workflow before committing:

```bash
moon info && moon fmt
moon test
moon check
```

## License

Apache-2.0.
