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
/// Glyph Definition (GDEF) table wrapper.
///
/// Ported from `swash-reference/src/internal/at.rs` (`Gdef`).
pub struct Gdef {
  data : Bytes
  base : Int
  classes : UInt16
  mark_classes : UInt16
  mark_sets : UInt16
  var_store : UInt
}

///|
pub fn Gdef::new(data : Bytes, base : Int) -> Gdef? {
  let b = BeBytes::new(data)
  let major = b.read_u16(base).unwrap_or(0).to_uint16()
  let minor = b.read_u16(base + 2).unwrap_or(0).to_uint16()
  let classes = match b.read_u16(base + 4) {
    None => return None
    Some(v) => v.to_uint16()
  }
  let mark_classes = match b.read_u16(base + 10) {
    None => return None
    Some(v) => v.to_uint16()
  }
  let mark_sets = if major > 1 || minor >= 2 {
    b.read_u16(base + 12).unwrap_or(0).to_uint16()
  } else {
    (0).to_uint16()
  }
  let var_store = if major > 1 || minor >= 3 {
    b.read_u32(base + 14).unwrap_or(0U)
  } else {
    0U
  }
  Some(Gdef::{ data, base, classes, mark_classes, mark_sets, var_store })
}

///|
pub fn Gdef::from_offset(data : Bytes, offset : UInt) -> Gdef? {
  if offset == 0U {
    return None
  }
  let start = offset.reinterpret_as_int()
  guard start >= 0 && start <= data.length() else { None }
  Gdef::new(data, start)
}

///|
pub fn Gdef::empty() -> Gdef {
  Gdef::{
    data: Bytes::from_array([]),
    base: 0,
    classes: 0,
    mark_classes: 0,
    mark_sets: 0,
    var_store: 0U,
  }
}

///|
pub fn Gdef::ok(self : Gdef) -> Bool {
  self.data.length() != 0
}

///|
/// Returns true if glyph classes are available.
pub fn Gdef::has_classes(self : Gdef) -> Bool {
  self.classes != 0
}

///|
/// Returns the class for the specified glyph id.
pub fn Gdef::class(self : Gdef, glyph_id : UInt16) -> UInt16 {
  if self.classes == 0 {
    return (0).to_uint16()
  }
  classdef(
    self.data,
    (self.base + self.classes.to_int()).reinterpret_as_uint(),
    glyph_id,
  )
}

///|
/// Returns true if mark glyph classes are available.
pub fn Gdef::has_mark_classes(self : Gdef) -> Bool {
  self.mark_classes != 0
}

///|
/// Returns the mark class for the specified glyph id.
pub fn Gdef::mark_class(self : Gdef, glyph_id : UInt16) -> UInt16 {
  if self.mark_classes == 0 {
    return (0).to_uint16()
  }
  classdef(
    self.data,
    (self.base + self.mark_classes.to_int()).reinterpret_as_uint(),
    glyph_id,
  )
}

///|
pub fn Gdef::mark_set_coverage(
  self : Gdef,
  set_offset : UInt,
  glyph_id : UInt16,
) -> UInt16? {
  coverage(self.data, set_offset, glyph_id)
}

///|
pub fn Gdef::mark_set_offset(self : Gdef, set_index : UInt16) -> UInt? {
  if self.mark_sets == 0 {
    return None
  }
  let set = set_index.to_int()
  let b = BeBytes::new(self.data)
  let sets_base = self.base + self.mark_sets.to_int()
  let len = match b.read_u16(sets_base + 2) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if set < 0 || set >= len {
    return None
  }
  let offset = match b.read_u32(sets_base + 4 + set * 4) {
    None => return None
    Some(v) => v
  }
  if offset == 0U {
    return None
  }
  let set_offset = sets_base.reinterpret_as_uint() + offset
  if validate_coverage(self.data, set_offset) {
    Some(set_offset)
  } else {
    None
  }
}

///|
pub fn Gdef::has_var_store(self : Gdef) -> Bool {
  self.var_store != 0U
}

///|
pub fn Gdef::delta(
  self : Gdef,
  outer : UInt16,
  inner : UInt16,
  coords : ArrayView[Int],
) -> Double {
  if self.var_store == 0U {
    return 0.0
  }
  let store = self.base.reinterpret_as_uint() + self.var_store
  match
    item_delta(
      self.data,
      store,
      outer.to_int().reinterpret_as_uint(),
      inner.to_int().reinterpret_as_uint(),
      coords,
    ) {
    None => 0.0
    Some(d) => d.to_f32()
  }
}

