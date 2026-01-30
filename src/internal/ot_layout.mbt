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
/// OpenType advanced typography data structures (GSUB/GPOS lookup metadata).
///
/// Ported from `upstream swash/src/internal/at.rs` (lookup + subtable metadata).

///|
/// Feature lookup kind.
pub(all) enum LookupKind {
  SingleSub
  MultiSub
  AltSub
  LigSub
  SingleAdj
  PairAdj
  Cursive
  MarkToBase
  MarkToLig
  MarkToMark
  Context
  ChainContext
  RevChainContext
}

///|
/// Data associated with a feature lookup.
pub struct LookupData {
  index : UInt16
  stage : Byte
  kind : LookupKind
  mut feature : UInt16
  mask : Byte
  ignored : Byte
  is_ext : Bool
  offset : UInt
  mut coverage : UInt
  count : UInt16
  mut subtables : (UInt16, UInt16)
  mark_set : UInt
  mark_check : Byte
  mark_class : Byte
}

///|
pub fn LookupData::set_feature(self : LookupData, feature : UInt16) -> Unit {
  self.feature = feature
}

///|
pub fn LookupData::set_coverage(self : LookupData, coverage : UInt) -> Unit {
  self.coverage = coverage
}

///|
pub fn LookupData::set_subtables(
  self : LookupData,
  start : UInt16,
  end : UInt16,
) -> Unit {
  self.subtables = (start, end)
}

///|
pub fn LookupData::subtable_data(
  self : LookupData,
  data : Bytes,
  index : UInt16,
) -> SubtableData? {
  let b = BeBytes::new(data)
  let base = self.offset.reinterpret_as_int()
  let subtable_base = base + 6
  let mut offset = match b.read_u16(subtable_base + index.to_int() * 2) {
    None => return None
    Some(v) => base + v.reinterpret_as_int()
  }
  if self.is_ext {
    offset = match b.read_u32(offset + 4) {
      None => return None
      Some(v) => offset + v.reinterpret_as_int()
    }
  }
  let fmt = match b.read_u16(offset) {
    None => return None
    Some(v) => v.to_uint16()
  }
  subtable_data(data, offset.reinterpret_as_uint(), self.kind, fmt)
}

///|
/// Lookup subtable kind, flattened to include the associated format.
pub(all) enum SubtableKind {
  SingleSub1
  SingleSub2
  MultiSub1
  AltSub1
  LigSub1
  SingleAdj1
  SingleAdj2
  PairAdj1
  PairAdj2
  Cursive1
  MarkToBase1
  MarkToLig1
  MarkToMark1
  Context1
  Context2
  Context3
  ChainContext1
  ChainContext2
  ChainContext3
  RevChainContext1
}

///|
/// Data associated with a lookup subtable.
pub struct SubtableData {
  offset : UInt
  kind : SubtableKind
  coverage : UInt16
}

///|
pub fn SubtableData::coverage(
  self : SubtableData,
  data : Bytes,
  glyph_id : UInt16,
) -> UInt16? {
  coverage(
    data,
    self.offset + self.coverage.to_int().reinterpret_as_uint(),
    glyph_id,
  )
}

///|
/// Feature substitutions for variable fonts.
pub struct FeatureSubsts {
  offset : UInt
}

///|
pub fn FeatureSubsts::new(
  data : Bytes,
  offset : UInt,
  coords : ArrayView[Int],
) -> FeatureSubsts? {
  if offset == 0U || coords.length() == 0 {
    return None
  }
  let b = BeBytes::new(data)
  let base = offset.reinterpret_as_int()
  let count = match b.read_u32(base + 4) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  for i in 0..<count {
    let rec = base + 8 + i * 8
    let condset_table = match b.read_u32(rec) {
      None => return None
      Some(v) => base + v.reinterpret_as_int()
    }
    let condset_count = match b.read_u16(condset_table) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    let mut matched = 0
    for j in 0..<condset_count {
      let cond_table = match b.read_u32(condset_table + 2 + j * 4) {
        None => return None
        Some(v) => condset_table + v.reinterpret_as_int()
      }
      let format = match b.read_u16(cond_table) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      if format != 1 {
        break
      }
      let axis = match b.read_u16(cond_table + 2) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      if axis < 0 || axis >= coords.length() {
        break
      }
      let coord = coords[axis]
      let min = match b.read_i16(cond_table + 4) {
        None => return None
        Some(v) => v
      }
      if coord < min {
        break
      }
      let max = match b.read_i16(cond_table + 6) {
        None => return None
        Some(v) => v
      }
      if coord > max {
        break
      }
      matched = matched + 1
    }
    if matched == condset_count {
      let subst = match b.read_u32(rec + 4) {
        None => return None
        Some(v) => v
      }
      return Some(FeatureSubsts::{ offset: offset + subst })
    }
  }
  None
}

