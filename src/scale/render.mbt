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
