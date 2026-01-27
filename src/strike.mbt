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
/// Alpha and color bitmaps.
///
/// Ported from `swash/src/strike.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
const EBLC : UInt = 0x45424C43 // "EBLC"

///|
const EBDT : UInt = 0x45424454 // "EBDT"

///|
const SBIX : UInt = 0x73626978 // "sbix"

///|
const CBLC : UInt = 0x43424C43 // "CBLC"

///|
const CBDT : UInt = 0x43424454 // "CBDT"

///|
const DUPE : UInt = 0x64757065 // "dupe"

///|
const PNG : UInt = 0x706E6720 // "png "

///|
fn strike_empty_bytes_view() -> BytesView {
  Bytes::from_array([])[:]
}

///|
fn slice_from(data : Bytes, start : UInt) -> BytesView {
  let s = start.reinterpret_as_int()
  if s < 0 || s > data.length() {
    strike_empty_bytes_view()
  } else {
    data[s:]
  }
}

///|
/// Proxy for rematerializing strike collections.
pub struct BitmapStrikesProxy {
  bitmaps : (UInt, UInt)
  color_bitmaps : (UInt, UInt)
  upem : UInt
  is_apple : Bool
}

///|
pub fn BitmapStrikesProxy::from_font(font : FontRef) -> BitmapStrikesProxy {
  let upem = match font.head() {
    None => 1U
    Some(h) => {
      let u = h.units_per_em()
      if u == 0 {
        1U
      } else {
        u
      }
    }
  }
  let mut bitmaps = (0U, 0U)
  let eblc = font.table_offset(EBLC)
  if eblc != 0U {
    let ebdt = font.table_offset(EBDT)
    if ebdt != 0U {
      bitmaps = (eblc, ebdt)
    }
  }
  let mut color_bitmaps = (0U, 0U)
  let mut is_apple = false
  let sbix = font.table_offset(SBIX)
  if sbix != 0U {
    color_bitmaps = (sbix, sbix)
    match font.localized_strings().find_by_id(StringId::Family, None) {
      None => ()
      Some(name) => is_apple = name.to_string() == "Apple Color Emoji"
    }
  } else {
    let cblc = font.table_offset(CBLC)
    if cblc != 0U {
      let cbdt = font.table_offset(CBDT)
      if cbdt != 0U {
        color_bitmaps = (cblc, cbdt)
      }
    }
  }
  BitmapStrikesProxy::{ bitmaps, color_bitmaps, upem, is_apple }
}

///|
/// Returns true if the font has alpha bitmap strikes.
pub fn BitmapStrikesProxy::has_alpha(self : BitmapStrikesProxy) -> Bool {
  let (loc, _) = self.bitmaps
  loc != 0U
}

///|
/// Returns true if the font has color bitmap strikes.
pub fn BitmapStrikesProxy::has_color(self : BitmapStrikesProxy) -> Bool {
  let (loc, _) = self.color_bitmaps
  loc != 0U
}

///| Materializes an alpha strike collection for the specified font. This proxy

///|
/// must have been created from the same font.
pub fn BitmapStrikesProxy::materialize_alpha(
  self : BitmapStrikesProxy,
  font : FontRef,
) -> BitmapStrikes {
  let (loc, dat) = self.bitmaps
  materialize_impl(font.data(), loc, dat, self.upem, false, false)
}

///| Materializes a color strike collection for the specified font. This proxy

///|
/// must have been created from the same font.
pub fn BitmapStrikesProxy::materialize_color(
  self : BitmapStrikesProxy,
  font : FontRef,
) -> BitmapStrikes {
  let (loc, dat) = self.color_bitmaps
  materialize_impl(font.data(), loc, dat, self.upem, true, self.is_apple)
}

///|
fn materialize_impl(
  data : Bytes,
  loc : UInt,
  dat : UInt,
  upem : UInt,
  is_sbix : Bool,
  is_apple : Bool,
) -> BitmapStrikes {
  if loc == 0U {
    BitmapStrikes::new(
      strike_empty_bytes_view(),
      strike_empty_bytes_view(),
      upem,
      false,
      false,
    )
  } else if loc == dat {
    let slice = slice_from(data, loc)
    BitmapStrikes::new(slice, slice, upem, is_sbix, is_apple)
  } else {
    BitmapStrikes::new(
      slice_from(data, loc),
      slice_from(data, dat),
      upem,
      false,
      false,
    )
  }
}

