# Milky2018/moon_swash

MoonBit port of the Rust `swash` reference implementation (see `./swash-reference`).

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
    { "path": "Milky2018/moon_swash/scale", "alias": "swash_scale" }
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
