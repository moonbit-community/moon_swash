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
/// AAT state tables.
///
/// Ported from `swash-reference/src/internal/aat.rs` (`ExtendedStateTable`,
/// `StateTable`).

///|
pub(all) struct AatEntry[T] {
  mut new_state : UInt16
  flags : UInt16
  data : T
}

///|
fn[T] aat_read_entry(
  b : BeBytes,
  offset : Int,
  _data_size : Int,
  read_data : (BeBytes, Int) -> T?,
) -> AatEntry[T]? {
  let new_state = match b.read_u16(offset) {
    None => return None
    Some(v) => v.to_uint16()
  }
  let flags = match b.read_u16(offset + 2) {
    None => return None
    Some(v) => v.to_uint16()
  }
  let data = match read_data(b, offset + 4) {
    None => return None
    Some(v) => v
  }
  Some(AatEntry::{ new_state, flags, data })
}

///|
fn aat_read_unit(_b : BeBytes, _offset : Int) -> Unit? {
  Some(())
}

///|
fn aat_read_u16(b : BeBytes, offset : Int) -> UInt16? {
  b.read_u16(offset).map(x => x.to_uint16())
}

///|
pub(all) struct ExtendedStateTable {
  b : BeBytes
  classes : Int
  class_table : Int
  state_array : Int
  entry_table : Int
}

///|
pub fn ExtendedStateTable::new(view : BytesView) -> ExtendedStateTable? {
  let b = BeBytes::from_view(view)
  let classes = match b.read_u32(0) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let class_table = match b.read_u32(4) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let state_array = match b.read_u32(8) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let entry_table = match b.read_u32(12) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  Some(ExtendedStateTable::{ b, classes, class_table, state_array, entry_table })
}

///|
pub fn ExtendedStateTable::class(
  self : ExtendedStateTable,
  glyph_id : UInt16,
) -> UInt16 {
  if glyph_id == (0xFFFF).to_uint16() {
    return (2).to_uint16()
  }
  match aat_lookup_u16(self.b, self.class_table, glyph_id) {
    None => (1).to_uint16()
    Some(v) => v
  }
}

///|
pub fn[T] ExtendedStateTable::entry(
  self : ExtendedStateTable,
  state : UInt16,
  class : UInt16,
  data_size : Int,
  read_data : (BeBytes, Int) -> T?,
) -> AatEntry[T]? {
  if self.classes <= 0 {
    return None
  }
  let mut offset = self.state_array
  offset = offset + state.to_int() * self.classes * 2 + class.to_int() * 2
  let index = match self.b.read_u16(offset) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let entry_offset = self.entry_table + index * (4 + data_size)
  aat_read_entry(self.b, entry_offset, data_size, read_data)
}

///|
pub(all) struct StateTable {
  b : BeBytes
  class_count : Int
  state_array : Int
  states : BytesView
  entry_table : Int
  first_glyph : UInt16
  classes : BytesView
}

///|
pub fn StateTable::new(view : BytesView) -> StateTable? {
  let b = BeBytes::from_view(view)
  let class_count = match b.read_u16(0) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let class_offset = match b.read_u16(2) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let state_array = match b.read_u16(4) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let entry_table = match b.read_u16(6) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if !b.check_range(class_offset, 4) {
    return None
  }
  let first_glyph = match b.read_u16(class_offset) {
    None => return None
    Some(v) => v.to_uint16()
  }
  let glyph_count = match b.read_u16(class_offset + 2) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let classes_start = class_offset + 4
  if glyph_count < 0 || !b.check_range(classes_start, glyph_count) {
    return None
  }
  let classes = view.sub(start=classes_start, end=classes_start + glyph_count)
  if state_array < 0 || state_array > view.length() {
    return None
  }
  let states = view.sub(start=state_array)
  Some(StateTable::{
    b,
    class_count,
    state_array,
    states,
    entry_table,
    first_glyph,
    classes,
  })
}

///|
pub fn StateTable::class(self : StateTable, glyph_id : UInt16) -> UInt16 {
  if glyph_id == (0xFFFF).to_uint16() {
    return (2).to_uint16()
  }
  let index = glyph_id.to_int() - self.first_glyph.to_int()
  if index >= 0 && index < self.classes.length() {
    match self.classes.get(index) {
      None => (1).to_uint16()
      Some(v) => v.to_uint16()
    }
  } else {
    (1).to_uint16()
  }
}

///|
pub fn[T] StateTable::entry(
  self : StateTable,
  state : UInt16,
  class : UInt16,
  data_size : Int,
  read_data : (BeBytes, Int) -> T?,
) -> AatEntry[T]? {
  if self.class_count <= 0 {
    return None
  }
  let index = state.to_int() * self.class_count + class.to_int()
  let entry_index = match self.states.get(index) {
    None => return None
    Some(v) => v.to_int()
  }
  let entry_offset = self.entry_table + entry_index * (4 + data_size)
  let entry = match aat_read_entry(self.b, entry_offset, data_size, read_data) {
    None => return None
    Some(v) => v
  }
  let new_state_off = entry.new_state.to_int() - self.state_array
  if new_state_off < 0 {
    return None
  }
  entry.new_state = (new_state_off / self.class_count).to_uint16()
  Some(entry)
}
