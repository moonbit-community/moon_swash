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
/// Extended kerning table (`kerx`) + anchor table (`ankr`).
///
/// Ported from `swash-reference/src/internal/aat.rs` (module `kerx`).

///|
pub struct KerxSubtables {
  b : BeBytes
  version : UInt16
  offset : Int
  len : UInt
  cur : UInt
  ankr : BytesView
}

///|
pub fn kerx_subtables(data : Bytes, kerx : UInt, ankr : UInt) -> KerxSubtables {
  let view = if kerx == 0U {
    aat_empty_view()
  } else {
    aat_slice_from(data, kerx)
  }
  let b = BeBytes::from_view(view)
  let ankr_view = if ankr == 0U {
    aat_empty_view()
  } else {
    aat_slice_from(data, ankr)
  }
  let version = b.read_u16(0).unwrap_or(0).to_uint16()
  let len = b.read_u32(4).unwrap_or(0)
  KerxSubtables::{ b, version, offset: 8, len, cur: 0U, ankr: ankr_view }
}

///|
pub struct KerxSubtable {
  b : BeBytes
  version : UInt16
  size : UInt
  coverage : UInt
  tuple_count : UInt
  ankr : BytesView
}

///|
pub fn KerxSubtables::iter(self : KerxSubtables) -> Iter[KerxSubtable] {
  let b = self.b
  let version = self.version
  let mut offset = self.offset
  let len = self.len
  let mut cur = self.cur
  let ankr = self.ankr
  Iter::new(fn() {
    if cur >= len {
      return None
    }
    cur = cur + 1U
    let base = offset
    let view = aat_subview(b.data(), base)
    let sub = BeBytes::from_view(view)
    let size = match sub.read_u32(0) {
      None => return None
      Some(v) => v
    }
    let coverage = match sub.read_u32(4) {
      None => return None
      Some(v) => v
    }
    let tuple_count = if version.to_int() >= 4 {
      match sub.read_u32(8) {
        None => return None
        Some(v) => v
      }
    } else {
      0U
    }
    offset = offset + size.reinterpret_as_int()
    Some(KerxSubtable::{ b: sub, version, size, coverage, tuple_count, ankr })
  })
}

///|
pub fn KerxSubtable::is_vertical(self : KerxSubtable) -> Bool {
  (self.coverage & 0x80000000U) != 0U
}

///|
pub fn KerxSubtable::is_cross_stream(self : KerxSubtable) -> Bool {
  (self.coverage & 0x40000000U) != 0U
}

///|
pub fn KerxSubtable::should_reverse(self : KerxSubtable, is_rtl : Bool) -> Bool {
  if (self.coverage & 0x10000000U) != 0U {
    !is_rtl
  } else {
    is_rtl
  }
}

///|
pub(all) enum KerxSubtableKind {
  Format0(KerxFormat0)
  Format1(KerxFormat1)
  Format2(KerxFormat2)
  Format4(KerxFormat4)
}

///|
pub fn KerxSubtable::kind(self : KerxSubtable) -> KerxSubtableKind? {
  let format = self.coverage & 0xFFU
  match format {
    0U => KerxFormat0::new(self.b).map(x => KerxSubtableKind::Format0(x))
    1U =>
      KerxFormat1::new(self.b, self.tuple_count).map(x => KerxSubtableKind::Format1(
        x,
      ))
    2U => KerxFormat2::new(self.b).map(x => KerxSubtableKind::Format2(x))
    4U =>
      KerxFormat4::new(self.b, self.ankr).map(x => KerxSubtableKind::Format4(x))
    _ => None
  }
}

// ---- Format0 ---------------------------------------------------------------

///|
pub struct KerxFormat0 {
  b : BeBytes
  count : Int
}

///|
fn KerxFormat0::new(b : BeBytes) -> KerxFormat0? {
  let count = match b.read_u32(12) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  Some(KerxFormat0::{ b, count })
}

///|
pub fn KerxFormat0::get(
  self : KerxFormat0,
  left : UInt16,
  right : UInt16,
) -> Int? {
  let key = (left.to_int().reinterpret_as_uint() << 16) |
    right.to_int().reinterpret_as_uint()
  let base = 28
  let reclen = 6
  let mut l = 0
  let mut h = self.count
  while l < h {
    let i = (l + h) / 2
    let pair = match self.b.read_u32(base + i * reclen) {
      None => return None
      Some(v) => v
    }
    if key > pair {
      l = i + 1
    } else if key < pair {
      h = i
    } else {
      return self.b.read_i16(base + i * reclen + 4)
    }
  }
  None
}

