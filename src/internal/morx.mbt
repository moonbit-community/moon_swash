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
/// Extended glyph metamorphosis table (`morx`).
///
/// Ported from `swash-reference/src/internal/aat.rs` (module `morx`).

///|
pub struct MorxChains {
  b : BeBytes
  offset : Int
  len : UInt
  cur : UInt
}

///|
pub fn morx_chains(data : Bytes, offset : UInt) -> MorxChains {
  let view = if offset == 0U {
    aat_empty_view()
  } else {
    aat_slice_from(data, offset)
  }
  let b = BeBytes::from_view(view)
  let len = b.read_u32(4).unwrap_or(0)
  MorxChains::{ b, offset: 8, len, cur: 0U }
}

///|
pub struct MorxChain {
  b : BeBytes
  offset : Int
  default_flags : UInt
  feature_count : UInt
  subtable_count : UInt
}

///|
pub fn MorxChains::iter(self : MorxChains) -> Iter[MorxChain] {
  let b = self.b
  let mut offset = self.offset
  let len = self.len
  let mut cur = self.cur
  Iter::new(fn() {
    if cur >= len {
      return None
    }
    cur = cur + 1U
    let base = offset
    let chain_len = match b.read_u32(base + 4) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    offset = offset + chain_len
    let default_flags = match b.read_u32(base) {
      None => return None
      Some(v) => v
    }
    let feature_count = match b.read_u32(base + 8) {
      None => return None
      Some(v) => v
    }
    let subtable_count = match b.read_u32(base + 12) {
      None => return None
      Some(v) => v
    }
    Some(MorxChain::{
      b,
      offset: base,
      default_flags,
      feature_count,
      subtable_count,
    })
  })
}

///|
pub fn MorxChain::default_flags(self : MorxChain) -> UInt {
  self.default_flags
}

///|
pub struct MorxFeature {
  selector : UInt16
  setting_selector : UInt16
  enable_flags : UInt
  disable_flags : UInt
}

///|
pub fn MorxChain::features(self : MorxChain) -> Iter[MorxFeature] {
  let b = self.b
  let base = self.offset + 16
  let len = self.feature_count.reinterpret_as_int()
  let mut cur = 0
  Iter::new(fn() {
    if cur >= len {
      return None
    }
    let i = cur
    cur = cur + 1
    let off = base + i * 12
    let selector = match b.read_u16(off) {
      None => return None
      Some(v) => v.to_uint16()
    }
    let setting_selector = match b.read_u16(off + 2) {
      None => return None
      Some(v) => v.to_uint16()
    }
    let enable_flags = match b.read_u32(off + 4) {
      None => return None
      Some(v) => v
    }
    let disable_flags = match b.read_u32(off + 8) {
      None => return None
      Some(v) => v
    }
    Some(MorxFeature::{
      selector,
      setting_selector,
      enable_flags,
      disable_flags,
    })
  })
}

///|
pub struct MorxSubtables {
  b : BeBytes
  offset : Int
  len : UInt
  cur : UInt
}

///|
pub fn MorxChain::subtables(self : MorxChain) -> MorxSubtables {
  let offset = self.offset + 16 + 12 * self.feature_count.reinterpret_as_int()
  MorxSubtables::{ b: self.b, offset, len: self.subtable_count, cur: 0U }
}

///|
pub struct MorxSubtable {
  b : BeBytes
  offset : Int
  kind : UInt
  coverage : UInt
  flags : UInt
}

///|
pub fn MorxSubtables::iter(self : MorxSubtables) -> Iter[MorxSubtable] {
  let b = self.b
  let mut offset = self.offset
  let len = self.len
  let mut cur = self.cur
  Iter::new(fn() {
    if cur >= len {
      return None
    }
    cur = cur + 1U
    let base = offset
    let size = match b.read_u32(base) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    offset = offset + size
    let coverage = match b.read_u32(base + 4) {
      None => return None
      Some(v) => v
    }
    let kind = coverage & 0xFFU
    let flags = match b.read_u32(base + 8) {
      None => return None
      Some(v) => v
    }
    Some(MorxSubtable::{ b, offset: base, kind, coverage, flags })
  })
}

