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
/// Low level OpenType parsing helpers for table directory access.
///
/// Ported from `swash/src/internal/mod.rs` (trait `RawFont` + table accessors).
///
/// swash is dual-licensed Apache-2.0 OR MIT.

///|
/// Trait for types that can supply font tables.
///
/// Note: this is declared as `pub(open)` so other packages in this module
/// (e.g. `swash/font.mbt`) can implement it, matching upstream swash.
pub(open) trait RawFont {
  data(Self) -> Bytes
  offset(Self) -> Int
}

///|
pub fn[T : RawFont] table_range(font : T, tag : RawTag) -> (UInt, UInt)? {
  let base = font.offset()
  let data = font.data()
  let b = BeBytes::new(data)

  // numTables is at offset + 4
  let len = match b.read_u16(base + 4) {
    None => return None
    Some(len_u) => len_u.reinterpret_as_int()
  }
  let record_base = base + 12
  let reclen = 16
  let mut l = 0
  let mut h = len
  while l < h {
    let i = (l + h) / 2
    let recbase = record_base + reclen * i
    let s = match Stream::with_offset(data, recbase) {
      None => return None
      Some(s) => s
    }
    let table_tag = match s.read_u32() {
      None => return None
      Some(t) => t
    }
    if tag < table_tag {
      h = i
    } else if tag > table_tag {
      l = i + 1
    } else {
      // skip checksum
      if !s.skip(4) {
        return None
      }
      let start = match s.read_u32() {
        None => return None
        Some(v) => v
      }
      let len = match s.read_u32() {
        None => return None
        Some(v) => v
      }
      let end = start + len
      if end < start {
        return None
      }
      return Some((start, end))
    }
  }
  None
}

///|
pub fn[T : RawFont] table_offset(font : T, tag : RawTag) -> UInt {
  match table_range(font, tag) {
    None => 0
    Some((start, _)) => start
  }
}

///|
pub fn[T : RawFont] table_data(font : T, tag : RawTag) -> BytesView? {
  let data = font.data()
  let (start_u, end_u) = match table_range(font, tag) {
    None => return None
    Some(r) => r
  }
  let start = start_u.reinterpret_as_int()
  let end = end_u.reinterpret_as_int()
  guard start >= 0 && end >= start && end <= data.length() else { None }
  Some(data[start:end])
}
