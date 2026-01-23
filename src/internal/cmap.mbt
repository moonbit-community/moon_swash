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
/// Character to glyph mapping table.
///
/// Ported from `swash/src/internal/cmap.rs` (swash is dual-licensed Apache-2.0 OR MIT).
const CMAP : RawTag = 0x636D6170 // "cmap"

///|
fn uint_to_int_checked(u : UInt) -> Int? {
  if u > 0x7FFFFFFF {
    None
  } else {
    Some(u.reinterpret_as_int())
  }
}

///|
/// Finds a suitable character map subtable for the specified font.
pub fn[T : RawFont] subtable(font : T) -> (UInt, UInt, Bool)? {
  let cmap_off = table_offset(font, CMAP)
  if cmap_off == 0 {
    return None
  }
  let cmap_off_i = match uint_to_int_checked(cmap_off) {
    None => return None
    Some(v) => v
  }
  let s = match Stream::with_offset(font.data(), cmap_off_i) {
    None => return None
    Some(v) => v
  }
  if !s.skip(2) {
    return None
  }
  let len_u = match s.read_u16() {
    None => return None
    Some(v) => v
  }
  let len = len_u.reinterpret_as_int()
  let b = BeBytes::from_view(s.data())
  let mut best : (UInt, UInt, Bool)? = None
  for _ in 0..<len {
    let platform = match s.read_u16() {
      None => return best
      Some(v) => v
    }
    let encoding = match s.read_u16() {
      None => return best
      Some(v) => v
    }
    let offset = match s.read_u32() {
      None => return best
      Some(v) => v
    }
    let offset_i = match uint_to_int_checked(offset) {
      None => continue
      Some(v) => v
    }
    let format_u = match b.read_u16(offset_i) {
      None => continue
      Some(v) => v
    }
    let format = format_u.reinterpret_as_int()
    if format != 4 && format != 12 {
      continue
    }
    let abs_off = cmap_off + offset
    if is_symbol(platform, encoding) {
      return Some((abs_off, format_u, true))
    } else if (format == 12 && is_unicode(platform, encoding)) ||
      (best is None && is_unicode(platform, encoding)) {
      best = Some((abs_off, format_u, false))
    }
  }
  best
}

///|
/// Maps a codepoint to a glyph identifier.
pub fn map(
  data : Bytes,
  subtable : UInt,
  format : UInt,
  codepoint : UInt,
) -> UInt? {
  if subtable == 0 {
    return None
  }
  let subtable_i = match uint_to_int_checked(subtable) {
    None => return None
    Some(v) => v
  }
  let b = match BeBytes::with_offset(data, subtable_i) {
    None => return None
    Some(v) => v
  }
  if format == 4 {
    if codepoint >= 65535 {
      return None
    }
    let c = codepoint
    let segcount_x2_u = match b.read_u16(6) {
      None => return None
      Some(v) => v
    }
    let segcount_x2 = segcount_x2_u.reinterpret_as_int()
    let segcount = segcount_x2 / 2
    if !b.ensure_range(0, 16 + segcount_x2 * 4) {
      return None
    }
    let end_codes_offset = 14
    let start_codes_offset = end_codes_offset + segcount_x2 + 2
    let mut l = 0
    let mut h = segcount
    while l < h {
      let i = (l + h) / 2
      let i2 = i * 2
      let start_u = match b.read_u16(start_codes_offset + i2) {
        None => return None
        Some(v) => v
      }
      if c < start_u {
        h = i
      } else {
        let end_u = match b.read_u16(end_codes_offset + i2) {
          None => return None
          Some(v) => v
        }
        if c > end_u {
          l = i + 1
        } else {
          let deltas_offset = start_codes_offset + segcount_x2
          let ranges_offset = deltas_offset + segcount_x2
          let mut range_base = ranges_offset + i2
          let range_u = match b.read_u16(range_base) {
            None => return None
            Some(v) => v
          }
          let delta = match b.read_i16(deltas_offset + i2) {
            None => return None
            Some(v) => v
          }
          let range = range_u.reinterpret_as_int()
          if range == 0 {
            let gid = (c.reinterpret_as_int() + delta) & 0xFFFF
            return Some(gid.reinterpret_as_uint())
          }
          range_base = range_base + range
          let diff = (c - start_u).reinterpret_as_int() * 2
          let id_u = b.read_u16(range_base + diff).unwrap_or(0)
          if id_u != 0 {
            let gid = (id_u.reinterpret_as_int() + delta) & 0xFFFF
            return Some(gid.reinterpret_as_uint())
          } else {
            return Some(0)
          }
        }
      }
    }
    None
  } else if format == 12 {
    let base = 16
    let len_u = b.read_u32(base - 4).unwrap_or(0)
    let len = match uint_to_int_checked(len_u) {
      None => return None
      Some(v) => v
    }
    if !b.ensure_range(base, len * 12) {
      return None
    }
    let mut l = 0
    let mut h = len
    while l < h {
      let i = (l + h) / 2
      let rec = base + i * 12
      let start = match b.read_u32(rec) {
        None => return None
        Some(v) => v
      }
      if codepoint < start {
        h = i
      } else {
        let end = match b.read_u32(rec + 4) {
          None => return None
          Some(v) => v
        }
        if codepoint > end {
          l = i + 1
        } else {
          let delta = match b.read_u32(rec + 8) {
            None => return None
            Some(v) => v
          }
          let gid = delta + (codepoint - start)
          return Some(gid & 0xFFFF)
        }
      }
    }
    None
  } else {
    None
  }
}

