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
/// Shaping buffers and low-level glyph reordering helpers.
///
/// Ported from `swash/src/shape/buffer.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
/// Glyph flags.
pub const SUBSTITUTED : UInt16 = 1

///|
pub const LIGATED : UInt16 = 2

///|
pub const COMPONENT : UInt16 = 4

///|
pub const MARK_ATTACH : UInt16 = 8

///|
pub const CURSIVE_ATTACH : UInt16 = 16

///|
pub const IGNORABLE : UInt16 = 64

///|
const INVALID_GLYPH_ID : UInt16 = 0xFFFF

///|
/// Per glyph shaping data.
pub struct GlyphData {
  mut id : GlyphId
  mut flags : UInt16
  mut class : Byte
  mut char_class : ShapeClass
  mut mark_type : Byte
  joining_type : Byte
  mut mask : Byte
  mut skip : Bool
  mut component : Byte
  mut cluster : UInt
  data : UserData
}

///|
pub fn GlyphData::default() -> GlyphData {
  GlyphData::{
    id: (0).to_uint16(),
    flags: 0,
    class: (0).to_byte(),
    char_class: ShapeClass::Base,
    mark_type: (0).to_byte(),
    joining_type: (0).to_byte(),
    mask: (0).to_byte(),
    skip: false,
    component: (0xFF).to_byte(),
    cluster: 0U,
    data: 0U,
  }
}

///|
pub fn GlyphData::is_component(self : GlyphData) -> Bool {
  (self.flags & COMPONENT) != 0
}

///|
pub fn GlyphData::id(self : GlyphData) -> GlyphId {
  self.id
}

///|
pub fn GlyphData::flags(self : GlyphData) -> UInt16 {
  self.flags
}

///|
pub fn GlyphData::cluster(self : GlyphData) -> UInt {
  self.cluster
}

///|
fn GlyphData::set_char_class(self : GlyphData, c : ShapeClass) -> Unit {
  self.char_class = c
}

///|
fn GlyphData::set_mark_type(self : GlyphData, t : Byte) -> Unit {
  self.mark_type = t
}

///|
/// Per glyph shaping position data.
pub struct PositionData {
  mut base : Byte
  mut flags : UInt16
  mut x : Double
  mut y : Double
  mut advance : Double
}

///|
pub fn PositionData::default() -> PositionData {
  PositionData::{ base: (0).to_byte(), flags: 0, x: 0.0, y: 0.0, advance: 0.0 }
}

///|
fn Glyph::new(g : GlyphData, p : PositionData) -> Glyph {
  Glyph::{
    id: g.id,
    info: GlyphInfo::new(p.flags),
    x: p.x,
    y: p.y,
    advance: p.advance,
    data: g.data,
  }
}

///|
pub struct IndexRange {
  start : Int
  end : Int
}

///|
pub fn IndexRange::new(start : Int, end : Int) -> IndexRange {
  IndexRange::{ start, end }
}

///|
pub fn IndexRange::start(self : IndexRange) -> Int {
  self.start
}

///|
pub fn IndexRange::end(self : IndexRange) -> Int {
  self.end
}

///|
pub struct Buffer {
  glyphs : Array[GlyphData]
  positions : Array[PositionData]
  infos : Array[(ClusterInfo, Bool, UserData)]
  ranges : Array[SourceRange]
  shaped_glyphs : Array[Glyph]
  mut is_rtl : Bool
  mut dotted_circle : GlyphId?
  mut has_cursive : Bool
  mut has_marks : Bool
  mut reversed : Bool
  mut next_cluster : UInt
  mut skip_state : SkipState
  sub_args : Array[UInt16]
  pos_args : Array[UInt16]
}

///|
pub struct SkipState {
  flags : Byte
  mask : Byte
  mark_check : Byte
  mark_class : Byte
  mark_set : UInt
}

///|
pub fn SkipState::default() -> SkipState {
  SkipState::{
    flags: (0).to_byte(),
    mask: (0).to_byte(),
    mark_check: (0).to_byte(),
    mark_class: (0).to_byte(),
    mark_set: 0U,
  }
}