///|
pub fn MorxSubtable::flags(self : MorxSubtable) -> UInt {
  self.flags
}

///|
pub fn MorxSubtable::should_reverse(self : MorxSubtable, is_rtl : Bool) -> Bool {
  let order_bits = (self.coverage >> 28) & 0b101U
  match order_bits {
    0U => is_rtl
    0b100U => !is_rtl
    0b001U => false
    0b101U => true
    _ => false
  }
}

///|
pub(all) enum MorxSubtableKind {
  Rearrangement(MorxRearrangement)
  Contextual(MorxContextual)
  Ligature(MorxLigature)
  NonContextual(MorxNonContextual)
  Insertion(MorxInsertion)
}

///|
pub fn MorxSubtable::kind(self : MorxSubtable) -> MorxSubtableKind? {
  let data = aat_subview(self.b.data(), self.offset + 12)
  match self.kind {
    0U =>
      MorxRearrangement::new(data).map(x => MorxSubtableKind::Rearrangement(x))
    1U => MorxContextual::new(data).map(x => MorxSubtableKind::Contextual(x))
    2U => MorxLigature::new(data).map(x => MorxSubtableKind::Ligature(x))
    4U => Some(MorxSubtableKind::NonContextual(MorxNonContextual::new(data)))
    5U => MorxInsertion::new(data).map(x => MorxSubtableKind::Insertion(x))
    _ => None
  }
}

// ---- Rearrangement ---------------------------------------------------------

///|
pub struct MorxRearrangement {
  state_table : ExtendedStateTable
}

///|
fn MorxRearrangement::new(data : BytesView) -> MorxRearrangement? {
  ExtendedStateTable::new(data).map(t => MorxRearrangement::{ state_table: t })
}

///|
let rearrangement_map : ReadOnlyArray[Byte] = [
  0x00, // 0  no change
   0x10, // 1  Ax => xA
   0x01, // 2  xD => Dx
   0x11, // 3  AxD => DxA
   0x20, // 4  ABx => xAB
   0x30, // 5  ABx => xBA
   0x02, // 6  xCD => CDx
   0x03, // 7  xCD => DCx
   0x12, // 8  AxCD => CDxA
   0x13, // 9  AxCD => DCxA
   0x21, // 10 ABxD => DxAB
   0x31, // 11 ABxD => DxBA
   0x22, // 12 ABxCD => CDxAB
   0x32, // 13 ABxCD => CDxBA
   0x23, // 14 ABxCD => DCxAB
   0x33, // 15 ABxCD => DCxBA
]

///|
pub struct MorxRearrangementState {
  mut state : UInt16
  mut first : Int
  mut last : Int
  mut cycles : Int
}

///|
pub fn MorxRearrangementState::new() -> MorxRearrangementState {
  MorxRearrangementState::{ state: 0, first: 0, last: 0, cycles: 0 }
}

///|
pub struct MorxRearrange {
  l : Int
  r : Int
  reverse_l : Bool
  reverse_r : Bool
  start : Int
  end : Int
}

///|
pub fn[T] MorxRearrange::apply(self : MorxRearrange, buffer : Array[T]) -> Unit {
  let l = self.l
  let r = self.r
  let start = self.start
  let mut end = self.end + 1
  if end > buffer.length() {
    end = buffer.length()
  }
  if start < 0 || start >= buffer.length() || end <= start {
    return
  }
  if end - start < l + r {
    return
  }
  // Save the left/right chunks before shifting the middle.
  let tmp_l : Array[T] = []
  let tmp_r : Array[T] = []
  for i in 0..<l {
    tmp_l.push(buffer[start + i])
  }
  for i in 0..<r {
    tmp_r.push(buffer[end - r + i])
  }
  if l != r {
    // shift middle segment.
    let mid_start = start + l
    let mid_end = end - r
    let delta = r - l
    if delta > 0 {
      // shift right
      let mut i = mid_end - 1
      while i >= mid_start {
        buffer[i + delta] = buffer[i]
        if i == mid_start {
          break
        }
        i = i - 1
      }
    } else if delta < 0 {
      // shift left
      for i in mid_start..<mid_end {
        buffer[i + delta] = buffer[i]
      }
    }
  }
  for i in 0..<r {
    buffer[start + i] = tmp_r[i]
  }
  for i in 0..<l {
    buffer[end - l + i] = tmp_l[i]
  }
  if self.reverse_l {
    buffer.swap(end - 1, end - 2)
  }
  if self.reverse_r {
    buffer.swap(start, start + 1)
  }
}

