// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Renderer scaffolding.
///
/// Ported from upstream `swash::scale::Render`.
pub struct Render {
  sources : Array[Source]
  format : @zeno.Format
  offset : @zeno.Vector
  transform : @zeno.Transform?
  embolden : Double
  foreground : Array[Byte]
  style : @zeno.Style

  fn new(sources : Array[Source]) -> Render
}

///|
fn ensure_zeroed(buf : Array[Byte], len : Int) -> Array[Byte] {
  if len <= 0 {
    buf.clear()
    return buf
  }
  if buf.capacity() < len {
    return Array::makei(len, _ => b'\x00')
  }
  if buf.length() < len {
    for _ in buf.length()..<len {
      buf.push(b'\x00')
    }
  } else if buf.length() > len {
    buf.truncate(len)
  }
  // zeno subpixel masks only write RGB channels; always clear to avoid stale
  // alpha/unused channels when reusing buffers.
  for i in 0..<len {
    buf[i] = b'\x00'
  }
  buf
}

///|
pub fn Render::new(sources : Array[Source]) -> Render {
  Render::{
    sources,
    format: @zeno.Format::Alpha,
    offset: @zeno.Vector::new(0.0, 0.0),
    transform: None,
    embolden: 0.0,
    foreground: [b'\x80', b'\x80', b'\x80', b'\xFF'],
    style: @zeno.Style::default(),
  }
}

///|
pub fn Render::format(self : Render, format : @zeno.Format) -> Render {
  Render::{
    sources: self.sources,
    format,
    offset: self.offset,
    transform: self.transform,
    embolden: self.embolden,
    foreground: self.foreground,
    style: self.style,
  }
}

///|
pub fn Render::style(self : Render, style : @zeno.Style) -> Render {
  Render::{
    sources: self.sources,
    format: self.format,
    offset: self.offset,
    transform: self.transform,
    embolden: self.embolden,
    foreground: self.foreground,
    style,
  }
}

///|
pub fn Render::offset(self : Render, offset : @zeno.Vector) -> Render {
  Render::{
    sources: self.sources,
    format: self.format,
    offset,
    transform: self.transform,
    embolden: self.embolden,
    foreground: self.foreground,
    style: self.style,
  }
}

///|
pub fn Render::transform(self : Render, transform : @zeno.Transform?) -> Render {
  Render::{
    sources: self.sources,
    format: self.format,
    offset: self.offset,
    transform,
    embolden: self.embolden,
    foreground: self.foreground,
    style: self.style,
  }
}

///|
pub fn Render::embolden(self : Render, strength : Double) -> Render {
  Render::{
    sources: self.sources,
    format: self.format,
    offset: self.offset,
    transform: self.transform,
    embolden: strength,
    foreground: self.foreground,
    style: self.style,
  }
}

///|
pub fn Render::default_color(self : Render, color : Array[Byte]) -> Render {
  Render::{
    sources: self.sources,
    format: self.format,
    offset: self.offset,
    transform: self.transform,
    embolden: self.embolden,
    foreground: color,
    style: self.style,
  }
}

