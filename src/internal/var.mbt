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
/// Font and metric variation tables (metrics subset).
///
/// Ported from `swash/src/internal/var.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
pub const FVAR : RawTag = 0x66766172 // "fvar"

///|
pub const AVAR : RawTag = 0x61766172 // "avar"

///|
pub const HVAR : RawTag = 0x48564152 // "HVAR"

///|
pub const VVAR : RawTag = 0x56564152 // "VVAR"

///|
pub const MVAR : RawTag = 0x4D564152 // "MVAR"

///|
/// Font variations table.
pub struct Fvar {
  data : BytesView
  axis_offset : UInt
  axis_count : UInt
  axis_size : UInt
  inst_count : UInt
  inst_size : UInt
}

///|
pub fn Fvar::new(data : BytesView) -> Fvar {
  let b = BeBytes::from_view(data)
  Fvar::{
    data,
    axis_offset: b.read_u16(4).unwrap_or(0),
    axis_count: b.read_u16(8).unwrap_or(0),
    axis_size: b.read_u16(10).unwrap_or(0),
    inst_count: b.read_u16(12).unwrap_or(0),
    inst_size: b.read_u16(14).unwrap_or(0),
  }
}

///|
pub fn[T : RawFont] Fvar::from_font(font : T) -> Fvar? {
  table_data(font, FVAR).map(Fvar::new)
}

///|
pub fn Fvar::axis_count(self : Fvar) -> UInt {
  self.axis_count
}

///|
pub fn Fvar::instance_count(self : Fvar) -> UInt {
  self.inst_count
}

///|
fn fvar_fixed_at(b : BeBytes, offset : Int) -> Fixed? {
  b.read_i32(offset).map(Fixed::from_raw)
}

///|
/// Axis of variation in a variable font.
pub struct VarAxis {
  index : UInt
  tag : RawTag
  name_id : UInt
  flags : UInt
  min : Fixed
  default : Fixed
  max : Fixed
}

///|
pub fn VarAxis::default() -> VarAxis {
  VarAxis::{
    index: 0,
    tag: 0,
    name_id: 0,
    flags: 0,
    min: Fixed::zero(),
    default: Fixed::zero(),
    max: Fixed::zero(),
  }
}

///|
pub fn VarAxis::is_hidden(self : VarAxis) -> Bool {
  (self.flags & 1) != 0
}

///|
/// Returns a normalized axis coordinate for the specified value in 2.14 fixed point format.
pub fn VarAxis::normalized_coord(
  self : VarAxis,
  value0 : Fixed,
  avar : (Bytes, UInt)?,
) -> Int {
  let mut value = value0
  if fixed_raw(value) < fixed_raw(self.min) {
    value = self.min
  } else if fixed_raw(value) > fixed_raw(self.max) {
    value = self.max
  }
  value = if fixed_raw(value) < fixed_raw(self.default) {
    -((self.default - value) / (self.default - self.min))
  } else if fixed_raw(value) > fixed_raw(self.default) {
    (value - self.default) / (self.max - self.default)
  } else {
    Fixed::zero()
  }
  value = value.min(Fixed::one()).max(-Fixed::one())
  value = match avar {
    None => value
    Some((data, avar_off)) =>
      match adjust_axis(data, avar_off, self.index, value) {
        None => value
        Some(v) => v
      }
  }
  value.to_f2dot14()
}

///|
/// Named instance in a variable font.
pub struct VarInstance {
  index : UInt
  name_id : UInt
  postscript_name_id : UInt?
  values : Array[Fixed]
}

///|
pub fn Fvar::get_axis(self : Fvar, index : UInt) -> VarAxis? {
  if index >= self.axis_count {
    return None
  }
  let b = BeBytes::from_view(self.data)
  let base = self.axis_offset.reinterpret_as_int()
  let axis_size = self.axis_size.reinterpret_as_int()
  let offset = base + index.reinterpret_as_int() * axis_size
  let tag = match b.read_u32(offset) {
    None => return None
    Some(v) => v
  }
  let min = match fvar_fixed_at(b, offset + 4) {
    None => return None
    Some(v) => v
  }
  let default = match fvar_fixed_at(b, offset + 8) {
    None => return None
    Some(v) => v
  }
  let max = match fvar_fixed_at(b, offset + 12) {
    None => return None
    Some(v) => v
  }
  let flags = match b.read_u16(offset + 16) {
    None => return None
    Some(v) => v
  }
  let name_id = match b.read_u16(offset + 18) {
    None => return None
    Some(v) => v
  }
  Some(VarAxis::{ index, tag, name_id, flags, min, default, max })
}

