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
/// Kerning table (`kern`).
///
/// Ported from `swash-reference/src/internal/aat.rs` (module `kern`).

///|
pub struct KernSubtables {
  b : BeBytes
  offset : Int
  len : UInt
  cur : UInt
  is_aat : Bool
}

///|
pub fn kern_subtables(data : Bytes, kern : UInt) -> KernSubtables {
  let view = if kern == 0U {
    aat_empty_view()
  } else {
    aat_slice_from(data, kern)
  }
  let b = BeBytes::from_view(view)
  let version = b.read_u16(0).unwrap_or(0).to_uint16()
  if version == 0 {
    let len = b.read_u16(2).unwrap_or(0)
    KernSubtables::{ b, offset: 4, len, cur: 0U, is_aat: false }
  } else {
    let len = b.read_u32(4).unwrap_or(0)
    KernSubtables::{ b, offset: 8, len, cur: 0U, is_aat: true }
  }
}

///|
pub struct KernSubtable {
  b : BeBytes
  offset : Int
  size : UInt
  is_horizontal : Bool
  cross_stream : Bool
  format : Byte
  is_aat : Bool
}

///|
pub fn KernSubtables::iter(self : KernSubtables) -> Iter[KernSubtable] {
  let b = self.b
  let mut offset = self.offset
  let len = self.len
  let mut cur = self.cur
  let is_aat = self.is_aat
  Iter::new(fn() {
    if cur >= len {
      return None
    }
    cur = cur + 1U
    let base = offset
    let view = aat_subview(b.data(), base)
    let sub = BeBytes::from_view(view)
    let mut sub_offset = 0
    let size = if is_aat {
      sub_offset = 8
      match sub.read_u32(0) {
        None => return None
        Some(v) => v
      }
    } else {
      sub_offset = 6
      match sub.read_u16(2) {
        None => return None
        Some(v) => v
      }
    }
    let coverage = match sub.read_u16(4) {
      None => return None
      Some(v) => v.to_uint16()
    }
    let (is_horizontal, cross_stream, format) = if is_aat {
      let format = (coverage & (0xFF).to_uint16()).to_int().to_byte()
      let is_vertical = (coverage & (0x8000).to_uint16()) != 0
      let cross_stream = (coverage & (0x4000).to_uint16()) != 0
      (!is_vertical, cross_stream, format)
    } else {
      let format = ((coverage & (0xFF00).to_uint16()) >> 8).to_int().to_byte()
      let cov = coverage & (0xFF).to_uint16()
      let is_horizontal = (cov & (1).to_uint16()) != 0
      let cross_stream = (cov & (1 << 2).to_uint16()) != 0
      (is_horizontal, cross_stream, format)
    }
    offset = offset + size.to_int()
    Some(KernSubtable::{
      b: sub,
      offset: sub_offset,
      size,
      is_horizontal,
      cross_stream,
      format,
      is_aat,
    })
  })
}

///|
pub fn KernSubtable::is_horizontal(self : KernSubtable) -> Bool {
  self.is_horizontal
}

///|
pub fn KernSubtable::cross_stream(self : KernSubtable) -> Bool {
  self.cross_stream
}

///|
pub(all) enum KernSubtableKind {
  Format0(KernFormat0)
  Format1(KernFormat1)
}

///|
pub fn KernSubtable::kind(self : KernSubtable) -> KernSubtableKind? {
  match self.format.to_int() {
    0 =>
      KernFormat0::new(self.b, self.offset).map(x => KernSubtableKind::Format0(
        x,
      ))
    1 =>
      KernFormat1::new(self.b, self.offset, self.cross_stream).map(x => KernSubtableKind::Format1(
        x,
      ))
    _ => None
  }
}

// ---- Format0 ---------------------------------------------------------------

///|
pub struct KernFormat0 {
  b : BeBytes
  base : Int
  count : Int
}

///|
fn KernFormat0::new(b : BeBytes, offset : Int) -> KernFormat0? {
  let count = match b.read_u16(offset) {
    None => return None
    Some(v) => v.to_int()
  }
  Some(KernFormat0::{ b, base: offset + 8, count })
}

///|
pub fn KernFormat0::get(
  self : KernFormat0,
  left : UInt16,
  right : UInt16,
) -> Int? {
  let key = (left.to_int().reinterpret_as_uint() << 16) |
    right.to_int().reinterpret_as_uint()
  let reclen = 6
  let mut l = 0
  let mut h = self.count
  while l < h {
    let i = (l + h) / 2
    let pair = match self.b.read_u32(self.base + i * reclen) {
      None => return None
      Some(v) => v
    }
    if key > pair {
      l = i + 1
    } else if key < pair {
      h = i
    } else {
      return self.b.read_i16(self.base + i * reclen + 4)
    }
  }
  None
}

// ---- Format1 ---------------------------------------------------------------

///|
pub struct KernFormat1State {
  mut state : UInt16
  stack : Array[Int]
  mut pos : Int
  mut cycles : Int
}

///|
pub fn KernFormat1State::new() -> KernFormat1State {
  KernFormat1State::{ state: 0, stack: Array::make(8, 0), pos: 0, cycles: 0 }
}

///|
pub struct KernFormat1 {
  b : BeBytes
  state_table : StateTable
  cross_stream : Bool
}

///|
fn KernFormat1::new(
  b0 : BeBytes,
  offset : Int,
  cross_stream : Bool,
) -> KernFormat1? {
  let data_view = aat_subview(b0.data(), offset)
  let b = BeBytes::from_view(data_view)
  let state_table = match StateTable::new(data_view) {
    None => return None
    Some(v) => v
  }
  Some(KernFormat1::{ b, state_table, cross_stream })
}

///|
pub fn KernFormat1::next(
  self : KernFormat1,
  state : KernFormat1State,
  index : Int,
  glyph_id : UInt16,
  f : (Int, Int) -> Unit?,
) -> Int? {
  let push_flag : UInt16 = 0x8000
  let dont_advance : UInt16 = 0x4000
  let class = self.state_table.class(glyph_id)
  let entry = match
    self.state_table.entry(state.state, class, 0, aat_read_unit) {
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
  } else if entry.flags == 0 {
    state.pos = 0
  }
  let mut value_offset = (entry.flags & (0x3FFF).to_uint16()).to_int()
  if value_offset != 0 {
    while state.pos > 0 {
      let mut value = match self.b.read_i16(value_offset) {
        None => return None
        Some(v) => v
      }
      let mut last = false
      if (value & 1) != 0 {
        last = true
        value = value & -2
      }
      let pos = state.pos - 1
      state.pos = pos
      // Cross-stream special value (0x8000) is ignored in upstream.
      if !(self.cross_stream && value == -32768) {
        match f(state.stack[pos], value) {
          None => return None
          Some(_) => ()
        }
      }
      if last {
        state.pos = 0
        break
      }
      value_offset = value_offset + 2
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
