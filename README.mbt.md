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

    // Optional: API parity with swash-reference module paths
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
img |> ignore
```

## API Compatibility Notes

- `Milky2018/moon_swash/iter` and `Milky2018/moon_swash/proxy` exist for API parity with swash-reference module paths.
- They currently provide stable type aliases (so downstream import paths match), while the underlying implementations live in the main packages.

## Verify It Works

Basic:

```bash
moon test
moon check
```

Diff against the Rust reference implementation (requires `wasmtime`, `cargo`, and a checkout at `./swash-reference`):

```bash
python3 tools/verify_swash_reference.py --font /path/to/font.ttf
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