// ---- Format1 ---------------------------------------------------------------

///|
pub struct KerxContextualState {
  mut state : UInt16
  stack : Array[Int]
  mut pos : Int
  mut cycles : Int
}

///|
pub fn KerxContextualState::new() -> KerxContextualState {
  KerxContextualState::{ state: 0, stack: Array::make(8, 0), pos: 0, cycles: 0 }
}

///|
pub struct KerxFormat1 {
  b : BeBytes
  state_table : ExtendedStateTable
  value : Int
  tuple_count : UInt
  tuple_size : Int
}

///|
fn KerxFormat1::new(b0 : BeBytes, tuple_count : UInt) -> KerxFormat1? {
  // Start of extended state table is at offset 12.
  let data_view = aat_subview(b0.data(), 12)
  let b = BeBytes::from_view(data_view)
  let state_table = match ExtendedStateTable::new(data_view) {
    None => return None
    Some(v) => v
  }
  let value = match b.read_u32(16) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let tuple_size = if tuple_count == 0U {
    2
  } else {
    tuple_count.reinterpret_as_int() * 2
  }
  Some(KerxFormat1::{ b, state_table, value, tuple_count, tuple_size })
}

///|
pub fn KerxFormat1::next(
  self : KerxFormat1,
  state : KerxContextualState,
  index : Int,
  glyph_id : UInt16,
  f : (Int, Int) -> Unit?,
) -> Int? {
  let push_flag : UInt16 = 0x8000
  let dont_advance : UInt16 = 0x4000
  let reset_flag : UInt16 = 0x2000
  let class = self.state_table.class(glyph_id)
  let entry = match
    self.state_table.entry(state.state, class, 2, aat_read_u16) {
    None => return None
    Some(v) => v
  }
  state.state = entry.new_state
  if (entry.flags & push_flag) != 0 {
    if state.pos >= state.stack.length() {
      return None
    }
    state.stack[state.pos] = index
    state.pos = state.pos + 1
  }
  if entry.data != (0xFFFF).to_uint16() {
    let mut offset = (self.value + entry.data.to_int()) * self.tuple_size
    while state.pos > 0 {
      let value = match self.b.read_i16(offset) {
        None => return None
        Some(v) => v
      }
      if value == -1 {
        break
      }
      let pos = state.pos - 1
      state.pos = pos
      match f(state.stack[pos], value) {
        None => return None
        Some(_) => ()
      }
      offset = offset + self.tuple_size
    }
  }
  if (entry.flags & reset_flag) != 0 {
    state.pos = 0
  }
  let mut advance = (entry.flags & dont_advance) == 0
  if advance {
    state.cycles = 0
  } else if state.cycles > MAX_CYCLES {
    state.cycles = 0
    advance = true
  } else {
    state.cycles = state.cycles + 1
  }
  Some(if advance { 1 } else { 0 })
}

// ---- Format2 ---------------------------------------------------------------

///|
pub struct KerxFormat2 {
  b : BeBytes
  l_table : Int
  r_table : Int
  array : Int
}

///|
fn KerxFormat2::new(b : BeBytes) -> KerxFormat2? {
  let l_table = match b.read_u32(16) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let r_table = match b.read_u32(20) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let array = match b.read_u32(24) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  Some(KerxFormat2::{ b, l_table, r_table, array })
}

///|
pub fn KerxFormat2::get(
  self : KerxFormat2,
  left : UInt16,
  right : UInt16,
) -> Int? {
  let row = match aat_lookup_u16(self.b, self.l_table, left) {
    None => return None
    Some(v) => v.to_int()
  }
  let col = match aat_lookup_u16(self.b, self.r_table, right) {
    None => return None
    Some(v) => v.to_int()
  }
  self.b.read_i16(self.array + row + col)
}

// ---- Format4 ---------------------------------------------------------------

///|
pub struct KerxFormat4State {
  mut state : UInt16
  mut mark : Int
  mut mark_id : UInt16
  mut cycles : Int
}

///|
pub fn KerxFormat4State::new() -> KerxFormat4State {
  KerxFormat4State::{ state: 0, mark: 0, mark_id: (0).to_uint16(), cycles: 0 }
}

///|
pub struct KerxFormat4 {
  b : BeBytes
  state_table : ExtendedStateTable
  action_type : UInt
  control_table : Int
  ankr : BytesView
}