///|
pub fn FeatureSubsts::apply(
  self : FeatureSubsts,
  data : Bytes,
  index : UInt16,
) -> UInt? {
  let b = BeBytes::new(data)
  let mut base = self.offset.reinterpret_as_int()
  let count = match b.read_u16(base + 4) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  base = base + 6
  let mut l = 0
  let mut h = count
  let needle = index.to_int()
  while l < h {
    let i = (l + h) / 2
    let rec = base + i * 6
    let idx = match b.read_u16(rec) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    if needle < idx {
      h = i
    } else if needle > idx {
      l = i + 1
    } else {
      let off = match b.read_u32(rec + 2) {
        None => return None
        Some(v) => v
      }
      return Some(self.offset + off)
    }
  }
  None
}

///|
pub fn lookup_data(
  data : Bytes,
  stage : Byte,
  list_base : UInt,
  index : UInt16,
  mask : Byte,
  gdef : Gdef?,
) -> LookupData? {
  if list_base == 0U {
    return None
  }
  let b = BeBytes::new(data)
  let base0 = list_base.reinterpret_as_int()
  let rec = base0 + 2 + index.to_int() * 2
  let offset = match b.read_u16(rec) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let base = base0 + offset
  let mut kind = match b.read_u16(base) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let flag = match b.read_u16(base + 2) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let f = (flag & 0xFF).to_byte()
  let count = match b.read_u16(base + 4) {
    None => return None
    Some(v) => v.to_uint16()
  }
  let mark_class = ((flag >> 8) & 0xFF).to_byte()
  let ignore_marks = (f & ((1).to_byte() << 3)) != 0
  let mut mark_check : Byte = 0
  let mut mark_set : UInt = 0U
  if !ignore_marks {
    match gdef {
      None => ()
      Some(g) => {
        mark_check = if mark_class != 0 && g.has_mark_classes() { 1 } else { 0 }
        if g.ok() && (flag & 0x10) != 0 {
          let idx = match b.read_u16(base + 6 + count.to_int() * 2) {
            None => return None
            Some(v) => v.to_uint16()
          }
          mark_check = 1
          mark_set = g.mark_set_offset(idx).unwrap_or(0U)
        }
      }
    }
  }
  let is_sub = stage == 0
  let subtables = base + 6
  let is_ext = (is_sub && kind == 7) || (!is_sub && kind == 9)
  if is_ext && count != 0 {
    let s = match b.read_u16(subtables) {
      None => return None
      Some(v) => base + v.reinterpret_as_int()
    }
    kind = match b.read_u16(s + 2) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
  }
  let kind = if stage == 0 {
    match kind {
      1 => LookupKind::SingleSub
      2 => LookupKind::MultiSub
      3 => LookupKind::AltSub
      4 => LookupKind::LigSub
      5 => LookupKind::Context
      6 => LookupKind::ChainContext
      8 => LookupKind::RevChainContext
      _ => return None
    }
  } else {
    match kind {
      1 => LookupKind::SingleAdj
      2 => LookupKind::PairAdj
      3 => LookupKind::Cursive
      4 => LookupKind::MarkToBase
      5 => LookupKind::MarkToLig
      6 => LookupKind::MarkToMark
      7 => LookupKind::Context
      8 => LookupKind::ChainContext
      _ => return None
    }
  }
  let ignored = (f & 0b1110) | ((1).to_byte() << 5)
  Some(LookupData::{
    index,
    stage,
    kind,
    feature: 0,
    mask,
    ignored,
    is_ext,
    offset: base.reinterpret_as_uint(),
    coverage: 0xFFFFFFFFU,
    count,
    subtables: (0, 0),
    mark_set,
    mark_check,
    mark_class,
  })
}

