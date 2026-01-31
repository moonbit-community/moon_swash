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
/// Rendered glyph image.
///
/// Ported from upstream `swash/src/scale/image.rs` (Apache-2.0 OR MIT).

///|
/// Content of a scaled glyph image.
pub(all) enum Content {
  /// 8-bit alpha mask.
  Mask
  /// 32-bit RGBA subpixel mask.
  SubpixelMask
  /// 32-bit RGBA bitmap.
  Color
}

///|
pub fn Content::default() -> Content {
  Content::Mask
}

///|
/// Scaled glyph image.
pub struct Image {
  /// Source of the image.
  mut source : Source
  /// Content of the image.
  mut content : Content
  /// Offset and size of the image.
  mut placement : Placement
  /// Raw image data.
  mut data : Array[Byte]
}

///|
pub fn Image::new() -> Image {
  Image::{
    source: Source::default(),
    content: Content::default(),
    placement: Placement::{ left: 0, top: 0, width: 0U, height: 0U },
    data: [],
  }
}

///|
pub fn Image::clear(self : Image) -> Unit {
  self.source = Source::default()
  self.content = Content::default()
  self.placement = Placement::{ left: 0, top: 0, width: 0U, height: 0U }
  self.data.clear()
}

///|
pub fn Image::source(self : Image) -> Source {
  self.source
}

///|
pub fn Image::content(self : Image) -> Content {
  self.content
}

///|
pub fn Image::placement(self : Image) -> Placement {
  self.placement
}

///|
/// Zero-copy view of the raw image data.
///
/// This is preferred over `Image::data()` when integrating with renderers that
/// can upload from an `ArrayView[Byte]` directly.
pub fn Image::data_view(self : Image) -> ArrayView[Byte] {
  self.data
}

///|
/// Copying accessor for image data.
///
/// Note: this clones the underlying bytes. Prefer `Image::data_view()` for
/// zero-copy access.
pub fn Image::data(self : Image) -> Bytes {
  Bytes::from_array(self.data)
}

///|
/// Converts `Mask` / `SubpixelMask` content into an RGBA8 buffer in-place.
///
/// - `base_color` is `[r, g, b, a]` (0..255). The output is *premultiplied*
///   RGBA8, suitable for standard premultiplied-alpha blending.
/// - For `SubpixelMask`, the input stores per-channel coverage in RGB (alpha
///   channel is unused by the rasterizer). We multiply each channel by its
///   corresponding coverage and set output alpha to `max(r, g, b)` coverage.
///
/// Returns false if the image buffer/placement is inconsistent or
/// `base_color` is invalid.
pub fn Image::to_rgba8(self : Image, base_color : Array[Byte]) -> Bool {
  if base_color.length() < 4 {
    return false
  }
  let w = self.placement.width
  let h = self.placement.height
  let pixels = (w * h).reinterpret_as_int()
  if pixels <= 0 {
    // Empty image; normalize to RGBA8 for convenience.
    self.data.clear()
    self.content = Content::Color
    return true
  }
  let br = base_color[0].to_int().reinterpret_as_uint()
  let bg = base_color[1].to_int().reinterpret_as_uint()
  let bb = base_color[2].to_int().reinterpret_as_uint()
  let ba = base_color[3].to_int().reinterpret_as_uint()
  match self.content {
    Content::Color => true
    Content::Mask => {
      if self.data.length() < pixels {
        return false
      }
      let out_len = pixels * 4
      // Grow in-place if possible; write backwards to avoid clobbering input.
      if self.data.capacity() < out_len {
        let out = Array::makei(out_len, _ => b'\x00')
        for i in 0..<pixels {
          let m = self.data[i].to_int().reinterpret_as_uint()
          let a = m * ba / 255U
          let r = br * a / 255U
          let g = bg * a / 255U
          let b = bb * a / 255U
          let o = i * 4
          out[o + 0] = r.reinterpret_as_int().to_byte()
          out[o + 1] = g.reinterpret_as_int().to_byte()
          out[o + 2] = b.reinterpret_as_int().to_byte()
          out[o + 3] = a.reinterpret_as_int().to_byte()
        }
        self.data = out
      } else {
        if self.data.length() < out_len {
          for _ in self.data.length()..<out_len {
            self.data.push(b'\x00')
          }
        } else if self.data.length() > out_len {
          self.data.truncate(out_len)
        }
        let mut i = pixels - 1
        while i >= 0 {
          let m = self.data[i].to_int().reinterpret_as_uint()
          let a = m * ba / 255U
          let r = br * a / 255U
          let g = bg * a / 255U
          let b = bb * a / 255U
          let o = i * 4
          self.data[o + 0] = r.reinterpret_as_int().to_byte()
          self.data[o + 1] = g.reinterpret_as_int().to_byte()
          self.data[o + 2] = b.reinterpret_as_int().to_byte()
          self.data[o + 3] = a.reinterpret_as_int().to_byte()
          i = i - 1
        }
      }
      self.content = Content::Color
      true
    }
    Content::SubpixelMask => {
      if self.data.length() < pixels * 4 {
        return false
      }
      // In-place transform (same buffer size).
      for i in 0..<pixels {
        let o = i * 4
        let mr = self.data[o + 0].to_int().reinterpret_as_uint()
        let mg = self.data[o + 1].to_int().reinterpret_as_uint()
        let mb = self.data[o + 2].to_int().reinterpret_as_uint()
        let ar = mr * ba / 255U
        let ag = mg * ba / 255U
        let ab = mb * ba / 255U
        let a = if ar > ag {
          if ar > ab {
            ar
          } else {
            ab
          }
        } else if ag > ab {
          ag
        } else {
          ab
        }
        self.data[o + 0] = (br * ar / 255U).reinterpret_as_int().to_byte()
        self.data[o + 1] = (bg * ag / 255U).reinterpret_as_int().to_byte()
        self.data[o + 2] = (bb * ab / 255U).reinterpret_as_int().to_byte()
        self.data[o + 3] = a.reinterpret_as_int().to_byte()
      }
      self.content = Content::Color
      true
    }
  }
}