///|
pub fn Fvar::get_axis_by_tag(self : Fvar, tag : RawTag) -> VarAxis? {
  let b = BeBytes::from_view(self.data)
  let base = self.axis_offset.reinterpret_as_int()
  let axis_size = self.axis_size.reinterpret_as_int()
  let count = self.axis_count.reinterpret_as_int()
  for i in 0..<count {
    let tag_off = base + i * axis_size
    if b.read_u32(tag_off) is Some(t) && t == tag {
      return self.get_axis(i.reinterpret_as_uint())
    }
  }
  None
}

///|
pub fn Fvar::get_instance(self : Fvar, index : UInt) -> VarInstance? {
  if index >= self.inst_count {
    return None
  }
  let b = BeBytes::from_view(self.data)
  let base = self.axis_offset.reinterpret_as_int() +
    self.axis_count.reinterpret_as_int() * self.axis_size.reinterpret_as_int()
  let offset = base +
    index.reinterpret_as_int() * self.inst_size.reinterpret_as_int()
  let name_id = match b.read_u16(offset) {
    None => return None
    Some(v) => v
  }
  let axis_count = self.axis_count.reinterpret_as_int()
  let values : Array[Fixed] = []
  for i in 0..<axis_count {
    let v = match fvar_fixed_at(b, offset + 4 + i * 4) {
      None => return None
      Some(v) => v
    }
    values.push(v)
  }
  let ps_name_offset = 4 + axis_count * 4
  let postscript_name_id = if ps_name_offset ==
    self.inst_size.reinterpret_as_int() - 2 {
    // NOTE: this matches the upstream `swash-reference` implementation.
    b.read_u16(ps_name_offset)
  } else {
    None
  }
  Some(VarInstance::{ index, name_id, postscript_name_id, values })
}

///|
/// Applies adjustments to a coordinate according to the optional axis variation table.
pub fn adjust_axis(
  data : Bytes,
  avar : UInt,
  axis : UInt,
  coord0 : Fixed,
) -> Fixed? {
  if avar == 0 {
    return None
  }
  let base = avar.reinterpret_as_int()
  if base < 0 || base >= data.length() {
    return None
  }
  let table = data[base:]
  let b = BeBytes::from_view(table)
  let major = b.read_u16(0).unwrap_or(0).reinterpret_as_int()
  let minor = b.read_u16(2).unwrap_or(0).reinterpret_as_int()
  if major != 1 || minor != 0 {
    return None
  }
  let axis_count = b.read_u16(4).unwrap_or(0)
  if axis >= axis_count {
    return None
  }
  let map_off = match b.read_u16(8 + axis.reinterpret_as_int() * 2) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if map_off < 0 || map_off + 2 > table.length() {
    return None
  }
  let count = match b.read_u16(map_off) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if count <= 0 {
    return None
  }
  let from_coords : Array[Fixed] = []
  let to_coords : Array[Fixed] = []
  let mut off = map_off + 2
  for _ in 0..<count {
    let from = b.read_i16(off).unwrap_or(0)
    let to = b.read_i16(off + 2).unwrap_or(0)
    off = off + 4
    from_coords.push(Fixed::from_f2dot14(from))
    to_coords.push(Fixed::from_f2dot14(to))
  }
  if from_coords.length() != to_coords.length() || from_coords.is_empty() {
    return None
  }
  let coord = coord0
  let n = from_coords.length()
  let from0 = from_coords.at(0)
  let to0 = to_coords.at(0)
  if fixed_raw(coord) <= fixed_raw(from0) {
    return Some(to0)
  }
  let from_last = from_coords.at(n - 1)
  let to_last = to_coords.at(n - 1)
  if fixed_raw(coord) >= fixed_raw(from_last) {
    return Some(to_last)
  }
  for i in 0..<(n - 1) {
    let from_a = from_coords.at(i)
    let from_b = from_coords.at(i + 1)
    if fixed_raw(coord) >= fixed_raw(from_a) &&
      fixed_raw(coord) <= fixed_raw(from_b) {
      let to_a = to_coords.at(i)
      let to_b = to_coords.at(i + 1)
      let denom = from_b - from_a
      if fixed_raw(denom) == 0 {
        return Some(to_a)
      }
      return Some(to_a + (coord - from_a) * (to_b - to_a) / denom)
    }
  }
  Some(coord)
}

///|
/// Metrics variation table wrapper.
pub struct Mvar {
  data : Bytes
  coords : ArrayView[Int]
  base : Int
  rec_size : Int
  rec_count : Int
  store : UInt
}