///|
pub fn subtable_data(
  data : Bytes,
  offset : UInt,
  kind : LookupKind,
  fmt : UInt16,
) -> SubtableData? {
  let b = BeBytes::new(data)
  let base = offset.reinterpret_as_int()
  fn cov(data : Bytes, b : BeBytes, base : Int, rel : Int) -> UInt16? {
    let c = match b.read_u16(base + rel) {
      None => return None
      Some(v) => v.to_uint16()
    }
    let abs = (base + c.to_int()).reinterpret_as_uint()
    if validate_coverage(data, abs) {
      Some(c)
    } else {
      None
    }
  }

  match kind {
    LookupKind::SingleSub => {
      let k = match fmt {
        1 => SubtableKind::SingleSub1
        2 => SubtableKind::SingleSub2
        _ => return None
      }
      match cov(data, b, base, 2) {
        None => None
        Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
      }
    }
    LookupKind::MultiSub => {
      let k = match fmt {
        1 => SubtableKind::MultiSub1
        _ => return None
      }
      match cov(data, b, base, 2) {
        None => None
        Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
      }
    }
    LookupKind::AltSub => {
      let k = match fmt {
        1 => SubtableKind::AltSub1
        _ => return None
      }
      match cov(data, b, base, 2) {
        None => None
        Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
      }
    }
    LookupKind::LigSub => {
      let k = match fmt {
        1 => SubtableKind::LigSub1
        _ => return None
      }
      match cov(data, b, base, 2) {
        None => None
        Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
      }
    }
    LookupKind::SingleAdj => {
      let k = match fmt {
        1 => SubtableKind::SingleAdj1
        2 => SubtableKind::SingleAdj2
        _ => return None
      }
      match cov(data, b, base, 2) {
        None => None
        Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
      }
    }
    LookupKind::PairAdj => {
      let k = match fmt {
        1 => SubtableKind::PairAdj1
        2 => SubtableKind::PairAdj2
        _ => return None
      }
      match cov(data, b, base, 2) {
        None => None
        Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
      }
    }
    LookupKind::Cursive => {
      let k = match fmt {
        1 => SubtableKind::Cursive1
        _ => return None
      }
      match cov(data, b, base, 2) {
        None => None
        Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
      }
    }
    LookupKind::MarkToBase => {
      let k = match fmt {
        1 => SubtableKind::MarkToBase1
        _ => return None
      }
      match cov(data, b, base, 2) {
        None => None
        Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
      }
    }
    LookupKind::MarkToLig => {
      let k = match fmt {
        1 => SubtableKind::MarkToLig1
        _ => return None
      }
      match cov(data, b, base, 2) {
        None => None
        Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
      }
    }
    LookupKind::MarkToMark => {
      let k = match fmt {
        1 => SubtableKind::MarkToMark1
        _ => return None
      }
      match cov(data, b, base, 2) {
        None => None
        Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
      }
    }
    LookupKind::Context =>
      if fmt == 1 || fmt == 2 {
        let k = if fmt == 1 {
          SubtableKind::Context1
        } else {
          SubtableKind::Context2
        }
        match cov(data, b, base, 2) {
          None => None
          Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
        }
      } else if fmt == 3 {
        match cov(data, b, base, 6) {
          None => None
          Some(c) =>
            Some(SubtableData::{
              offset,
              kind: SubtableKind::Context3,
              coverage: c,
            })
        }
      } else {
        None
      }
    LookupKind::ChainContext =>
      if fmt == 1 || fmt == 2 {
        let k = if fmt == 1 {
          SubtableKind::ChainContext1
        } else {
          SubtableKind::ChainContext2
        }
        match cov(data, b, base, 2) {
          None => None
          Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
        }
      } else if fmt == 3 {
        let backtrack_len = match b.read_u16(base + 2) {
          None => return None
          Some(v) => v.reinterpret_as_int() * 2
        }
        let input_len = match b.read_u16(base + backtrack_len + 4) {
          None => return None
          Some(v) => v.to_uint16()
        }
        if input_len == 0 {
          return None
        }
        match cov(data, b, base, backtrack_len + 6) {
          None => None
          Some(c) =>
            Some(SubtableData::{
              offset,
              kind: SubtableKind::ChainContext3,
              coverage: c,
            })
        }
      } else {
        None
      }
    LookupKind::RevChainContext => {
      let k = match fmt {
        1 => SubtableKind::RevChainContext1
        _ => return None
      }
      match cov(data, b, base, 2) {
        None => None
        Some(c) => Some(SubtableData::{ offset, kind: k, coverage: c })
      }
    }
  }
}