///|
/// Enumerates all codepoint/glyph pairs in the table.
pub fn enumerate(
  data : Bytes,
  subtable : UInt,
  f : (UInt, UInt) -> Unit,
) -> Unit {
  if subtable == 0 {
    return
  }
  let subtable_i = match uint_to_int_checked(subtable) {
    None => return
    Some(v) => v
  }
  let b = match BeBytes::with_offset(data, subtable_i) {
    None => return
    Some(v) => v
  }
  let format = b.read_u16(0).unwrap_or(0)
  if format == 4 {
    let segcount_x2_u = match b.read_u16(6) {
      None => return
      Some(v) => v
    }
    let segcount_x2 = segcount_x2_u.reinterpret_as_int()
    let segcount = segcount_x2 / 2
    if !b.check_range(0, 16 + segcount_x2 * 4) {
      return
    }
    let end_codes_offset = 14
    let start_codes_offset = end_codes_offset + segcount_x2 + 2
    let deltas_offset = start_codes_offset + segcount_x2
    let ranges_offset = deltas_offset + segcount_x2
    for i in 0..<segcount {
      let i2 = i * 2
      let start_u = b.read_u16(start_codes_offset + i2).unwrap_or(0)
      let end_u = b.read_u16(end_codes_offset + i2).unwrap_or(0)
      let delta = b.read_i16(deltas_offset + i2).unwrap_or(0)
      let mut range_base = ranges_offset + i2
      let range_u = b.read_u16(range_base).unwrap_or(0)
      if range_u == 0 {
        for cp in start_u..<=end_u {
          let id = (cp.reinterpret_as_int() + delta) & 0xFFFF
          if id != 0 {
            f(cp, id.reinterpret_as_uint())
          }
        }
      } else {
        range_base = range_base + range_u.reinterpret_as_int()
        for cp in start_u..<=end_u {
          let diff = (cp - start_u).reinterpret_as_int() * 2
          match b.read_u16(range_base + diff) {
            None => ()
            Some(id_u) =>
              if id_u != 0 {
                let id = ((id_u.reinterpret_as_int() + delta) & 0xFFFF).reinterpret_as_uint()
                f(cp, id)
              }
          }
        }
      }
    }
  } else if format == 12 {
    let base = 16
    let len_u = b.read_u32(base - 4).unwrap_or(0)
    let len = match uint_to_int_checked(len_u) {
      None => return
      Some(v) => v
    }
    if !b.check_range(base, len * 12) {
      return
    }
    for i in 0..<len {
      let rec = base + i * 12
      let start = b.read_u32(rec).unwrap_or(0)
      let end = b.read_u32(rec + 4).unwrap_or(0)
      let offset = b.read_u32(rec + 8).unwrap_or(0)
      let mut cp = start
      while cp <= end {
        let id = (offset + cp - start) & 0xFFFF
        if id != 0 {
          f(cp, id)
        }
        cp = cp + 1
      }
    }
  }
}

///|
fn is_unicode(platform : UInt, encoding : UInt) -> Bool {
  platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10))
}

///|
fn is_symbol(platform : UInt, encoding : UInt) -> Bool {
  platform == 3 && encoding == 0
}