///|
pub fn Buffer::default() -> Buffer {
  Buffer::{
    glyphs: ([] : Array[GlyphData]),
    positions: ([] : Array[PositionData]),
    infos: ([] : Array[(ClusterInfo, Bool, UserData)]),
    ranges: ([] : Array[SourceRange]),
    shaped_glyphs: ([] : Array[Glyph]),
    is_rtl: false,
    dotted_circle: None,
    has_cursive: false,
    has_marks: false,
    reversed: false,
    next_cluster: 0U,
    skip_state: SkipState::default(),
    sub_args: ([] : Array[UInt16]),
    pos_args: ([] : Array[UInt16]),
  }
}

///|
pub fn Buffer::new() -> Buffer {
  Buffer::default()
}

///|
pub fn Buffer::len(self : Buffer) -> Int {
  self.glyphs.length()
}

///|
pub fn Buffer::glyphs(self : Buffer) -> ArrayView[GlyphData] {
  self.glyphs.op_as_view()
}

///|
pub fn Buffer::positions(self : Buffer) -> ArrayView[PositionData] {
  self.positions.op_as_view()
}

///|
pub fn Buffer::ranges(self : Buffer) -> ArrayView[SourceRange] {
  self.ranges.op_as_view()
}

///|
pub fn Buffer::clear(self : Buffer) -> Unit {
  self.glyphs.clear()
  self.positions.clear()
  self.infos.clear()
  self.ranges.clear()
  self.is_rtl = false
  self.reversed = false
  self.has_cursive = false
  self.has_marks = false
  self.dotted_circle = None
  self.next_cluster = 0U
  self.skip_state = SkipState::default()
}

///|
fn Buffer::push_cluster(self : Buffer, cluster : CharCluster) -> Unit {
  self.infos.push((cluster.info(), false, cluster.user_data()))
  self.ranges.push(cluster.range())
}

///|
fn Buffer::push_char(self : Buffer, ch : ClusterChar) -> Unit {
  let cluster = self.next_cluster
  let flags : UInt16 = if ch.is_ignorable() { IGNORABLE } else { 0 }
  self.glyphs.push(GlyphData::{
    id: ch.glyph_id(),
    flags,
    class: (0).to_byte(),
    char_class: ch.shape_class(),
    joining_type: joining_type_index(ch.joining_type()).to_byte(),
    mark_type: (0).to_byte(),
    mask: (0).to_byte(),
    skip: false,
    component: (0xFF).to_byte(),
    cluster,
    data: ch.data(),
  })
}

///|
fn Buffer::_push_hangul_char(self : Buffer, ch : ClusterChar) -> Unit {
  let cluster = self.next_cluster
  let c = ch.ch().to_int()
  let mask = if (c >= 0x1100 && c <= 0x115F) || (c >= 0xA960 && c <= 0xA97C) {
    LJMO_MASK
  } else if (c >= 0x1160 && c <= 0x11A7) || (c >= 0xD7B0 && c <= 0xD7C6) {
    VJMO_MASK
  } else if (c >= 0x11A8 && c <= 0x11FF) || (c >= 0xD7CB && c <= 0xD7FB) {
    TJMO_MASK
  } else {
    LJMO_MASK | VJMO_MASK | TJMO_MASK
  }
  let flags : UInt16 = if ch.is_ignorable() { IGNORABLE } else { 0 }
  self.glyphs.push(GlyphData::{
    id: ch.glyph_id(),
    flags,
    class: (0).to_byte(),
    char_class: ch.shape_class(),
    joining_type: joining_type_index(ch.joining_type()).to_byte(),
    mark_type: (0).to_byte(),
    mask,
    skip: false,
    component: (0xFF).to_byte(),
    cluster,
    data: ch.data(),
  })
}

///|
pub fn Buffer::push(self : Buffer, cluster : CharCluster) -> IndexRange {
  let start = self.glyphs.length()
  let chars = cluster.mapped_chars()
  if cluster.info().is_broken() {
    match self.dotted_circle {
      None => ()
      Some(id) => {
        let first = chars[0]
        self.push_char(
          ClusterChar::new(
            '\u{25CC}',
            first.offset(),
            ShapeClass::Base,
            JoiningType::U,
            false,
            true,
            id,
            first.data(),
          ),
        )
      }
    }
  }
  for ch in chars {
    self.push_char(ch)
  }
  self.next_cluster = self.next_cluster + 1U
  self.push_cluster(cluster)
  IndexRange::new(start, self.glyphs.length())
}