///|
pub fn Render::render_into(
  self : Render,
  scaler : Scaler,
  glyph_id : @swash.GlyphId,
  image : Image,
) -> Bool {
  for source in self.sources {
    match source {
      Source::Outline => {
        let outline = scaler.state.val.outline
        outline.clear()
        if !scaler.scale_outline_into(glyph_id, outline) {
          continue
        }
        if self.embolden != 0.0 {
          outline.embolden(self.embolden, self.embolden)
        }
        if self.transform is Some(t) {
          outline.transform(t)
        }
        let placement = @zeno.Mask::with_scratch(
            outline.path(),
            scaler.state.val.rcx,
          )
          .format(self.format)
          .origin(@zeno.Origin::BottomLeft)
          .style(self.style)
          .offset(self.offset)
          .render_offset(self.offset)
          .inspect((fmt, w, h) => {
            let n = fmt.buffer_size(w, h)
            image.data = ensure_zeroed(image.data, n)
          })
          .render_into(image.data)
        image.placement = placement
        image.content = match self.format {
          @zeno.Format::Alpha => Content::Mask
          _ => Content::SubpixelMask
        }
        image.source = Source::Outline
        return true
      }
      Source::ColorOutline(palette_index) => {
        let outline = scaler.state.val.outline
        outline.clear()
        if !scaler.scale_color_outline_into(glyph_id, outline) {
          continue
        }
        if self.transform is Some(t) {
          outline.transform(t)
        }
        let palettes = match to_skrifa_font(scaler.font) {
          None => None
          Some(skrifa_font) => Some(skrifa_font.color_palettes())
        }
        let total_bounds = outline.bounds()
        // Take offset into account when placing glyph.
        let base_x = (total_bounds.min.x() + self.offset.x()).floor().to_int()
        let base_y = (total_bounds.min.y() + self.offset.y()).ceil().to_int()
        let base_w = total_bounds.width().ceil().to_int().reinterpret_as_uint()
        let base_h = total_bounds.height().ceil().to_int().reinterpret_as_uint()
        let base_size = (base_w * base_h * 4U).reinterpret_as_int()
        image.data = ensure_zeroed(image.data, base_size)
        image.placement = Placement::{
          left: base_x,
          top: base_h.reinterpret_as_int() + base_y,
          width: base_w,
          height: base_h,
        }
        let mut ok = true
        for i in 0..<outline.len() {
          match outline.get(i) {
            None => {
              ok = false
              break
            }
            Some(layer) => {
              scaler.state.val._scratch0.clear()
              let placement = @zeno.Mask::with_scratch(
                  layer.path(),
                  scaler.state.val.rcx,
                )
                .format(@zeno.Format::Alpha)
                .origin(@zeno.Origin::BottomLeft)
                .style(self.style)
                .offset(self.offset)
                .render_offset(self.offset)
                .inspect((fmt, w, h) => {
                  let n = fmt.buffer_size(w, h)
                  scaler.state.val._scratch0 = ensure_zeroed(
                    scaler.state.val._scratch0,
                    n,
                  )
                })
                .render_into(scaler.state.val._scratch0)
              let color = match layer.color_index() {
                None => self.foreground
                Some(ci) =>
                  match palettes {
                    None => self.foreground
                    Some(ps) =>
                      match ps.color(palette_index.to_int(), ci.to_int()) {
                        None => self.foreground
                        Some(c) => [c.r(), c.g(), c.b(), c.a()]
                      }
                  }
              }
              blit(
                scaler.state.val._scratch0,
                placement.width,
                placement.height,
                placement.left - base_x,
                base_h.reinterpret_as_int() + base_y - placement.top,
                color,
                image.data,
                base_w,
                base_h,
              )
            }
          }
        }
        if ok {
          image.source = Source::ColorOutline(palette_index)
          image.content = Content::Color
          return true
        }
      }
      Source::Bitmap(mode) => {
        if !scaler.has_bitmaps() {
          continue
        }
        if scaler.scale_bitmap_into(glyph_id, mode, image) {
          return true
        }
      }
      Source::ColorBitmap(mode) => {
        if !scaler.has_color_bitmaps() {
          continue
        }
        if scaler.scale_color_bitmap_into(glyph_id, mode, image) {
          return true
        }
      }
    }
  }
  false
}

///|
pub fn Render::render(
  self : Render,
  scaler : Scaler,
  glyph_id : @swash.GlyphId,
) -> Image? {
  let image = Image()
  if self.render_into(scaler, glyph_id, image) {
    Some(image)
  } else {
    None
  }
}

///|
test "Render builder scaffolding" {
  let r = Render([Source::Outline])
    .format(@zeno.Format::Subpixel)
    .offset(@zeno.Vector::new(0.25, 0.75))
  inspect(r.sources.length(), content="1")
}
