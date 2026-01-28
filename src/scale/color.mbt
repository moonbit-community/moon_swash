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
/// Color scalable outline helpers (COLR/CPAL).
///
/// Ported from `swash-reference/src/scale/color.rs`.

///|
struct ColorProxy {
  colr : UInt
  cpal : UInt
}

///|
pub fn ColorProxy::from_font(font : @swash.FontRef) -> ColorProxy {
  ColorProxy::{
    colr: @internal.table_offset(font, 0x434f4c52), // "COLR"
    cpal: @internal.table_offset(font, 0x4350414c), // "CPAL"
  }
}

///|
pub fn ColorProxy::layers(
  self : ColorProxy,
  data : Bytes,
  glyph_id : UInt16,
) -> ColrLayers? {
  if self.colr == 0 {
    return None
  }
  let colr_off = self.colr.reinterpret_as_int()
  let b_opt = @internal.BeBytes::with_offset(data, colr_off)
  if b_opt is None {
    return None
  }
  let b = b_opt.unwrap()
  // COLR v0 header:
  // u16 version, u16 numBaseGlyphRecords, u32 baseGlyphRecordsOffset,
  // u32 layerRecordsOffset, u16 numLayerRecords
  let count_u = b.read_u16(2).unwrap_or(0)
  let count = count_u.reinterpret_as_int()
  let base_off_u = b.read_u32(4).unwrap_or(0)
  let base_off = base_off_u.reinterpret_as_int()
  let mut l = 0
  let mut h = count
  while l < h {
    let i = l + (h - l) / 2
    let rec = base_off + i * 6
    match b.read_u16(rec) {
      None => return None
      Some(id_u) => {
        let id = id_u.to_uint16()
        if glyph_id < id {
          h = i
        } else if glyph_id > id {
          l = i + 1
        } else {
          let first = b.read_u16(rec + 2).unwrap_or(0).reinterpret_as_int()
          let layer_records_off = b
            .read_u32(8)
            .unwrap_or(0)
            .reinterpret_as_int()
          let offset = layer_records_off + first * 4
          let len = b.read_u16(rec + 4).unwrap_or(0).to_uint16()
          return Some(ColrLayers::{ data: b, offset, len })
        }
      }
    }
  }
  None
}

///|
struct ColrLayers {
  data : @internal.BeBytes
  offset : Int
  len : UInt16
}

///|
pub fn ColrLayers::len(self : ColrLayers) -> UInt16 {
  self.len
}

///|
pub fn ColrLayers::get(self : ColrLayers, index : UInt16) -> ColrLayer? {
  if index >= self.len {
    return None
  }
  let base = self.offset + index.to_int() * 4
  let glyph_id_u = match self.data.read_u16(base) {
    None => return None
    Some(u) => u
  }
  let color_u = match self.data.read_u16(base + 2) {
    None => return None
    Some(u) => u
  }
  let glyph_id = glyph_id_u.to_uint16()
  let color_index = if color_u == 0xFFFF {
    None
  } else {
    Some(color_u.to_uint16())
  }
  Some(ColrLayer::{ glyph_id, color_index })
}

///|
struct ColrLayer {
  glyph_id : UInt16
  color_index : UInt16?
}

///|
pub fn ColrLayer::glyph_id(self : ColrLayer) -> UInt16 {
  self.glyph_id
}

///|
pub fn ColrLayer::color_index(self : ColrLayer) -> UInt16? {
  self.color_index
}