///|
pub fn Buffer::push_order(
  self : Buffer,
  cluster : CharCluster,
  order : ArrayView[Int],
) -> IndexRange {
  let start = self.glyphs.length()
  let chars = cluster.mapped_chars()
  if cluster.info().is_broken() {
    match self.dotted_circle {
      None => ()
      Some(id) => {
        let first = chars[order[0]]
        self.push_char(
          ClusterChar::new(
            '\u{25CC}',
            first.offset(),
            ShapeClass::Base,
            JoiningType::U,
            false,
            true,
            id,
            first.data(),
          ),
        )
      }
    }
  }
  let len = chars.length()
  for i in 0..<len {
    let j = order[i]
    self.push_char(chars[j])
  }
  self.next_cluster = self.next_cluster + 1U
  self.push_cluster(cluster)
  IndexRange::new(start, self.glyphs.length())
}

///|
pub fn Buffer::_push_hangul(self : Buffer, cluster : CharCluster) -> IndexRange {
  let start = self.glyphs.length()
  let chars = cluster.mapped_chars()
  if cluster.info().is_broken() {
    match self.dotted_circle {
      None => ()
      Some(id) => {
        let first = chars[0]
        self.push_char(
          ClusterChar::new(
            '\u{25CC}',
            first.offset(),
            ShapeClass::Base,
            JoiningType::U,
            false,
            true,
            id,
            first.data(),
          ),
        )
      }
    }
  }
  for ch in chars {
    self._push_hangul_char(ch)
  }
  self.next_cluster = self.next_cluster + 1U
  self.push_cluster(cluster)
  IndexRange::new(start, self.glyphs.length())
}

///|
pub fn Buffer::ensure_order(self : Buffer, reversed : Bool) -> Unit {
  if reversed != self.reversed {
    reverse_glyph_data(self.glyphs)
    if self.positions.length() != 0 {
      reverse_position_data(self.positions)
    }
    self.reversed = reversed
  }
}

///|
pub fn Buffer::clear_flags(
  self : Buffer,
  flags : UInt16,
  range : IndexRange?,
) -> Unit {
  let mask : UInt16 = (0xFFFF).to_uint16() ^ flags
  match range {
    None =>
      for i in 0..<self.glyphs.length() {
        self.glyphs[i].flags = self.glyphs[i].flags & mask
      }
    Some(r) =>
      for i in r.start()..<r.end() {
        self.glyphs[i].flags = self.glyphs[i].flags & mask
      }
  }
}

///|
pub fn Buffer::setup_positions(self : Buffer, was_morx : Bool) -> Unit {
  let kept : Array[GlyphData] = []
  for g in self.glyphs.iter() {
    if g.is_component() {
      continue
    }
    if was_morx && g.id == INVALID_GLYPH_ID {
      continue
    }
    kept.push(g)
  }
  self.glyphs.clear()
  for g in kept.iter() {
    self.glyphs.push(g)
  }
  self.positions.clear()
  for _ in 0..<self.glyphs.length() {
    self.positions.push(PositionData::default())
  }
}

///|
pub fn Buffer::substitute(self : Buffer, index : Int, id : GlyphId) -> Unit {
  self.glyphs[index].id = id
  self.glyphs[index].flags = self.glyphs[index].flags | SUBSTITUTED
}