///|
/// Collection of bitmap strikes.
pub struct BitmapStrikes {
  b : @internal.BeBytes
  bitmap_data : BytesView
  is_sbix : Bool
  is_apple : Bool
  upem : UInt
  len : Int
}

///|
fn BitmapStrikes::new(
  data : BytesView,
  bitmap_data : BytesView,
  upem : UInt,
  is_sbix : Bool,
  is_apple : Bool,
) -> BitmapStrikes {
  let b = @internal.BeBytes::from_view(data)
  let len = b.read_u32(4).unwrap_or(0).reinterpret_as_int()
  BitmapStrikes::{ b, bitmap_data, is_sbix, is_apple, upem, len }
}

///|
/// Returns the number of strikes in the collection.
pub fn BitmapStrikes::len(self : BitmapStrikes) -> Int {
  self.len
}

///|
/// Returns an iterator over the strikes.
pub fn BitmapStrikes::iter(self : BitmapStrikes) -> Iter[BitmapStrike] {
  let strikes = self
  let mut pos = 0
  Iter::new(fn() {
    if pos >= strikes.len {
      return None
    }
    let i = pos
    pos = pos + 1
    strikes.get(i)
  })
}

///|
fn BitmapStrikes::get(self : BitmapStrikes, index : Int) -> BitmapStrike? {
  if index < 0 || index >= self.len {
    return None
  }
  let offset = if self.is_sbix {
    match self.b.read_u32(8 + index * 4) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
  } else {
    8 + index * 48
  }
  Some(BitmapStrike::{
    b: self.b,
    bitmap_data: self.bitmap_data,
    upem: self.upem,
    is_sbix: self.is_sbix,
    is_apple: self.is_apple,
    offset,
  })
}

///| Searches for a strike that matches the specified size and glyph identifier.

///| Returns the strike of the nearest suitable size, preferring larger strikes

///| if no exact match is available.

///|

///| This function searches the entire strike collection without regard for the

///|
/// current state of the iterator.
pub fn BitmapStrikes::find_by_nearest_ppem(
  self : BitmapStrikes,
  ppem : UInt16,
  glyph_id : GlyphId,
) -> BitmapStrike? {
  let mut best : BitmapStrike? = None
  let mut best_size : UInt16 = (0).to_uint16()
  for i in 0..<self.len {
    let strike = match self.get(i) {
      None => continue
      Some(s) => s
    }
    if !strike.contains(glyph_id) {
      continue
    }
    best = Some(strike)
    let strike_ppem = strike.ppem()
    if strike_ppem > best_size {
      best = Some(strike)
      best_size = strike_ppem
    }
    if strike_ppem >= ppem {
      return Some(strike)
    }
  }
  best
}

///| Searches for a strike that exactly matches the specified size and glyph

///| identifier.

///|

///| This function searches the entire strike collection without regard for the

///|
/// current state of the iterator.
pub fn BitmapStrikes::find_by_exact_ppem(
  self : BitmapStrikes,
  ppem : UInt16,
  glyph_id : GlyphId,
) -> BitmapStrike? {
  for i in 0..<self.len {
    let strike = match self.get(i) {
      None => continue
      Some(s) => s
    }
    if !strike.contains(glyph_id) {
      continue
    }
    if strike.ppem() == ppem {
      return Some(strike)
    }
  }
  None
}

///| Searches for a strike with the largest size that contains the specified glyph.

///|

///| This function searches the entire strike collection without regard for the

///|
/// current state of the iterator.
pub fn BitmapStrikes::find_by_largest_ppem(
  self : BitmapStrikes,
  glyph_id : GlyphId,
) -> BitmapStrike? {
  let mut largest : BitmapStrike? = None
  let mut largest_ppem : UInt16 = (0).to_uint16()
  for i in 0..<self.len {
    let strike = match self.get(i) {
      None => continue
      Some(s) => s
    }
    if !strike.contains(glyph_id) {
      continue
    }
    let strike_ppem = strike.ppem()
    if largest is None || strike_ppem > largest_ppem {
      largest = Some(strike)
      largest_ppem = strike_ppem
    }
  }
  largest
}

