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
/// OpenType advanced typography table helpers (subset).
///
/// Ported from `swash/src/internal/at.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
pub const GSUB : RawTag = 0x47535542 // "GSUB"

///|
pub const GPOS : RawTag = 0x47504F53 // "GPOS"

///|
pub const DFLT : RawTag = 0x44464C54 // "DFLT"

///|
pub fn script_count(data : Bytes, gsubgpos_offset : UInt) -> UInt16 {
  if gsubgpos_offset == 0U {
    return (0).to_uint16()
  }
  let base = gsubgpos_offset.reinterpret_as_int()
  let b = BeBytes::new(data)
  let offset = b.read_u16(base + 4).unwrap_or(0).reinterpret_as_int()
  if offset == 0 {
    return (0).to_uint16()
  }
  b.read_u16(base + offset).unwrap_or(0).to_uint16()
}

///|
pub fn script_at(
  data : Bytes,
  gsubgpos_offset : UInt,
  index : UInt16,
) -> (RawTag, UInt)? {
  if gsubgpos_offset == 0U {
    return None
  }
  let base = gsubgpos_offset.reinterpret_as_int()
  let b = BeBytes::new(data)
  let sbase = match b.read_u16(base + 4) {
    None => return None
    Some(off) => base + off.reinterpret_as_int()
  }
  let rec = sbase + 2 + index.to_int() * 6
  let tag = match b.read_u32(rec) {
    None => return None
    Some(v) => v
  }
  let off = match b.read_u16(rec + 4) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  Some((tag, (sbase + off).reinterpret_as_uint()))
}

///|
pub fn script_by_tag(
  data : Bytes,
  gsubgpos_offset : UInt,
  script : RawTag,
) -> UInt? {
  if gsubgpos_offset == 0U {
    return None
  }
  let base = gsubgpos_offset.reinterpret_as_int()
  let b = BeBytes::new(data)
  let sbase = match b.read_u16(base + 4) {
    None => return None
    Some(off) => base + off.reinterpret_as_int()
  }
  let mut l = 0
  let mut h = match b.read_u16(sbase) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  while l < h {
    let i = l + (h - l) / 2
    let rec = sbase + 2 + i * 6
    let t = match b.read_u32(rec) {
      None => return None
      Some(v) => v
    }
    if script < t {
      h = i
    } else if script > t {
      l = i + 1
    } else {
      let off = match b.read_u16(rec + 4) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      return Some((sbase + off).reinterpret_as_uint())
    }
  }
  None
}

///|
pub fn script_language_count(data : Bytes, script_offset : UInt) -> UInt16 {
  if script_offset == 0U {
    return (0).to_uint16()
  }
  let base = script_offset.reinterpret_as_int()
  let b = BeBytes::new(data)
  match b.read_u16(base + 2) {
    None => (0).to_uint16()
    Some(n) => (n + 1).to_uint16()
  }
}

///|
pub fn script_default_language(data : Bytes, script_offset : UInt) -> UInt? {
  if script_offset == 0U {
    return None
  }
  let base = script_offset.reinterpret_as_int()
  let b = BeBytes::new(data)
  let off = match b.read_u16(base) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if off == 0 {
    None
  } else {
    Some((base + off).reinterpret_as_uint())
  }
}

///|
pub fn script_language_at(
  data : Bytes,
  script_offset : UInt,
  index : UInt16,
) -> (RawTag, UInt)? {
  if script_offset == 0U {
    return None
  }
  if index == 0 {
    let off = match script_default_language(data, script_offset) {
      None => return None
      Some(v) => v
    }
    return Some((DFLT, off))
  }
  let index = (index.to_int() - 1).to_uint16()
  let base = script_offset.reinterpret_as_int()
  let b = BeBytes::new(data)
  let rec = base + 4 + index.to_int() * 6
  let tag = match b.read_u32(rec) {
    None => return None
    Some(v) => v
  }
  let off = match b.read_u16(rec + 4) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if off == 0 {
    return None
  }
  Some((tag, (base + off).reinterpret_as_uint()))
}

///|
pub fn script_language_by_tag(
  data : Bytes,
  script_offset : UInt,
  language : RawTag?,
) -> (UInt, Bool)? {
  if script_offset == 0U {
    return None
  }
  let base = script_offset.reinterpret_as_int()
  let b = BeBytes::new(data)
  if language is Some(lang) {
    let mut l = 0
    let mut h = match b.read_u16(base + 2) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    while l < h {
      let i = (l + h) / 2
      let rec = base + 4 + i * 6
      let t = match b.read_u32(rec) {
        None => return None
        Some(v) => v
      }
      if lang < t {
        h = i
      } else if lang > t {
        l = i + 1
      } else {
        let lang_off = match b.read_u16(rec + 4) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        if lang_off == 0 {
          return None
        }
        return Some(((base + lang_off).reinterpret_as_uint(), false))
      }
    }
  }
  let def_off = match b.read_u16(base) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if def_off == 0 {
    None
  } else {
    Some(((base + def_off).reinterpret_as_uint(), true))
  }
}

///|
pub fn language_feature_count(data : Bytes, language_offset : UInt) -> UInt16 {
  if language_offset == 0U {
    return (0).to_uint16()
  }
  let base = language_offset.reinterpret_as_int()
  BeBytes::new(data).read_u16(base + 4).unwrap_or(0).to_uint16()
}

///|
pub fn language_feature_at(
  data : Bytes,
  language_offset : UInt,
  index : UInt16,
) -> UInt16? {
  let base = language_offset.reinterpret_as_int()
  match BeBytes::new(data).read_u16(base + 6 + index.to_int() * 2) {
    None => None
    Some(v) => Some(v.to_uint16())
  }
}

///|
pub fn feature_count(data : Bytes, gsubgpos_offset : UInt) -> UInt16 {
  if gsubgpos_offset == 0U {
    return (0).to_uint16()
  }
  let base = gsubgpos_offset.reinterpret_as_int()
  let b = BeBytes::new(data)
  let foff = b.read_u16(base + 6).unwrap_or(0).reinterpret_as_int()
  if foff == 0 {
    return (0).to_uint16()
  }
  b.read_u16(base + foff).unwrap_or(0).to_uint16()
}

///|
pub fn feature_at(
  data : Bytes,
  gsubgpos_offset : UInt,
  index : UInt16,
) -> (RawTag, UInt)? {
  if gsubgpos_offset == 0U {
    return None
  }
  let base = gsubgpos_offset.reinterpret_as_int()
  let b = BeBytes::new(data)
  let foff = match b.read_u16(base + 6) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if foff == 0 {
    return None
  }
  let fbase = base + foff
  let rec = fbase + 2 + index.to_int() * 6
  let tag = match b.read_u32(rec) {
    None => return None
    Some(v) => v
  }
  let off = match b.read_u16(rec + 4) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if off == 0 {
    return None
  }
  Some((tag, (fbase + off).reinterpret_as_uint()))
}