///|
pub fn Buffer::substitute_ligature(
  self : Buffer,
  index : Int,
  id : GlyphId,
  components : ArrayView[Int],
) -> Unit {
  if components.length() == 0 {
    return
  }
  self.glyphs[index].id = id
  self.glyphs[index].flags = self.glyphs[index].flags | (SUBSTITUTED | LIGATED)
  let cluster = self.glyphs[index].cluster
  let mut last_index = index
  let n = components.length()
  for i in 0..<n {
    let cindex = components[i]
    let cluster_ix = self.glyphs[cindex].cluster.reinterpret_as_int()
    let (info, _, data) = self.infos[cluster_ix]
    self.infos[cluster_ix] = (info, true, data)
    self.glyphs[cindex].id = INVALID_GLYPH_ID
    self.glyphs[cindex].flags = self.glyphs[cindex].flags | COMPONENT
    self.glyphs[cindex].class = (5).to_byte()
    self.glyphs[cindex].cluster = cluster
    self.glyphs[cindex].skip = true
    if cindex - last_index > 1 {
      let component = i.to_byte()
      for j in (last_index + 1)..<cindex {
        if self.glyphs[j].mark_type != (0).to_byte() ||
          self.glyphs[j].class == (3).to_byte() {
          self.glyphs[j].component = component
          self.glyphs[j].cluster = cluster
        }
      }
    }
    last_index = cindex
  }
  if last_index + 1 < self.glyphs.length() {
    let last_component = n.to_byte()
    for j in (last_index + 1)..<self.glyphs.length() {
      if self.glyphs[j].mark_type != (0).to_byte() ||
        self.glyphs[j].class == (3).to_byte() {
        self.glyphs[j].component = last_component
        self.glyphs[j].cluster = cluster
      } else {
        break
      }
    }
  }
}

///|
pub fn Buffer::substitute_multiple(
  self : Buffer,
  index : Int,
  ids : ArrayView[UInt16],
) -> Unit {
  let count = ids.length()
  if count == 0 {
    // Remove the glyph.
    let out : Array[GlyphData] = []
    let len = self.glyphs.length()
    for i in 0..<len {
      if i != index {
        out.push(self.glyphs[i])
      }
    }
    self.glyphs.clear()
    for g in out.iter() {
      self.glyphs.push(g)
    }
    return
  } else if count == 1 {
    self.substitute(index, ids[0])
    return
  }
  let g = self.glyphs[index]
  let out : Array[GlyphData] = []
  let len = self.glyphs.length()
  for i in 0..<len {
    if i == index {
      for j in 0..<count {
        out.push(GlyphData::{
          id: ids[j],
          flags: SUBSTITUTED,
          class: g.class,
          char_class: g.char_class,
          mark_type: g.mark_type,
          joining_type: g.joining_type,
          mask: g.mask,
          skip: g.skip,
          component: g.component,
          cluster: g.cluster,
          data: g.data,
        })
      }
    } else {
      out.push(self.glyphs[i])
    }
  }
  self.glyphs.clear()
  for x in out.iter() {
    self.glyphs.push(x)
  }
}

///|
pub fn Buffer::multiply(self : Buffer, index : Int, count : Int) -> Unit {
  if index < 0 || index >= self.glyphs.length() || count <= 0 {
    return
  }
  let g = self.glyphs[index]
  let out : Array[GlyphData] = []
  let len = self.glyphs.length()
  for i in 0..<len {
    if i == index {
      for _ in 0..<count {
        out.push(g)
      }
    }
    out.push(self.glyphs[i])
  }
  self.glyphs.clear()
  for x in out.iter() {
    self.glyphs.push(x)
  }
}

///|
pub fn Buffer::position(
  self : Buffer,
  index : Int,
  x : Double,
  y : Double,
  xadvance : Double,
  _yadvance : Double,
) -> Unit {
  self.positions[index].x = self.positions[index].x + x
  self.positions[index].y = self.positions[index].y + y
  self.positions[index].advance = self.positions[index].advance + xadvance
}

///|
pub fn Buffer::position_cursive(
  self : Buffer,
  index : Int,
  next : Int,
  x : Double,
  y : Double,
) -> Unit {
  self.has_cursive = true
  self.positions[index].flags = CURSIVE_ATTACH
  self.positions[index].y = y
  // self.positions[index].advance = self.positions[index].advance - x
  self.positions[index].base = (next - index).to_byte()
}

///|
pub fn Buffer::position_mark(
  self : Buffer,
  index : Int,
  base : Int,
  dx : Double,
  dy : Double,
) -> Unit {
  self.has_marks = true
  self.positions[index].flags = MARK_ATTACH
  self.positions[index].base = (index - base).to_byte()
  self.positions[index].x = dx
  self.positions[index].y = dy
}