///|
/// Collection of bitmaps of a specific size and format.
pub struct BitmapStrike {
  b : @internal.BeBytes
  bitmap_data : BytesView
  offset : Int
  upem : UInt
  is_sbix : Bool
  is_apple : Bool
}

///|
/// Returns the device pixel density for which the strike was designed.
pub fn BitmapStrike::ppi(self : BitmapStrike) -> UInt16 {
  if self.is_sbix {
    self.b.read_u16(self.offset + 2).unwrap_or(0).to_uint16()
  } else {
    (72).to_uint16()
  }
}

///|
/// Returns the bit depth of the strike.
pub fn BitmapStrike::bit_depth(self : BitmapStrike) -> Byte {
  if self.is_sbix {
    (32).to_byte()
  } else {
    self.b.read_u8(self.offset + 46).unwrap_or((0).to_byte())
  }
}

///|
/// Returns the size of the strike in pixels per em.
pub fn BitmapStrike::ppem(self : BitmapStrike) -> UInt16 {
  if self.is_sbix {
    self.b.read_u16(self.offset).unwrap_or(0).to_uint16()
  } else {
    self.b.read_u8(self.offset + 45).unwrap_or((0).to_byte()).to_uint16()
  }
}

///|
/// Returns true if the specified glyph is covered by the strike.
pub fn BitmapStrike::contains(self : BitmapStrike, glyph_id : GlyphId) -> Bool {
  get_coverage(self.b.data(), self.offset, self.is_sbix, glyph_id).unwrap_or(
    false,
  )
}

///|
fn get_coverage(
  table : BytesView,
  strike_base : Int,
  is_sbix : Bool,
  glyph_id : GlyphId,
) -> Bool? {
  if is_sbix {
    return Some(
      match sbix_range(table, strike_base, glyph_id, 0) {
        None => false
        Some(_) => true
      },
    )
  }
  let d = @internal.BeBytes::from_view(table)
  let gid = glyph_id.to_int().reinterpret_as_uint()
  let first_gid = match d.read_u16(strike_base + 40) {
    None => return None
    Some(v) => v
  }
  let last_gid = match d.read_u16(strike_base + 42) {
    None => return None
    Some(v) => v
  }
  if gid < first_gid || gid > last_gid {
    return None
  }
  let count = match d.read_u32(strike_base + 8) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let array_offset = match d.read_u32(strike_base) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  for i in 0..<count {
    let offset = array_offset + i * 8
    let first = match d.read_u16(offset) {
      None => return None
      Some(v) => v
    }
    if gid < first {
      return None
    }
    let last = match d.read_u16(offset + 2) {
      None => return None
      Some(v) => v
    }
    if gid > last {
      continue
    }
    return Some(true)
  }
  None
}

///|
fn sbix_range(
  table : BytesView,
  strike_base : Int,
  glyph_id : GlyphId,
  recurse : Int,
) -> (UInt, UInt)? {
  if recurse > 1 || strike_base < 0 {
    return None
  }
  let b = @internal.BeBytes::from_view(table)
  let id = glyph_id.to_int()
  let base = strike_base + 4
  let mut start = match b.read_u32(base + id * 4) {
    None => return None
    Some(v) => v
  }
  let mut end = match b.read_u32(base + (id + 1) * 4) {
    None => return None
    Some(v) => v
  }
  if end <= start {
    return None
  }
  let strike_u = strike_base.reinterpret_as_uint()
  start = start + strike_u
  end = end + strike_u
  let start_i = start.reinterpret_as_int()
  let tag = match b.read_u32(start_i + 4) {
    None => return None
    Some(v) => v
  }
  if tag == DUPE {
    let dupe = match b.read_u16(start_i + 8) {
      None => return None
      Some(v) => v.to_uint16()
    }
    sbix_range(table, strike_base, dupe, recurse + 1)
  } else if tag == PNG {
    Some((start, end))
  } else {
    None
  }
}

///|
/// Returns an iterator over the alpha bitmap strikes for the font.
pub fn FontRef::alpha_strikes(self : FontRef) -> BitmapStrikes {
  BitmapStrikesProxy::from_font(self).materialize_alpha(self)
}

///|
/// Returns an iterator over the color bitmap strikes for the font.
pub fn FontRef::color_strikes(self : FontRef) -> BitmapStrikes {
  BitmapStrikesProxy::from_font(self).materialize_color(self)
}
