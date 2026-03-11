# Milky2018/moon_swash

MoonBit port of Rust `swash` for font metadata, text shaping, and glyph scaling/rendering.

## Install

Add imports in your `moon.pkg`:

```text
import {
  "Milky2018/moon_swash" @swash,
  "Milky2018/moon_swash/shape" @swash_shape,
  "Milky2018/moon_swash/scale" @swash_scale,
}
```

Optional modules:

```text
import {
  "Milky2018/moon_swash/iter" @swash_iter,
  "Milky2018/moon_swash/proxy" @swash_proxy,
}
```

## Quickstart

### Load a Font

```moonbit
let data : Bytes = ...
let font = @swash.FontRef::from_offset(data, 0).unwrap()
```

### Shape Text

```moonbit
let cx = @swash_shape.ShapeContext::new()
let shaper = cx.builder(font).size(14.0).build()
shaper.add_str("Hello, world!")
shaper.shape_with(fn(cluster) {
  // cluster.glyphs() / cluster.source() ...
  cluster |> ignore
})
```

### Scale and Render a Glyph

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

## Modules

- `Milky2018/moon_swash`: core font APIs (`FontRef`, attributes, metrics, variations, palettes, strikes).
- `Milky2018/moon_swash/shape`: OpenType/AAT shaping and glyph clustering.
- `Milky2018/moon_swash/scale`: outline/bitmap scaling and rendering.

## SubpixelMask Notes
- `Content::SubpixelMask` stores per-channel coverage in RGB; the alpha channel is unused by the rasterizer.
- `Image::to_rgba8(base_color)` converts `Mask` / `SubpixelMask` into **premultiplied** RGBA8 and sets alpha to `max(r, g, b)` coverage (modulated by `base_color[3]`).
- Use premultiplied-alpha blending when compositing (`src = 1`, `dst = 1 - srcA`).

## License

Apache-2.0.