///|
pub fn Buffer::set_join_masks(self : Buffer) -> Unit {
  let mut prev : Int? = None
  let mut state = 0
  let len = self.glyphs.length()
  // Transparent joining type.
  for i in 0..<len {
    let ty = self.glyphs[i].joining_type
    if ty.to_int() == 6 {
      continue
    }
    let (pm, cm, next_state) = join_states[state][ty.to_int()]
    match prev {
      None => ()
      Some(j) => if pm != NONE_MASK { self.glyphs[j].mask = pm }
    }
    self.glyphs[i].mask = cm
    prev = Some(i)
    state = next_state.to_int()
  }
}

///|
fn reverse_glyph_data(arr : Array[GlyphData]) -> Unit {
  if arr.length() <= 1 {
    return
  }
  let mut i = 0
  let mut j = arr.length() - 1
  while i < j {
    let tmp = arr[i]
    arr[i] = arr[j]
    arr[j] = tmp
    i = i + 1
    j = j - 1
  }
}

///|
fn reverse_position_data(arr : Array[PositionData]) -> Unit {
  if arr.length() <= 1 {
    return
  }
  let mut i = 0
  let mut j = arr.length() - 1
  while i < j {
    let tmp = arr[i]
    arr[i] = arr[j]
    arr[j] = tmp
    i = i + 1
    j = j - 1
  }
}

///|
fn joining_type_index(t : JoiningType) -> Int {
  match t {
    JoiningType::U => 0
    JoiningType::L => 1
    JoiningType::R => 2
    JoiningType::D => 3
    JoiningType::Alaph => 4
    JoiningType::DalathRish => 5
    JoiningType::T => 6
  }
}

///|
pub fn reorder_myanmar(
  chars : ArrayView[ClusterChar],
  order : Array[Int],
) -> Unit {
  let ignored : Array[Bool] = Array::makei(MAX_CLUSTER_SIZE, _ => false)
  let mut base : Int? = None
  let mut kinzi : IndexRange? = None
  let mut medial_ra : Int? = None
  let mut vpre : IndexRange? = None
  let mut vblw : Int? = None
  let mut anus : IndexRange? = None
  let mut i = 0
  let mut last_vblw = false
  let len = chars.length()
  if len == 0 {
    return
  }
  while order.length() < len {
    order.push(0)
  }
  match chars[0].shape_class() {
    ShapeClass::Kinzi => {
      kinzi = Some(IndexRange::new(0, 3))
      ignored[0] = true
      ignored[1] = true
      ignored[2] = true
      i = 3
    }
    _ => ()
  }
  while i < len {
    let ch = chars[i]
    let k = ch.shape_class()
    if last_vblw {
      match k {
        ShapeClass::Anusvara => {
          anus = match anus {
            Some(r) => Some(IndexRange::new(r.start(), i - r.start() + 1))
            None => Some(IndexRange::new(i, i + 1))
          }
          ignored[i] = true
          i = i + 1
          continue
        }
        _ => ()
      }
    }
    last_vblw = false
    match k {
      ShapeClass::VBlw => {
        if vblw is None {
          vblw = Some(i)
        }
        last_vblw = true
      }
      _ => ()
    }
    match base {
      None =>
        match k {
          ShapeClass::Base => {
            base = Some(i)
            ignored[i] = true
          }
          ShapeClass::MedialRa => {
            medial_ra = Some(i)
            ignored[i] = true
          }
          ShapeClass::VPre => {
            vpre = match vpre {
              Some(r) => Some(IndexRange::new(r.start(), i - r.start() + 1))
              None => Some(IndexRange::new(i, i + 1))
            }
            ignored[i] = true
          }
          _ => ()
        }
      Some(_) =>
        match k {
          ShapeClass::MedialRa => {
            medial_ra = Some(i)
            ignored[i] = true
          }
          ShapeClass::VPre => {
            vpre = match vpre {
              Some(r) => Some(IndexRange::new(r.start(), i - r.start() + 1))
              None => Some(IndexRange::new(i, i + 1))
            }
            ignored[i] = true
          }
          _ => ()
        }
    }
    i = i + 1
  }
  i = 0
  match vpre {
    None => ()
    Some(r) =>
      for j in r.start()..<r.end() {
        order[i] = j
        i = i + 1
      }
  }
  match medial_ra {
    None => ()
    Some(j) => {
      order[i] = j
      i = i + 1
    }
  }
  match base {
    None => ()
    Some(j) => {
      order[i] = j
      i = i + 1
    }
  }
  match kinzi {
    None => ()
    Some(r) =>
      for j in r.start()..<r.end() {
        order[i] = j
        i = i + 1
      }
  }
  let mut j = 0
  while j < len {
    if ignored[j] {
      j = j + 1
      continue
    }
    match vblw {
      None => ()
      Some(v) =>
        if v == j {
          match anus {
            None => ()
            Some(ar) =>
              for k in ar.start()..<ar.end() {
                order[i] = k
                i = i + 1
              }
          }
          anus = None
        }
    }
    order[i] = j
    i = i + 1
    j = j + 1
  }
}