///|
test "Image::new produces empty image" {
  let img = Image::new()
  inspect(
    match img.source() {
      Outline => true
      _ => false
    },
    content="true",
  )
  inspect(
    match img.content() {
      Mask => true
      _ => false
    },
    content="true",
  )
  inspect(img.placement().width, content="0")
  inspect(img.data().length(), content="0")
}

///|
test "Image::clear resets fields" {
  let img = Image::new()
  img.clear()
  inspect(
    match img.source() {
      Outline => true
      _ => false
    },
    content="true",
  )
  inspect(
    match img.content() {
      Mask => true
      _ => false
    },
    content="true",
  )
  inspect(img.data().length(), content="0")
}

///|
test "Image::data_view is zero-copy length view" {
  let img = Image::new()
  inspect(img.data_view().length(), content="0")
}

///|
test "Image::to_rgba8 converts Mask to premultiplied RGBA8" {
  let img = Image::new()
  img.placement = Placement::{ left: 0, top: 0, width: 2U, height: 1U }
  img.content = Content::Mask
  img.data = [b'\x00', b'\xFF']
  let ok = img.to_rgba8([
    (10).to_byte(),
    (20).to_byte(),
    (30).to_byte(),
    (255).to_byte(),
  ])
  inspect(ok, content="true")
  inspect(
    match img.content() {
      Color => true
      _ => false
    },
    content="true",
  )
  let d = img.data_view()
  inspect(d.length(), content="8")
  // Pixel 0: alpha=0 => premultiplied => all zeros.
  inspect(d[0].to_int(), content="0")
  inspect(d[1].to_int(), content="0")
  inspect(d[2].to_int(), content="0")
  inspect(d[3].to_int(), content="0")
  // Pixel 1: alpha=255 => premultiplied => base RGB.
  inspect(d[4].to_int(), content="10")
  inspect(d[5].to_int(), content="20")
  inspect(d[6].to_int(), content="30")
  inspect(d[7].to_int(), content="255")
}

///|
test "Image::to_rgba8 converts SubpixelMask using per-channel coverage" {
  let img = Image::new()
  img.placement = Placement::{ left: 0, top: 0, width: 1U, height: 1U }
  img.content = Content::SubpixelMask
  // Coverage only on the red subpixel.
  img.data = [(255).to_byte(), (0).to_byte(), (0).to_byte(), (0).to_byte()]
  let ok = img.to_rgba8([
    (100).to_byte(),
    (200).to_byte(),
    (50).to_byte(),
    (255).to_byte(),
  ])
  inspect(ok, content="true")
  let d = img.data_view()
  inspect(d[0].to_int(), content="100")
  inspect(d[1].to_int(), content="0")
  inspect(d[2].to_int(), content="0")
  inspect(d[3].to_int(), content="255")
}