///|
pub fn validate_coverage(b : Bytes, coverage_offset : UInt) -> Bool {
  if coverage_offset == 0U {
    return false
  }
  let base = coverage_offset.reinterpret_as_int()
  let arr = base + 4
  let bb = BeBytes::new(b)
  match (bb.read_u16(base), bb.read_u16(base + 2)) {
    (Some(_), Some(len_u)) if len_u == 0 => false
    (Some(fmt_u), Some(len_u)) => {
      let fmt = fmt_u.reinterpret_as_int()
      let len = len_u.reinterpret_as_int()
      if fmt == 1 {
        bb.check_range(arr, len * 2)
      } else if fmt == 2 {
        bb.check_range(arr, len * 6)
      } else {
        false
      }
    }
    _ => false
  }
}

///|
pub fn coverage(
  b : Bytes,
  coverage_offset : UInt,
  glyph_id : UInt16,
) -> UInt16? {
  if coverage_offset == 0U {
    return None
  }
  let base = coverage_offset.reinterpret_as_int()
  let bb = BeBytes::new(b)
  let fmt = match bb.read_u16(base) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let len = match bb.read_u16(base + 2) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let arr = base + 4
  let gid = glyph_id.to_int()
  if fmt == 1 {
    if !bb.check_range(arr, len * 2) {
      return None
    }
    let mut l = 0
    let mut h = len
    while l < h {
      let i = (l + h) / 2
      let g = match bb.read_u16(arr + i * 2) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      if gid < g {
        h = i
      } else if gid > g {
        l = i + 1
      } else {
        return Some(i.to_uint16())
      }
    }
    None
  } else if fmt == 2 {
    if !bb.check_range(arr, len * 6) {
      return None
    }
    let mut l = 0
    let mut h = len
    while l < h {
      let i = (l + h) / 2
      let rec = arr + i * 6
      let start = match bb.read_u16(rec) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      if gid < start {
        h = i
      } else {
        let last = match bb.read_u16(rec + 2) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        if gid > last {
          l = i + 1
        } else {
          let base_ix = match bb.read_u16(rec + 4) {
            None => return None
            Some(v) => v.reinterpret_as_int()
          }
          return Some((base_ix + gid - start).to_uint16())
        }
      }
    }
    None
  } else {
    None
  }
}

///|
pub fn classdef(b : Bytes, classdef_offset : UInt, glyph_id : UInt16) -> UInt16 {
  if classdef_offset == 0U {
    return (0).to_uint16()
  }
  let base = classdef_offset.reinterpret_as_int()
  let bb = BeBytes::new(b)
  let fmt = bb.read_u16(base).unwrap_or(0).reinterpret_as_int()
  let gid : UInt16 = glyph_id
  if fmt == 1 {
    let start = bb.read_u16(base + 2).unwrap_or(0).to_uint16()
    let len = bb.read_u16(base + 4).unwrap_or(0).to_uint16()
    if len == 0 {
      return (0).to_uint16()
    }
    let end = start + len - 1
    let arr = base + 6
    if gid >= start && gid <= end {
      bb.read_u16(arr + (gid - start).to_int() * 2).unwrap_or(0).to_uint16()
    } else {
      (0).to_uint16()
    }
  } else if fmt == 2 {
    let len = bb.read_u16(base + 2).unwrap_or(0).reinterpret_as_int()
    let arr = base + 4
    if !bb.check_range(arr, len * 6) {
      return (0).to_uint16()
    }
    let mut l = 0
    let mut h = len
    while l < h {
      let i = (l + h) / 2
      let rec = arr + i * 6
      let start = bb.read_u16(rec).unwrap_or(0).reinterpret_as_int()
      if gid.to_int() < start {
        h = i
      } else if gid.to_int() >
        bb.read_u16(rec + 2).unwrap_or(0).reinterpret_as_int() {
        l = i + 1
      } else {
        return bb.read_u16(rec + 4).unwrap_or(0).to_uint16()
      }
    }
    (0).to_uint16()
  } else {
    (0).to_uint16()
  }
}
