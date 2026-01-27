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
/// Collections of colors for layered outlines.
///
/// Ported from `swash/src/palette.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
const CPAL : UInt = 0x4350414c // "CPAL"

///|
/// Iterator over a collection of color palettes.
pub struct ColorPalettes {
  font : FontRef
  b : @internal.BeBytes
  len : Int
}

///|
fn empty_bytes_view() -> BytesView {
  Bytes::from_array([])[:]
}

///|
pub fn ColorPalettes::from_font(font : FontRef) -> ColorPalettes {
  let data = font.table_data(CPAL).unwrap_or(empty_bytes_view())
  let b = @internal.BeBytes::from_view(data)
  let len = b.read_u16(4).unwrap_or(0).reinterpret_as_int()
  ColorPalettes::{ font, b, len }
}

///|
pub fn ColorPalettes::len(self : ColorPalettes) -> Int {
  self.len
}

///|
pub fn ColorPalettes::iter(self : ColorPalettes) -> Iter[ColorPalette] {
  let palettes = self
  let mut pos = 0
  Iter::new(fn() {
    if pos >= palettes.len {
      return None
    }
    let i = pos
    pos = pos + 1
    palettes.get(i)
  })
}

///|
fn ColorPalettes::get(self : ColorPalettes, index : Int) -> ColorPalette? {
  if index < 0 || index >= self.len {
    return None
  }
  let b = self.b
  let version = match b.read_u16(0) {
    None => return None
    Some(v) => v.to_uint16()
  }
  let num_entries = match b.read_u16(2) {
    None => return None
    Some(v) => v.to_uint16()
  }
  let offset = match b.read_u32(8) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let first = match b.read_u16(12 + index * 2) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let offset = offset + first * 4
  Some(ColorPalette::{
    font: self.font,
    b,
    version,
    index: index.to_uint16(),
    num_entries,
    offset,
  })
}

///|
/// Collection of colors.
pub struct ColorPalette {
  font : FontRef
  b : @internal.BeBytes
  version : UInt16
  index : UInt16
  num_entries : UInt16
  offset : Int
}

///|
pub fn ColorPalette::index(self : ColorPalette) -> UInt16 {
  self.index
}

///|
pub fn ColorPalette::name_id(self : ColorPalette) -> StringId? {
  if self.version == 0 {
    return None
  }
  let d = self.b
  let num_palettes = match d.read_u16(4) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let base = 16 + num_palettes * 2
  let labels_offset = match d.read_u32(base) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if labels_offset == 0 {
    return None
  }
  let id = match d.read_u16(labels_offset + self.index.to_int() * 2) {
    None => return None
    Some(v) => v.to_uint16()
  }
  Some(StringId::Other(id))
}

///|
pub fn ColorPalette::name(
  self : ColorPalette,
  language : String?,
) -> LocalizedString? {
  match self.name_id() {
    None => None
    Some(id) => self.font.localized_strings().find_by_id(id, language)
  }
}

///|
pub fn ColorPalette::usability(self : ColorPalette) -> Usability? {
  let flags = match self.flags() {
    None => return None
    Some(v) => v
  }
  match flags & 0b11 {
    0b01 => Some(Usability::Light)
    0b10 => Some(Usability::Dark)
    0b11 => Some(Usability::Both)
    _ => None
  }
}

///|
pub fn ColorPalette::len(self : ColorPalette) -> UInt16 {
  self.num_entries
}

///|
pub fn ColorPalette::is_empty(self : ColorPalette) -> Bool {
  self.num_entries == 0
}

///|
/// Returns the color for the specified entry in RGBA order.
pub fn ColorPalette::get(
  self : ColorPalette,
  index : UInt16,
) -> (Byte, Byte, Byte, Byte) {
  if index >= self.num_entries {
    return ((0).to_byte(), (0).to_byte(), (0).to_byte(), (0).to_byte())
  }
  let offset = self.offset + index.to_int() * 4
  let d = self.b
  let b = d.read_u8(offset).unwrap_or((0).to_byte())
  let g = d.read_u8(offset + 1).unwrap_or((0).to_byte())
  let r = d.read_u8(offset + 2).unwrap_or((0).to_byte())
  let a = d.read_u8(offset + 3).unwrap_or((0).to_byte())
  (r, g, b, a)
}

///|
fn ColorPalette::flags(self : ColorPalette) -> UInt? {
  if self.version == 0 {
    return None
  }
  let d = self.b
  let num_palettes = match d.read_u16(4) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let base = 12 + num_palettes * 2
  let types_offset = match d.read_u32(base) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if types_offset == 0 {
    return None
  }
  d.read_u32(types_offset + self.index.to_int() * 4)
}

///|
/// Theme of a palette with respect to background color.
pub(all) enum Usability {
  /// Usable with light backgrounds.
  Light
  /// Usable with dark backgrounds.
  Dark
  /// Usable with both light and dark backgrounds.
  Both
}

///|
pub fn FontRef::color_palettes(self : FontRef) -> ColorPalettes {
  ColorPalettes::from_font(self)
}