///|
pub fn Mvar::new(data : Bytes, mvar : UInt, coords : ArrayView[Int]) -> Mvar? {
  let base = mvar.reinterpret_as_int()
  let b = match BeBytes::with_offset(data, base) {
    None => return None
    Some(v) => v
  }
  let rec_size = match b.read_u16(6) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let rec_count = match b.read_u16(8) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let store_rel = match b.read_u16(10) {
    None => return None
    Some(v) => v
  }
  if rec_count == 0 || store_rel == 0 {
    return None
  }
  Some(Mvar::{
    data,
    coords,
    base,
    rec_size,
    rec_count,
    store: store_rel + mvar,
  })
}

///|
pub fn Mvar::delta(self : Mvar, metric : RawTag) -> Double {
  match self.read_delta(metric) {
    None => 0.0
    Some(d) => d.to_f32()
  }
}

///|
fn Mvar::read_delta(self : Mvar, metric : RawTag) -> Fixed? {
  let base = self.base
  let b = BeBytes::new(self.data)
  let rec_size = self.rec_size
  let mut l = 0
  let mut h = self.rec_count
  while l < h {
    let i = (l + h) / 2
    let offset = base + 12 + i * rec_size
    let t = match b.read_u32(offset) {
      None => return None
      Some(v) => v
    }
    if metric < t {
      h = i
    } else if metric > t {
      l = i + 1
    } else {
      let inner = match b.read_u16(offset + 4) {
        None => return None
        Some(v) => v
      }
      let outer = match b.read_u16(offset + 6) {
        None => return None
        Some(v) => v
      }
      return item_delta(self.data, self.store, outer, inner, self.coords)
    }
  }
  None
}

///|
/// Returns the advance delta for the specified glyph.
pub fn advance_delta(
  data : Bytes,
  xvar : UInt,
  glyph_id : UInt,
  coords : ArrayView[Int],
) -> Double {
  match metric_delta(data, xvar, 8, glyph_id, coords) {
    None => 0.0
    Some(d) => d.to_f32()
  }
}

///|
/// Returns the side bearing delta for the specified glyph.
pub fn sb_delta(
  data : Bytes,
  xvar : UInt,
  glyph_id : UInt,
  coords : ArrayView[Int],
) -> Double {
  match metric_delta(data, xvar, 12, glyph_id, coords) {
    None => 0.0
    Some(d) => d.to_f32()
  }
}

///|
fn read_i8(data : Bytes, offset : Int) -> Int? {
  match BeBytes::new(data).read_u8(offset) {
    None => None
    Some(b) => {
      let u = b.to_int()
      if u >= 128 {
        Some(u - 256)
      } else {
        Some(u)
      }
    }
  }
}

///|
fn fixed_raw(f : Fixed) -> Int {
  f.raw()
}

