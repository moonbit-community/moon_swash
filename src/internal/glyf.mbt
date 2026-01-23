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
/// Glyph data table.
///
/// Ported from `swash/src/internal/glyf.rs` (swash is dual-licensed Apache-2.0 OR MIT).
pub const GLYF : RawTag = 0x676C7966 // "glyf"

///|
pub const LOCA : RawTag = 0x6C6F6361 // "loca"

///|
pub const CVT_ : RawTag = 0x63767420 // "cvt "

///|
pub const FPGM : RawTag = 0x6670676D // "fpgm"

///|
pub const PREP : RawTag = 0x70726570 // "prep"

///|
pub const CVAR : RawTag = 0x63766172 // "cvar"

///|
pub const GVAR : RawTag = 0x67766172 // "gvar"

///|
fn u32_to_int_checked(u : UInt) -> Int? {
  if u > 0x7FFFFFFF {
    None
  } else {
    Some(u.reinterpret_as_int())
  }
}

///|
/// Returns the data for the specified glyph.
pub fn get(
  data : Bytes,
  loca_fmt : UInt,
  loca : UInt,
  glyf : UInt,
  glyph_id : UInt,
) -> BytesView? {
  let loca_i = match u32_to_int_checked(loca) {
    None => return None
    Some(v) => v
  }
  let glyf_i = match u32_to_int_checked(glyf) {
    None => return None
    Some(v) => v
  }
  let b = match BeBytes::with_offset(data, loca_i) {
    None => return None
    Some(v) => v
  }
  let (start, end) : (Int, Int) = if loca_fmt == 0 {
    let offset = glyph_id.reinterpret_as_int() * 2
    let start_u = match b.read_u16(offset) {
      None => return None
      Some(v) => v
    }
    let end_u = match b.read_u16(offset + 2) {
      None => return None
      Some(v) => v
    }
    (start_u.reinterpret_as_int() * 2, end_u.reinterpret_as_int() * 2)
  } else if loca_fmt == 1 {
    let offset = glyph_id.reinterpret_as_int() * 4
    let start_u = match b.read_u32(offset) {
      None => return None
      Some(v) => v
    }
    let end_u = match b.read_u32(offset + 4) {
      None => return None
      Some(v) => v
    }
    (start_u.reinterpret_as_int(), end_u.reinterpret_as_int())
  } else {
    return None
  }
  if end < start {
    return None
  }
  let glyf_bytes = match BeBytes::with_offset(data, glyf_i) {
    None => return None
    Some(v) => v
  }
  let view = glyf_bytes.data()
  guard start >= 0 && end >= start && end <= view.length() else { None }
  Some(view[start:end])
}

///|
/// Returns the y-max value of the specified glyph from the bounding box in the
/// `glyf` table.
pub fn ymax(
  data : Bytes,
  loca_fmt : UInt,
  loca : UInt,
  glyf : UInt,
  glyph_id : UInt,
) -> Int? {
  let glyph_data = match get(data, loca_fmt, loca, glyf, glyph_id) {
    None => return None
    Some(v) => v
  }
  let s = Stream::from_view(glyph_data)
  if !s.skip(8) {
    return None
  }
  s.read_i16()
}

///|
test "glyf.get + ymax for loca fmt 0" {
  // data[0..4): loca table with two u16 offsets (0, 5) -> [0, 10) bytes.
  // data[20..30): glyf data for glyph 0 with ymax=16 at offset 8.
  let data = Bytes::makei(40, i => if i == 0 {
    b'\x00'
  } else if i == 1 {
    b'\x00'
  } else if i == 2 {
    b'\x00'
  } else if i == 3 {
    b'\x05'
  } else if i == 28 {
    b'\x00'
  } else if i == 29 {
    b'\x10'
  } else {
    b'\x00'
  })
  let view_opt = get(data, 0, 0, 20, 0)
  if view_opt is Some(view) {
    inspect(view.length(), content="10")
  } else {
    fail("expected Some(view)")
  }
  inspect(ymax(data, 0, 0, 20, 0), content="Some(16)")
}
