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
/// Mapping characters to nominal glyph identifiers.
///
/// Ported from `swash/src/charmap.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
/// Proxy for rematerializing a character map.
pub struct CharmapProxy {
  offset : UInt
  format : UInt
  symbol : Bool
}

///|
pub fn CharmapProxy::from_font(font : FontRef) -> CharmapProxy {
  match @internal.subtable(font) {
    None => CharmapProxy::{ offset: 0, format: 0, symbol: false }
    Some((offset, format, symbol)) => CharmapProxy::{ offset, format, symbol }
  }
}

///|
/// Materializes a character map from the specified font. This proxy must have
/// been created from the same font.
pub fn CharmapProxy::materialize(
  self : CharmapProxy,
  font : FontRef,
) -> Charmap {
  Charmap::{ data: font.data(), proxy: self }
}

///|
/// Maps characters to nominal glyph identifiers.
pub struct Charmap {
  data : Bytes
  proxy : CharmapProxy
}

///|
pub fn Charmap::from_font(font : FontRef) -> Charmap {
  let proxy = CharmapProxy::from_font(font)
  Charmap::{ data: font.data(), proxy }
}

///|
pub fn Charmap::proxy(self : Charmap) -> CharmapProxy {
  self.proxy
}

///|
pub fn Charmap::map(self : Charmap, codepoint : UInt) -> GlyphId {
  let mut glyph_id = @internal.map(
    self.data,
    self.proxy.offset,
    self.proxy.format,
    codepoint,
  ).unwrap_or(0)
  // Remap U+0000..=U+00FF to U+F000..=U+F0FF for symbol encodings.
  if glyph_id == 0 && self.proxy.symbol && codepoint <= 0x00FF {
    glyph_id = @internal.map(
      self.data,
      self.proxy.offset,
      self.proxy.format,
      codepoint + 0xF000,
    ).unwrap_or(0)
  }
  glyph_id
}

///|
pub fn Charmap::enumerate(self : Charmap, f : (UInt, GlyphId) -> Unit) -> Unit {
  @internal.enumerate(self.data, self.proxy.offset, f)
}

///|
test "Charmap maps U+0041 to glyph id via FontRef" {
  // Same synthetic font as internal/cmap_test.
  let data = Bytes::makei(76, i => if i == 0 {
    b'\x00'
  } else if i == 1 {
    b'\x01'
  } else if i == 2 {
    b'\x00'
  } else if i == 3 {
    b'\x00'
  } else if i == 4 {
    b'\x00'
  } else if i == 5 {
    b'\x01'
  } else if i == 12 {
    b'c'
  } else if i == 13 {
    b'm'
  } else if i == 14 {
    b'a'
  } else if i == 15 {
    b'p'
  } else if i == 20 {
    b'\x00'
  } else if i == 21 {
    b'\x00'
  } else if i == 22 {
    b'\x00'
  } else if i == 23 {
    b'\x20'
  } else if i == 24 {
    b'\x00'
  } else if i == 25 {
    b'\x00'
  } else if i == 26 {
    b'\x00'
  } else if i == 27 {
    b'\x2C'
  } else if i == 32 {
    b'\x00'
  } else if i == 33 {
    b'\x00'
  } else if i == 34 {
    b'\x00'
  } else if i == 35 {
    b'\x01'
  } else if i == 36 {
    b'\x00'
  } else if i == 37 {
    b'\x03'
  } else if i == 38 {
    b'\x00'
  } else if i == 39 {
    b'\x01'
  } else if i == 40 {
    b'\x00'
  } else if i == 41 {
    b'\x00'
  } else if i == 42 {
    b'\x00'
  } else if i == 43 {
    b'\x0C'
  } else if i == 44 {
    b'\x00'
  } else if i == 45 {
    b'\x04'
  } else if i == 46 {
    b'\x00'
  } else if i == 47 {
    b'\x20'
  } else if i == 48 {
    b'\x00'
  } else if i == 49 {
    b'\x00'
  } else if i == 50 {
    b'\x00'
  } else if i == 51 {
    b'\x04'
  } else if i == 58 {
    b'\x00'
  } else if i == 59 {
    b'\x41'
  } else if i == 60 {
    b'\xFF'
  } else if i == 61 {
    b'\xFF'
  } else if i == 62 {
    b'\x00'
  } else if i == 63 {
    b'\x00'
  } else if i == 64 {
    b'\x00'
  } else if i == 65 {
    b'\x41'
  } else if i == 66 {
    b'\xFF'
  } else if i == 67 {
    b'\xFF'
  } else if i == 68 {
    b'\xFF'
  } else if i == 69 {
    b'\xC2'
  } else if i == 70 {
    b'\x00'
  } else if i == 71 {
    b'\x01'
  } else if i == 72 {
    b'\x00'
  } else if i == 73 {
    b'\x00'
  } else if i == 74 {
    b'\x00'
  } else if i == 75 {
    b'\x00'
  } else {
    b'\x00'
  })
  let font_opt = FontRef::from_offset(data, 0)
  if font_opt is Some(font) {
    let cm = Charmap::from_font(font)
    inspect(cm.map(0x41), content="3")
    inspect(cm.map(0x42), content="0")
  } else {
    fail("expected Some(FontRef)")
  }
}