///|
/// Returns a delta from an item variation store.
pub fn item_delta(
  data : Bytes,
  offset : UInt,
  outer : UInt,
  inner : UInt,
  coords : ArrayView[Int],
) -> Fixed? {
  if offset == 0 {
    return None
  }
  let b = BeBytes::new(data)
  let store = offset.reinterpret_as_int()
  let count = match b.read_u16(store + 6) {
    None => return None
    Some(v) => v
  }
  if outer >= count {
    return None
  }
  let region_base = match b.read_u32(store + 2) {
    None => return None
    Some(v) => store + v.reinterpret_as_int()
  }
  let axis_count = match b.read_u16(region_base) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let region_record_size = axis_count * 6
  let region_count = match b.read_u16(region_base + 2) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let data_base = match b.read_u32(store + 8 + outer.reinterpret_as_int() * 4) {
    None => return None
    Some(v) => store + v.reinterpret_as_int()
  }
  let region_index_base = data_base + 6
  let region_index_count = match b.read_u16(data_base + 4) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let short_count = match b.read_u16(data_base + 2) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let elem_len = region_index_count - short_count + short_count * 2
  let mut delta_base = data_base +
    6 +
    region_index_count * 2 +
    inner.reinterpret_as_int() * elem_len
  let zero = Fixed::zero()
  let one = Fixed::one()
  let mut idx = 0
  let mut delta = zero
  for i in 0..<region_index_count {
    let region_index = match b.read_u16(region_index_base + i * 2) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    if region_index < 0 || region_index >= region_count {
      return None
    }
    let region_offset = region_base + 4 + region_index * region_record_size
    let mut scalar = one
    for axis in 0..<axis_count {
      let region_axis_base = region_offset + axis * 6
      let start = match b.read_i16(region_axis_base) {
        None => return None
        Some(v) => Fixed::from_f2dot14(v)
      }
      let peak = match b.read_i16(region_axis_base + 2) {
        None => return None
        Some(v) => Fixed::from_f2dot14(v)
      }
      let end = match b.read_i16(region_axis_base + 4) {
        None => return None
        Some(v) => Fixed::from_f2dot14(v)
      }
      let coord = if axis < coords.length() {
        Fixed::from_f2dot14(coords[axis])
      } else {
        zero
      }
      if fixed_raw(start) > fixed_raw(peak) ||
        fixed_raw(peak) > fixed_raw(end) ||
        fixed_raw(peak) == 0 ||
        (fixed_raw(start) < 0 && fixed_raw(end) > 0) {
        continue
      } else if fixed_raw(coord) < fixed_raw(start) ||
        fixed_raw(coord) > fixed_raw(end) {
        scalar = zero
        break
      } else if fixed_raw(coord) == fixed_raw(peak) {
        continue
      } else if fixed_raw(coord) < fixed_raw(peak) {
        scalar = scalar * (coord - start) / (peak - start)
      } else {
        scalar = scalar * (end - coord) / (end - peak)
      }
    }
    let val : Int = if idx >= short_count {
      delta_base = delta_base + 1
      match read_i8(data, delta_base - 1) {
        None => return None
        Some(v) => v
      }
    } else {
      delta_base = delta_base + 2
      match b.read_i16(delta_base - 2) {
        None => return None
        Some(v) => v
      }
    }
    idx = idx + 1
    delta = delta + scalar * Fixed::from_i32(val)
  }
  Some(delta)
}

///|
fn metric_delta(
  data : Bytes,
  base : UInt,
  which : Int,
  glyph_id : UInt,
  coords : ArrayView[Int],
) -> Fixed? {
  if base == 0 {
    return None
  }
  let b = BeBytes::new(data)
  let base_i = base.reinterpret_as_int()
  let mut store = match b.read_u32(base_i + 4) {
    None => return None
    Some(v) => v
  }
  if store == 0 {
    return None
  }
  store = store + base
  let mut offset = match b.read_u32(base_i + which) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if offset == 0 {
    if which == 8 {
      return item_delta(data, store, 0, glyph_id, coords)
    } else {
      return None
    }
  }
  offset = offset + base_i
  let format = match b.read_u16(offset) {
    None => return None
    Some(v) => v
  }
  let count = match b.read_u16(offset + 2) {
    None => return None
    Some(v) => v
  }
  if count == 0 {
    return None
  }
  let bit_count = ((format & 0xF) + 1).reinterpret_as_int()
  let entry_size = (((format & 0x30) >> 4) + 1).reinterpret_as_int()
  let base = offset + 4
  let index = (if glyph_id >= count { count - 1 } else { glyph_id }).reinterpret_as_int()
  let entry : UInt = match entry_size {
    1 =>
      match b.read_u8(base + index) {
        None => return None
        Some(v) => v.to_int().reinterpret_as_uint()
      }
    2 =>
      match b.read_u16(base + index * 2) {
        None => return None
        Some(v) => v
      }
    3 =>
      match b.read_u24(base + index * 3) {
        None => return None
        Some(v) => v
      }
    4 =>
      match b.read_u32(base + index * 4) {
        None => return None
        Some(v) => v
      }
    _ => return None
  }
  let outer = entry >> bit_count
  let inner = entry & (((1).reinterpret_as_uint() << bit_count) - 1)
  item_delta(data, store, outer, inner, coords)
}

///|
/// Tags for metrics from the `MVAR` table.
pub const HASC : RawTag = 0x68617363 // "hasc"

///|
pub const HDSC : RawTag = 0x68647363 // "hdsc"

///|
pub const HLGP : RawTag = 0x686C6770 // "hlgp"

///|
pub const VASC : RawTag = 0x76617363 // "vasc"

///|
pub const VDSC : RawTag = 0x76647363 // "vdsc"

///|
pub const VLGP : RawTag = 0x766C6770 // "vlgp"

///|
pub const XHGT : RawTag = 0x78686774 // "xhgt"

///|
pub const CPHT : RawTag = 0x63706874 // "cpht"

///|
pub const UNDO : RawTag = 0x756E646F // "undo"

///|
pub const UNDS : RawTag = 0x756E6473 // "unds"

///|
pub const STRO : RawTag = 0x7374726F // "stro"