///|
pub fn reorder_complex(
  glyphs : Array[GlyphData],
  buf : Array[GlyphData],
  order : Array[Int],
) -> Unit {
  let mut first_base : Int? = None
  let mut last_base : Int? = None
  let mut last_halant : Int? = None
  let mut reph : Int? = None
  let mut pref : Int? = None
  let mut vpre : IndexRange? = None
  let mut vmpre : IndexRange? = None
  let ignored : Array[Bool] = Array::makei(64, _ => false)
  let len = glyphs.length()
  while buf.length() < len {
    buf.push(GlyphData::default())
  }
  while order.length() < len {
    order.push(0)
  }
  for i in 0..<len {
    let g = glyphs[i]
    if g.is_component() {
      continue
    }
    match g.char_class {
      ShapeClass::Base => {
        match first_base {
          None => {
            first_base = Some(i)
            ignored[i] = true
          }
          Some(_) => ()
        }
        match last_halant {
          None => last_base = Some(i)
          Some(_) => ()
        }
      }
      ShapeClass::Halant => last_halant = Some(i)
      ShapeClass::Reph =>
        match reph {
          None => {
            reph = Some(i)
            ignored[i] = true
          }
          Some(_) => ()
        }
      ShapeClass::Pref =>
        match pref {
          None => {
            pref = Some(i)
            ignored[i] = true
          }
          Some(_) => ()
        }
      ShapeClass::VPre => {
        vpre = match vpre {
          Some(r) => Some(IndexRange::new(r.start(), i - r.start() + 1))
          None => Some(IndexRange::new(i, i + 1))
        }
        ignored[i] = true
      }
      ShapeClass::VMPre => {
        vmpre = match vmpre {
          Some(r) => Some(IndexRange::new(r.start(), i - r.start() + 1))
          None => Some(IndexRange::new(i, i + 1))
        }
        ignored[i] = true
      }
      _ => ()
    }
  }
  let mut j = 0
  match last_halant {
    None => {
      match vmpre {
        None => ()
        Some(r) =>
          for i in r.start()..<r.end() {
            order[j] = i
            j = j + 1
          }
      }
      match vpre {
        None => ()
        Some(r) =>
          for i in r.start()..<r.end() {
            order[j] = i
            j = j + 1
          }
      }
      match pref {
        None => ()
        Some(i) => {
          order[j] = i
          j = j + 1
        }
      }
    }
    Some(_) => ()
  }
  match first_base {
    None => ()
    Some(i) => {
      order[j] = i
      j = j + 1
    }
  }
  match last_base {
    None =>
      match reph {
        None => ()
        Some(i) => {
          order[j] = i
          j = j + 1
        }
      }
    Some(_) => ()
  }
  for i in 0..<len {
    if ignored[i] {
      continue
    }
    order[j] = i
    j = j + 1
    match last_base {
      None => ()
      Some(lb) =>
        if lb == i {
          match reph {
            None => ()
            Some(r) => {
              order[j] = r
              j = j + 1
            }
          }
        }
    }
    match last_halant {
      None => ()
      Some(lh) =>
        if lh == i {
          match vmpre {
            None => ()
            Some(r) =>
              for k in r.start()..<r.end() {
                order[j] = k
                j = j + 1
              }
          }
          match vpre {
            None => ()
            Some(r) =>
              for k in r.start()..<r.end() {
                order[j] = k
                j = j + 1
              }
          }
          match pref {
            None => ()
            Some(p) => {
              order[j] = p
              j = j + 1
            }
          }
        }
    }
  }
  for i in 0..<len {
    buf[i] = glyphs[i]
  }
  for i in 0..<len {
    let k = order[i]
    glyphs[i] = buf[k]
  }
}