///|
pub fn MorxRearrangement::next(
  self : MorxRearrangement,
  state : MorxRearrangementState,
  index : Int,
  glyph_id : UInt16,
  end_of_text : Bool,
  f : (MorxRearrange) -> Unit?,
) -> Int? {
  let mark_first : UInt16 = 0x8000
  let dont_advance : UInt16 = 0x4000
  let mark_last : UInt16 = 0x2000
  let class = if end_of_text {
    (0).to_uint16()
  } else {
    self.state_table.class(glyph_id)
  }
  let entry = match
    self.state_table.entry(state.state, class, 0, aat_read_unit) {
    None => return None
    Some(v) => v
  }
  state.state = entry.new_state
  if (entry.flags & mark_first) != 0 {
    state.first = index
  }
  if (entry.flags & mark_last) != 0 {
    state.last = index
  }
  let verb = entry.flags & (0xF).to_uint16()
  let start = state.first
  let end = state.last
  if verb != 0 && start <= end {
    let m = rearrangement_map[verb.to_int() & 0xF].to_int()
    let mut l = m >> 4
    let mut r = m & 0x0F
    if l > 2 {
      l = 2
    }
    if r > 2 {
      r = 2
    }
    let reverse_l = m >> 4 == 3
    let reverse_r = (m & 0x0F) == 3
    match f(MorxRearrange::{ l, r, reverse_l, reverse_r, start, end }) {
      None => return None
      Some(_) => ()
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

// ---- Contextual ------------------------------------------------------------

///|
priv struct MorxContextualData {
  mark_index : UInt16
  current_index : UInt16
}

///|
fn read_morx_contextual_data(b : BeBytes, offset : Int) -> MorxContextualData? {
  let mark_index = match b.read_u16(offset) {
    None => return None
    Some(v) => v.to_uint16()
  }
  let current_index = match b.read_u16(offset + 2) {
    None => return None
    Some(v) => v.to_uint16()
  }
  Some(MorxContextualData::{ mark_index, current_index })
}

///|
pub struct MorxContextual {
  b : BeBytes
  state_table : ExtendedStateTable
  table : Int
}

///|
fn MorxContextual::new(data : BytesView) -> MorxContextual? {
  let b = BeBytes::from_view(data)
  let table = match b.read_u32(16) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let state_table = match ExtendedStateTable::new(data) {
    None => return None
    Some(v) => v
  }
  Some(MorxContextual::{ b, state_table, table })
}

///|
pub struct MorxContextualState {
  mut state : UInt16
  mut mark_set : Bool
  mut mark_index : Int
  mut mark_id : UInt16
}

///|
pub fn MorxContextualState::new() -> MorxContextualState {
  MorxContextualState::{
    state: 0,
    mark_set: false,
    mark_index: 0,
    mark_id: (0).to_uint16(),
  }
}

///|
pub fn MorxContextual::next(
  self : MorxContextual,
  state : MorxContextualState,
  index : Int,
  glyph_id : UInt16,
  end_of_text : Bool,
  f : (Int, UInt16) -> Unit?,
) -> Unit? {
  let set_mark : UInt16 = 0x8000
  let dont_advance : UInt16 = 0x4000
  if end_of_text && !state.mark_set {
    return Some(())
  }
  let mut last_glyph_id = glyph_id
  let mut current_glyph_id = glyph_id
  let mut class = if end_of_text {
    (0).to_uint16()
  } else {
    self.state_table.class(glyph_id)
  }
  if index == 0 && !end_of_text {
    state.mark_index = 0
    state.mark_id = glyph_id
  }
  let mut cycles = 0
  while true {
    let entry = match
      self.state_table.entry(state.state, class, 4, read_morx_contextual_data) {
      None => return None
      Some(v) => v
    }
    state.state = entry.new_state
    if entry.data.mark_index != (0xFFFF).to_uint16() {
      match self.lookup(entry.data.mark_index, state.mark_id) {
        None => ()
        Some(g) => {
          match f(state.mark_index, g) {
            None => return None
            Some(_) => ()
          }
          if state.mark_index == index {
            last_glyph_id = g
            current_glyph_id = g
          }
        }
      }
    }
    if entry.data.current_index != (0xFFFF).to_uint16() {
      match self.lookup(entry.data.current_index, last_glyph_id) {
        None => ()
        Some(g) => {
          match f(index, g) {
            None => return None
            Some(_) => ()
          }
          current_glyph_id = g
        }
      }
    }
    if (entry.flags & set_mark) != 0 {
      state.mark_set = true
      state.mark_index = index
      state.mark_id = current_glyph_id
    }
    if (entry.flags & dont_advance) == 0 || cycles > MAX_CYCLES {
      break
    }
    cycles = cycles + 1
    class = self.state_table.class(current_glyph_id)
    last_glyph_id = current_glyph_id
  }
  Some(())
}

///|
fn MorxContextual::lookup(
  self : MorxContextual,
  table_index : UInt16,
  glyph_id : UInt16,
) -> UInt16? {
  let offset0 = match self.b.read_u32(self.table + table_index.to_int() * 4) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let offset = self.table + offset0
  aat_lookup_u16(self.b, offset, glyph_id)
}

// ---- Ligature --------------------------------------------------------------

///|
pub struct MorxLigature {
  b : BeBytes
  state_table : ExtendedStateTable
  action : Int
  component : Int
  ligature : Int
}

///|
fn MorxLigature::new(data : BytesView) -> MorxLigature? {
  let b = BeBytes::from_view(data)
  let state_table = match ExtendedStateTable::new(data) {
    None => return None
    Some(v) => v
  }
  let action = match b.read_u32(16) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let component = match b.read_u32(20) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let ligature = match b.read_u32(24) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  Some(MorxLigature::{ b, state_table, action, component, ligature })
}

///|
pub struct MorxLigatureState {
  mut state : UInt16
  indices : Array[Int]
  glyphs : Array[UInt16]
  mut pos : Int
}

///|
pub fn MorxLigatureState::new() -> MorxLigatureState {
  MorxLigatureState::{
    state: 0,
    indices: Array::make(32, 0),
    glyphs: Array::make(32, (0).to_uint16()),
    pos: 0,
  }
}

///|
fn MorxLigatureState::push(
  self : MorxLigatureState,
  index : Int,
  glyph_id : UInt16,
) -> Unit? {
  if self.pos < 0 || self.pos >= 32 {
    return None
  }
  self.indices[self.pos] = index
  self.glyphs[self.pos] = glyph_id
  self.pos = self.pos + 1
  Some(())
}

///|
pub fn MorxLigature::next(
  self : MorxLigature,
  state : MorxLigatureState,
  index : Int,
  glyph_id : UInt16,
  end_of_text : Bool,
  f : (Int, UInt16, ArrayView[Int]) -> Unit?,
) -> Unit? {
  let set_component : UInt16 = 0x8000
  let dont_advance : UInt16 = 0x4000
  let perform_action : UInt16 = 0x2000
  let last_flag : UInt = 0x80000000
  let store_flag : UInt = 0x40000000
  let class = if end_of_text {
    (0).to_uint16()
  } else {
    self.state_table.class(glyph_id)
  }
  let mut cycles = 0
  while true {
    let entry = match
      self.state_table.entry(state.state, class, 2, aat_read_u16) {
      None => return None
      Some(v) => v
    }
    state.state = entry.new_state
    if (entry.flags & set_component) != 0 {
      match state.push(index, glyph_id) {
        None => return None
        Some(_) => ()
      }
    }
    if (entry.flags & perform_action) != 0 {
      let mut action_index = entry.data
      let mut ligature_index = 0U
      let end_pos = state.pos
      let mut pos = end_pos
      while pos > 0 {
        pos = pos - 1
        let glyph_index = state.indices[pos]
        let action = match self.action_at(action_index) {
          None => return None
          Some(v) => v
        }
        action_index = (action_index.to_int() + 1).to_uint16()
        let mut off = action & 0x3FFFFFFFU
        if (off & 0x20000000U) != 0U {
          off = off | 0xC0000000U
        }
        let offset_i = off.reinterpret_as_int()
        let component_index_i = state.glyphs[pos].to_int() + offset_i
        if component_index_i < 0 {
          return None
        }
        let component = match
          self.component_at(component_index_i.reinterpret_as_uint()) {
          None => return None
          Some(v) => v
        }
        ligature_index = ligature_index +
          component.to_int().reinterpret_as_uint()
        if (action & (last_flag | store_flag)) != 0U {
          let lig = match self.ligature_at(ligature_index) {
            None => return None
            Some(v) => v
          }
          let comps = state.indices.op_as_view(start=pos + 1, end=end_pos)
          match f(glyph_index, lig, comps) {
            None => return None
            Some(_) => ()
          }
          state.glyphs[pos] = lig
          pos = pos + 1
        }
        if (action & last_flag) != 0U || cycles > MAX_CYCLES * 2 {
          break
        }
        cycles = cycles + 1
      }
      state.pos = pos
    }
    if (entry.flags & dont_advance) == 0 || cycles > MAX_CYCLES {
      break
    }
    cycles = cycles + 1
  }
  Some(())
}

///|
fn MorxLigature::action_at(self : MorxLigature, index : UInt16) -> UInt? {
  self.b.read_u32(self.action + index.to_int() * 4)
}

///|
fn MorxLigature::component_at(self : MorxLigature, index : UInt) -> UInt16? {
  self.b
  .read_u16(self.component + index.reinterpret_as_int() * 2)
  .map(x => x.to_uint16())
}

///|
fn MorxLigature::ligature_at(self : MorxLigature, index : UInt) -> UInt16? {
  self.b
  .read_u16(self.ligature + index.reinterpret_as_int() * 2)
  .map(x => x.to_uint16())
}

// ---- Non-contextual --------------------------------------------------------

///|
pub struct MorxNonContextual {
  b : BeBytes
}

///|
fn MorxNonContextual::new(data : BytesView) -> MorxNonContextual {
  MorxNonContextual::{ b: BeBytes::from_view(data) }
}

///|
pub fn MorxNonContextual::substitute(
  self : MorxNonContextual,
  glyph_id : UInt16,
) -> UInt16? {
  aat_lookup_u16(self.b, 0, glyph_id)
}

// ---- Insertion -------------------------------------------------------------

///|
priv struct MorxInsertionData {
  current_index : UInt16
  mark_index : UInt16
}

///|
fn read_morx_insertion_data(b : BeBytes, offset : Int) -> MorxInsertionData? {
  let current_index = match b.read_u16(offset) {
    None => return None
    Some(v) => v.to_uint16()
  }
  let mark_index = match b.read_u16(offset + 2) {
    None => return None
    Some(v) => v.to_uint16()
  }
  Some(MorxInsertionData::{ current_index, mark_index })
}

///|
pub struct MorxInsertion {
  b : BeBytes
  state_table : ExtendedStateTable
  action : Int
}

///|
fn MorxInsertion::new(data : BytesView) -> MorxInsertion? {
  let b = BeBytes::from_view(data)
  let state_table = match ExtendedStateTable::new(data) {
    None => return None
    Some(v) => v
  }
  let action = match b.read_u32(16) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  Some(MorxInsertion::{ b, state_table, action })
}

///|
pub struct MorxInsertionState {
  mut state : UInt16
  mut mark : Int
  mut cycles : Int
}

///|
pub fn MorxInsertionState::new() -> MorxInsertionState {
  MorxInsertionState::{ state: 0, mark: 0, cycles: 0 }
}

///|
pub fn MorxInsertion::next(
  self : MorxInsertion,
  state : MorxInsertionState,
  index : Int,
  glyph_id : UInt16,
  end_of_text : Bool,
  f : (Int, ArrayView[UInt16]) -> Unit?,
) -> Int? {
  let set_mark : UInt16 = 0x8000
  let dont_advance : UInt16 = 0x4000
  let current_insert_before : UInt16 = 0x0800
  let marked_insert_before : UInt16 = 0x0400
  let class = if end_of_text {
    (0).to_uint16()
  } else {
    self.state_table.class(glyph_id)
  }
  let entry = match
    self.state_table.entry(state.state, class, 4, read_morx_insertion_data) {
    None => return None
    Some(v) => v
  }
  state.state = entry.new_state
  let mut working_index = index
  let mut mark_inserted = 0
  if entry.data.mark_index != (0xFFFF).to_uint16() {
    let before = (entry.flags & marked_insert_before) != 0
    let base = if before { state.mark } else { state.mark + 1 }
    let glyphs = match self.marked_glyphs(entry.flags, entry.data.mark_index) {
      None => return None
      Some(v) => v
    }
    mark_inserted = glyphs.length()
    working_index = working_index + mark_inserted
    match f(base, glyphs.op_as_view()) {
      None => return None
      Some(_) => ()
    }
  }
  if (entry.flags & set_mark) != 0 {
    state.mark = index
  }
  let mut current_inserted = 0
  if entry.data.current_index != (0xFFFF).to_uint16() {
    let before = (entry.flags & current_insert_before) != 0
    let base = if before { working_index } else { working_index + 1 }
    let glyphs = match
      self.current_glyphs(entry.flags, entry.data.current_index) {
      None => return None
      Some(v) => v
    }
    current_inserted = glyphs.length()
    match f(base, glyphs.op_as_view()) {
      None => return None
      Some(_) => ()
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
  if advance {
    Some(mark_inserted + current_inserted + 1)
  } else {
    Some(mark_inserted)
  }
}

///|
fn MorxInsertion::marked_glyphs(
  self : MorxInsertion,
  flags : UInt16,
  index : UInt16,
) -> Array[UInt16]? {
  let marked_insert_count : UInt16 = 0x001F
  let len = (flags & marked_insert_count).to_int()
  let offset = self.action + index.to_int() * 2
  aat_read_u16_array(self.b, offset, len)
}

///|
fn MorxInsertion::current_glyphs(
  self : MorxInsertion,
  flags : UInt16,
  index : UInt16,
) -> Array[UInt16]? {
  let current_insert_count : UInt16 = 0x03E0
  let len = (flags & current_insert_count).to_int() >> 5
  let offset = self.action + index.to_int() * 2
  aat_read_u16_array(self.b, offset, len)
}

// ---- ltag + feature tag mapping -------------------------------------------

///|
pub fn morx_language_index(
  data : Bytes,
  ltag : UInt,
  language : String,
) -> UInt? {
  let name = @utf8.encode(language)[:]
  let view = if ltag == 0U { return None } else { aat_slice_from(data, ltag) }
  let b = BeBytes::from_view(view)
  let count = match b.read_u32(8) {
    None => return None
    Some(v) => v
  }
  let mut i = 0U
  while i < count {
    let off = match b.read_u16(12 + i.reinterpret_as_int() * 4) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    let len = match b.read_u16(12 + i.reinterpret_as_int() * 4 + 2) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    if len < 0 || !b.check_range(off, len) {
      return None
    }
    let bytes = view.sub(start=off, end=off + len)
    if bytes.equal(name) {
      return Some(i)
    }
    i = i + 1U
  }
  None
}

// (tag, feature, on, off) sorted by tag.

///|
let at_to_aat : ReadOnlyArray[(UInt, Byte, Byte, Byte)] = [
  (0x61667263U, (11).to_byte(), (1).to_byte(), (0).to_byte()), // "afrc"
  (0x63327063U, (38).to_byte(), (2).to_byte(), (0).to_byte()), // "c2pc"
  (0x63327363U, (38).to_byte(), (1).to_byte(), (0).to_byte()), // "c2sc"
  (0x63616C74U, (36).to_byte(), (0).to_byte(), (1).to_byte()), // "calt"
  (0x63617365U, (33).to_byte(), (0).to_byte(), (1).to_byte()), // "case"
  (0x636C6967U, (1).to_byte(), (18).to_byte(), (19).to_byte()), // "clig"
  (0x63707370U, (33).to_byte(), (2).to_byte(), (3).to_byte()), // "cpsp"
  (0x63737768U, (36).to_byte(), (4).to_byte(), (5).to_byte()), // "cswh"
  (0x646C6967U, (1).to_byte(), (4).to_byte(), (5).to_byte()), // "dlig"
  (0x65787074U, (20).to_byte(), (10).to_byte(), (16).to_byte()), // "expt"
  (0x66726163U, (11).to_byte(), (2).to_byte(), (0).to_byte()), // "frac"
  (0x66776964U, (22).to_byte(), (1).to_byte(), (7).to_byte()), // "fwid"
  (0x68616C74U, (22).to_byte(), (6).to_byte(), (7).to_byte()), // "halt"
  (0x68697374U, (1).to_byte(), (20).to_byte(), (21).to_byte()), // "hist"
  (0x686B6E61U, (34).to_byte(), (0).to_byte(), (1).to_byte()), // "hkna"
  (0x686C6967U, (1).to_byte(), (20).to_byte(), (21).to_byte()), // "hlig"
  (0x686E676CU, (23).to_byte(), (1).to_byte(), (0).to_byte()), // "hngl"
  (0x686F6A6FU, (20).to_byte(), (12).to_byte(), (16).to_byte()), // "hojo"
  (0x68776964U, (22).to_byte(), (2).to_byte(), (7).to_byte()), // "hwid"
  (0x6974616CU, (32).to_byte(), (2).to_byte(), (3).to_byte()), // "ital"
  (0x6A703034U, (20).to_byte(), (11).to_byte(), (16).to_byte()), // "jp04"
  (0x6A703738U, (20).to_byte(), (2).to_byte(), (16).to_byte()), // "jp78"
  (0x6A703833U, (20).to_byte(), (3).to_byte(), (16).to_byte()), // "jp83"
  (0x6A703930U, (20).to_byte(), (4).to_byte(), (16).to_byte()), // "jp90"
  (0x6C696761U, (1).to_byte(), (2).to_byte(), (3).to_byte()), // "liga"
  (0x6C6E756DU, (21).to_byte(), (1).to_byte(), (2).to_byte()), // "lnum"
  (0x6D67726BU, (15).to_byte(), (10).to_byte(), (11).to_byte()), // "mgrk"
  (0x6E6C636BU, (20).to_byte(), (13).to_byte(), (16).to_byte()), // "nlck"
  (0x6F6E756DU, (21).to_byte(), (0).to_byte(), (2).to_byte()), // "onum"
  (0x6F72646EU, (10).to_byte(), (3).to_byte(), (0).to_byte()), // "ordn"
  (0x70616C74U, (22).to_byte(), (5).to_byte(), (7).to_byte()), // "palt"
  (0x70636170U, (37).to_byte(), (2).to_byte(), (0).to_byte()), // "pcap"
  (0x706B6E61U, (22).to_byte(), (0).to_byte(), (7).to_byte()), // "pkna"
  (0x706E756DU, (6).to_byte(), (1).to_byte(), (4).to_byte()), // "pnum"
  (0x70776964U, (22).to_byte(), (0).to_byte(), (7).to_byte()), // "pwid"
  (0x71776964U, (22).to_byte(), (4).to_byte(), (7).to_byte()), // "qwid"
  (0x726C6967U, (1).to_byte(), (0).to_byte(), (1).to_byte()), // "rlig"
  (0x72756279U, (28).to_byte(), (2).to_byte(), (3).to_byte()), // "ruby"
  (0x73696E66U, (10).to_byte(), (4).to_byte(), (0).to_byte()), // "sinf"
  (0x736D6370U, (37).to_byte(), (1).to_byte(), (0).to_byte()), // "smcp"
  (0x736D706CU, (20).to_byte(), (1).to_byte(), (16).to_byte()), // "smpl"
  (0x73733031U, (35).to_byte(), (2).to_byte(), (3).to_byte()), // "ss01"
  (0x73733032U, (35).to_byte(), (4).to_byte(), (5).to_byte()), // "ss02"
  (0x73733033U, (35).to_byte(), (6).to_byte(), (7).to_byte()), // "ss03"
  (0x73733034U, (35).to_byte(), (8).to_byte(), (9).to_byte()), // "ss04"
  (0x73733035U, (35).to_byte(), (10).to_byte(), (11).to_byte()), // "ss05"
  (0x73733036U, (35).to_byte(), (12).to_byte(), (13).to_byte()), // "ss06"
  (0x73733037U, (35).to_byte(), (14).to_byte(), (15).to_byte()), // "ss07"
  (0x73733038U, (35).to_byte(), (16).to_byte(), (17).to_byte()), // "ss08"
  (0x73733039U, (35).to_byte(), (18).to_byte(), (19).to_byte()), // "ss09"
  (0x73733130U, (35).to_byte(), (20).to_byte(), (21).to_byte()), // "ss10"
  (0x73733131U, (35).to_byte(), (22).to_byte(), (23).to_byte()), // "ss11"
  (0x73733132U, (35).to_byte(), (24).to_byte(), (25).to_byte()), // "ss12"
  (0x73733133U, (35).to_byte(), (26).to_byte(), (27).to_byte()), // "ss13"
  (0x73733134U, (35).to_byte(), (28).to_byte(), (29).to_byte()), // "ss14"
  (0x73733135U, (35).to_byte(), (30).to_byte(), (31).to_byte()), // "ss15"
  (0x73733136U, (35).to_byte(), (32).to_byte(), (33).to_byte()), // "ss16"
  (0x73733137U, (35).to_byte(), (34).to_byte(), (35).to_byte()), // "ss17"
  (0x73733138U, (35).to_byte(), (36).to_byte(), (37).to_byte()), // "ss18"
  (0x73733139U, (35).to_byte(), (38).to_byte(), (39).to_byte()), // "ss19"
  (0x73733230U, (35).to_byte(), (40).to_byte(), (41).to_byte()), // "ss20"
  (0x73756273U, (10).to_byte(), (2).to_byte(), (0).to_byte()), // "subs"
  (0x73757073U, (10).to_byte(), (1).to_byte(), (0).to_byte()), // "sups"
  (0x73777368U, (36).to_byte(), (2).to_byte(), (3).to_byte()), // "swsh"
  (0x7469746CU, (19).to_byte(), (4).to_byte(), (0).to_byte()), // "titl"
  (0x746E616DU, (20).to_byte(), (14).to_byte(), (16).to_byte()), // "tnam"
  (0x746E756DU, (6).to_byte(), (0).to_byte(), (4).to_byte()), // "tnum"
  (0x74726164U, (20).to_byte(), (0).to_byte(), (16).to_byte()), // "trad"
  (0x74776964U, (22).to_byte(), (3).to_byte(), (7).to_byte()), // "twid"
  (0x756E6963U, (3).to_byte(), (14).to_byte(), (15).to_byte()), // "unic"
  (0x76616C74U, (22).to_byte(), (5).to_byte(), (7).to_byte()), // "valt"
  (0x76657274U, (4).to_byte(), (0).to_byte(), (1).to_byte()), // "vert"
  (0x7668616CU, (22).to_byte(), (6).to_byte(), (7).to_byte()), // "vhal"
  (0x766B6E61U, (34).to_byte(), (2).to_byte(), (3).to_byte()), // "vkna"
  (0x7670616CU, (22).to_byte(), (5).to_byte(), (7).to_byte()), // "vpal"
  (0x76727432U, (4).to_byte(), (0).to_byte(), (1).to_byte()), // "vrt2"
  (0x7A65726FU, (14).to_byte(), (4).to_byte(), (5).to_byte()), // "zero"
]

///|
pub fn morx_feature_from_tag(tag : UInt) -> (UInt16, (UInt16, UInt16))? {
  let mut l = 0
  let mut h = at_to_aat.length()
  while l < h {
    let i = (l + h) / 2
    let (t, feature, on, off) = at_to_aat[i]
    if tag > t {
      l = i + 1
    } else if tag < t {
      h = i
    } else {
      return Some(
        (
          feature.to_int().to_uint16(),
          (on.to_int().to_uint16(), off.to_int().to_uint16()),
        ),
      )
    }
  }
  None
}