///|
fn KerxFormat4::new(b0 : BeBytes, ankr : BytesView) -> KerxFormat4? {
  let data_view = aat_subview(b0.data(), 12)
  let b = BeBytes::from_view(data_view)
  let state_table = match ExtendedStateTable::new(data_view) {
    None => return None
    Some(v) => v
  }
  let flags = match b.read_u32(16) {
    None => return None
    Some(v) => v
  }
  let action_type = (flags & 0xC0000000U) >> 30
  let control_table = (flags & 0x00FFFFFFU).reinterpret_as_int()
  Some(KerxFormat4::{ b, state_table, action_type, control_table, ankr })
}

///|
pub fn KerxFormat4::next(
  self : KerxFormat4,
  state : KerxFormat4State,
  index : Int,
  glyph_id : UInt16,
  f : (Int, Int, Double, Double) -> Unit?,
) -> Int? {
  let mark_flag : UInt16 = 0x8000
  let dont_advance : UInt16 = 0x4000
  let class = self.state_table.class(glyph_id)
  let entry = match
    self.state_table.entry(state.state, class, 2, aat_read_u16) {
    None => return None
    Some(v) => v
  }
  state.state = entry.new_state
  if (entry.flags & mark_flag) != 0 {
    state.mark = index
    state.mark_id = glyph_id
  }
  if entry.data != (0xFFFF).to_uint16() {
    let offset = self.control_table + entry.data.to_int() * 2
    match self.action_type {
      1U => {
        let mark_index = match self.b.read_u16(offset) {
          None => return None
          Some(v) => v.to_uint16()
        }
        let cur_index = match self.b.read_u16(offset + 2) {
          None => return None
          Some(v) => v.to_uint16()
        }
        match
          self.anchor_offset(mark_index, state.mark_id, cur_index, glyph_id) {
          None => ()
          Some((x, y)) => {
            let diff = index - state.mark
            if diff < 255 {
              match f(index, diff, x, y) {
                None => return None
                Some(_) => ()
              }
            }
          }
        }
      }
      _ => ()
    }
  }
  let mut advance = (entry.flags & dont_advance) == 0
  if advance {
    state.cycles = 0
  } else if state.cycles > MAX_CYCLES {
    state.cycles = 0
    advance = true
  } else {
    state.cycles = state.cycles + 1
  }
  Some(if advance { 1 } else { 0 })
}

///|
fn KerxFormat4::anchor_offset(
  self : KerxFormat4,
  mark_index : UInt16,
  mark_id : UInt16,
  cur_index : UInt16,
  cur_id : UInt16,
) -> (Double, Double)? {
  let mark_points = match kerx_anchor_points(self.ankr, mark_id) {
    None => return None
    Some(v) => v
  }
  let cur_points = match kerx_anchor_points(self.ankr, cur_id) {
    None => return None
    Some(v) => v
  }
  let (mx, my) = match mark_points.get(mark_index) {
    None => return None
    Some(v) => v
  }
  let (cx, cy) = match cur_points.get(cur_index) {
    None => return None
    Some(v) => v
  }
  Some((mx.to_double() - cx.to_double(), my.to_double() - cy.to_double()))
}

// ---- ankr -----------------------------------------------------------------

///|
pub struct KerxAnchorPoints {
  b : BeBytes
  offset : Int
  len : UInt
}

///|
pub fn kerx_anchor_points(
  data : BytesView,
  glyph_id : UInt16,
) -> KerxAnchorPoints? {
  if data.length() == 0 {
    return None
  }
  let b = BeBytes::from_view(data)
  let lookup_offset = match b.read_u32(4) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let base = match b.read_u32(8) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let off = match aat_lookup_u16(b, lookup_offset, glyph_id) {
    None => return None
    Some(v) => v.to_int()
  }
  let offset = base + off
  let len = match b.read_u32(offset) {
    None => return None
    Some(v) => v
  }
  Some(KerxAnchorPoints::{ b, offset, len })
}

///|
pub fn KerxAnchorPoints::get(
  self : KerxAnchorPoints,
  index : UInt16,
) -> (Int, Int)? {
  let ix = index.to_int()
  if ix.reinterpret_as_uint() >= self.len {
    return None
  }
  let off = self.offset + 4 + ix * 4
  let x = match self.b.read_i16(off) {
    None => return None
    Some(v) => v
  }
  let y = match self.b.read_i16(off + 2) {
    None => return None
    Some(v) => v
  }
  Some((x, y))
}