///|
let join_states : ReadOnlyArray[ReadOnlyArray[(Byte, Byte, Byte)]] = [
  //   U,                            L,                       R,                        D,                    ALAPH,                 DALATH_RISH
  // State 0: prev was U, not willing to join.
  [
    (NONE_MASK, NONE_MASK, (0).to_byte()),
    (NONE_MASK, ISOL_MASK, (2).to_byte()),
    (NONE_MASK, ISOL_MASK, (1).to_byte()),
    (NONE_MASK, ISOL_MASK, (2).to_byte()),
    (NONE_MASK, ISOL_MASK, (1).to_byte()),
    (NONE_MASK, ISOL_MASK, (6).to_byte()),
  ],
  // State 1: prev was R or ISOL_MASK/ALAPH, not willing to join.
  [
    (NONE_MASK, NONE_MASK, (0).to_byte()),
    (NONE_MASK, ISOL_MASK, (2).to_byte()),
    (NONE_MASK, ISOL_MASK, (1).to_byte()),
    (NONE_MASK, ISOL_MASK, (2).to_byte()),
    (NONE_MASK, FIN2_MASK, (5).to_byte()),
    (NONE_MASK, ISOL_MASK, (6).to_byte()),
  ],
  // State 2: prev was D/L in ISOL_MASK form, willing to join.
  [
    (NONE_MASK, NONE_MASK, (0).to_byte()),
    (NONE_MASK, ISOL_MASK, (2).to_byte()),
    (INIT_MASK, FINA_MASK, (1).to_byte()),
    (INIT_MASK, FINA_MASK, (3).to_byte()),
    (INIT_MASK, FINA_MASK, (4).to_byte()),
    (INIT_MASK, FINA_MASK, (6).to_byte()),
  ],
  // State 3: prev was D in FINA_MASK form, willing to join.
  [
    (NONE_MASK, NONE_MASK, (0).to_byte()),
    (NONE_MASK, ISOL_MASK, (2).to_byte()),
    (MEDI_MASK, FINA_MASK, (1).to_byte()),
    (MEDI_MASK, FINA_MASK, (3).to_byte()),
    (MEDI_MASK, FINA_MASK, (4).to_byte()),
    (MEDI_MASK, FINA_MASK, (6).to_byte()),
  ],
  // State 4: prev was FINA_MASK ALAPH, not willing to join.
  [
    (NONE_MASK, NONE_MASK, (0).to_byte()),
    (NONE_MASK, ISOL_MASK, (2).to_byte()),
    (MED2_MASK, ISOL_MASK, (1).to_byte()),
    (MED2_MASK, ISOL_MASK, (2).to_byte()),
    (MED2_MASK, FIN2_MASK, (5).to_byte()),
    (MED2_MASK, ISOL_MASK, (6).to_byte()),
  ],
  // State 5: prev was FIN2_MASK/FIN3_MASK ALAPH, not willing to join.
  [
    (NONE_MASK, NONE_MASK, (0).to_byte()),
    (NONE_MASK, ISOL_MASK, (2).to_byte()),
    (ISOL_MASK, ISOL_MASK, (1).to_byte()),
    (ISOL_MASK, ISOL_MASK, (2).to_byte()),
    (ISOL_MASK, FIN2_MASK, (5).to_byte()),
    (ISOL_MASK, ISOL_MASK, (6).to_byte()),
  ],
  // State 6: prev was DALATH/RISH, not willing to join.
  [
    (NONE_MASK, NONE_MASK, (0).to_byte()),
    (NONE_MASK, ISOL_MASK, (2).to_byte()),
    (NONE_MASK, ISOL_MASK, (1).to_byte()),
    (NONE_MASK, ISOL_MASK, (2).to_byte()),
    (NONE_MASK, FIN3_MASK, (5).to_byte()),
    (NONE_MASK, ISOL_MASK, (6).to_byte()),
  ],
]
