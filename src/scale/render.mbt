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
            image.data = Array::makei(n, _ => b'\x00')
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
        image.data = Array::makei(base_size, _ => b'\x00')
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
                  scaler.state.val._scratch0 = Array::makei(n, _ => b'\x00')
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
      _ => continue
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
  let image = Image::new()
  if self.render_into(scaler, glyph_id, image) {
    Some(image)
  } else {
    None
  }
}

///|
test "Render builder scaffolding" {
  let r = Render::new([Source::Outline])
    .format(@zeno.Format::Subpixel)
    .offset(@zeno.Vector::new(0.25, 0.75))
  inspect(r.sources.length(), content="1")
}

///|
test "Render renders outline into an alpha mask" {
  let data = mk_min_ttf_with_one_simple_glyph()
  let font = @swash.FontRef::from_offset(data, 0).unwrap()
  let cx = ScaleContext::new()
  let scaler = cx.builder(font).size(1000.0).build()
  let r = Render::new([Source::Outline]).format(@zeno.Format::Alpha)
  let img = r.render(scaler, (0).to_uint16()).unwrap()
  let p = img.placement()
  inspect(p.width.reinterpret_as_int() > 0, content="true")
  inspect(p.height.reinterpret_as_int() > 0, content="true")
  inspect(img.data().length() > 0, content="true")
  let mut sum = 0
  for b in img.data() {
    sum = sum + b.to_int()
  }
  inspect(sum > 0, content="true")
}

///|
test "Render renders COLR/CPAL layers into an RGBA image" {
  let data = mk_min_ttf_with_colr_two_layer_glyph()
  let font = @swash.FontRef::from_offset(data, 0).unwrap()
  let cx = ScaleContext::new()
  let scaler = cx.builder(font).size(1000.0).build()
  let r = Render::new([Source::ColorOutline((0).to_uint16())]).format(
    @zeno.Format::Alpha,
  )
  let img = r.render(scaler, (0).to_uint16()).unwrap()
  inspect(
    match img.source() {
      ColorOutline(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match img.content() {
      Color => true
      _ => false
    },
    content="true",
  )
  // RGBA buffer size should match placement.
  let p = img.placement()
  let expected = (p.width * p.height * 4U).reinterpret_as_int()
  inspect(img.data().length(), content=expected.to_string())
  // Ensure some non-zero alpha got blended in.
  let mut sum = 0
  let data = img.data()
  let mut i = 3
  while i < data.length() {
    sum = sum + data[i].to_int()
    i = i + 4
  }
  inspect(sum > 0, content="true")
}
