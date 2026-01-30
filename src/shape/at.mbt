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
/// OpenType GSUB/GPOS shaping (AT).
///
/// Ported from `upstream swash/src/shape/at.rs`.
pub type FeatureBit = UInt16

///|
/// Feature mask: up to 256 feature bits packed into 4x u64 words.
pub struct FeatureMask {
  mut b0 : UInt64
  mut b1 : UInt64
  mut b2 : UInt64
  mut b3 : UInt64
}

///|
pub fn FeatureMask::default() -> FeatureMask {
  FeatureMask::{ b0: 0, b1: 0, b2: 0, b3: 0 }
}

///|
pub fn FeatureMask::is_empty(self : FeatureMask) -> Bool {
  self.b0 == 0 && self.b1 == 0 && self.b2 == 0 && self.b3 == 0
}

///|
pub fn FeatureMask::set(self : FeatureMask, bit : FeatureBit) -> Unit {
  let word = bit.to_int() / 64
  let shift = bit.to_int() & 63
  let mask : UInt64 = (1).to_uint64() << shift
  if word == 0 {
    self.b0 = self.b0 | mask
  } else if word == 1 {
    self.b1 = self.b1 | mask
  } else if word == 2 {
    self.b2 = self.b2 | mask
  } else {
    self.b3 = self.b3 | mask
  }
}

///|
pub fn FeatureMask::clear(self : FeatureMask, bit : FeatureBit) -> Unit {
  let word = bit.to_int() / 64
  let shift = bit.to_int() & 63
  let mask : UInt64 = (1).to_uint64() << shift
  let all = (-1).to_int64().reinterpret_as_uint64()
  let inv = all ^ mask
  if word == 0 {
    self.b0 = self.b0 & inv
  } else if word == 1 {
    self.b1 = self.b1 & inv
  } else if word == 2 {
    self.b2 = self.b2 & inv
  } else {
    self.b3 = self.b3 & inv
  }
}

///|
pub fn FeatureMask::has(self : FeatureMask, bit : FeatureBit) -> Bool {
  let word = bit.to_int() / 64
  let shift = bit.to_int() & 63
  let mask : UInt64 = (1).to_uint64() << shift
  if word == 0 {
    (self.b0 & mask) != 0
  } else if word == 1 {
    (self.b1 & mask) != 0
  } else if word == 2 {
    (self.b2 & mask) != 0
  } else {
    (self.b3 & mask) != 0
  }
}

///|
/// Returns the union of two masks.
pub fn FeatureMask::or(self : FeatureMask, other : FeatureMask) -> FeatureMask {
  FeatureMask::{
    b0: self.b0 | other.b0,
    b1: self.b1 | other.b1,
    b2: self.b2 | other.b2,
    b3: self.b3 | other.b3,
  }
}

///|
/// Mutating OR assignment.
pub fn FeatureMask::or_assign(self : FeatureMask, other : FeatureMask) -> Unit {
  self.b0 = self.b0 | other.b0
  self.b1 = self.b1 | other.b1
  self.b2 = self.b2 | other.b2
  self.b3 = self.b3 | other.b3
}

///|
/// Masks or bits for specific feature groups.
pub struct FeatureGroups {
  default : FeatureMask
  mut reph : FeatureBit?
  mut pref : FeatureBit?
  stage1 : FeatureMask
  stage2 : FeatureMask
  basic : FeatureMask
  position : FeatureMask
  vert : FeatureMask
  rtl : FeatureMask
}

///|
pub fn FeatureGroups::default() -> FeatureGroups {
  FeatureGroups::{
    default: FeatureMask::default(),
    reph: None,
    pref: None,
    stage1: FeatureMask::default(),
    stage2: FeatureMask::default(),
    basic: FeatureMask::default(),
    position: FeatureMask::default(),
    vert: FeatureMask::default(),
    rtl: FeatureMask::default(),
  }
}

///|
pub fn feature_bit_to_mask(bit : FeatureBit?) -> FeatureMask {
  match bit {
    None => FeatureMask::default()
    Some(b) => {
      let m = FeatureMask::default()
      m.set(b)
      m
    }
  }
}

///|
/// Offsets for a particular layout stage.
pub struct StageOffsets {
  base : UInt
  lang : UInt
  vars : UInt
}

///|
pub fn StageOffsets::default() -> StageOffsets {
  StageOffsets::{ base: 0U, lang: 0U, vars: 0U }
}

///|
pub fn StageOffsets::new(
  data : Bytes,
  base : UInt,
  script : UInt,
  language : UInt?,
) -> (StageOffsets, (UInt, UInt))? {
  match language_or_default_by_tags(data, base, script, language) {
    None => None
    Some((lang, tags)) => {
      let vars = feature_var_offset(data, base)
      Some((StageOffsets::{ base, lang, vars }, tags))
    }
  }
}

///|
fn language_or_default_by_tags(
  data : Bytes,
  base : UInt,
  script : UInt,
  language : UInt?,
) -> (UInt, (UInt, UInt))? {
  let script_offset_opt = @internal.script_by_tag(data, base, script)
  let (script_offset, script_tag) = match script_offset_opt {
    Some(off) => (off, script)
    None =>
      match @internal.script_by_tag(data, base, @internal.DFLT) {
        None => return None
        Some(off) => (off, @internal.DFLT)
      }
  }
  let (lang_offset, used_default) = match
    @internal.script_language_by_tag(data, script_offset, language) {
    None => return None
    Some(r) => r
  }
  let lang_tag = if used_default {
    @internal.DFLT
  } else {
    match language {
      None => @internal.DFLT
      Some(t) => t
    }
  }
  Some((lang_offset, (script_tag, lang_tag)))
}

///|
fn feature_var_offset(data : Bytes, gsubgpos_offset : UInt) -> UInt {
  if gsubgpos_offset == 0U {
    return 0U
  }
  let base = gsubgpos_offset.reinterpret_as_int()
  let b = @internal.BeBytes::new(data)
  let major = b.read_u16(base).unwrap_or(0U)
  let minor = b.read_u16(base + 2).unwrap_or(0U)
  if major > 1U || (major == 1U && minor >= 1U) {
    let offset = b.read_u32(base + 10).unwrap_or(0U)
    if offset != 0U {
      gsubgpos_offset + offset
    } else {
      0U
    }
  } else {
    0U
  }
}

///|
/// Maximum number of features that are allowed per stage.
const MAX_CACHED_FEATURES : Int = 256

// These limits are used by the lookup application engine (ported later).

///|
const MAX_NESTED_LOOKUPS : Int = 4

///|
const MAX_SEQUENCE : Int = 32

///|
/// Cache of features, lookups and subtables for a particular script/language pair.
///
/// Only the feature-group plumbing is ported in this step; lookup application
/// is implemented as part of the AT shaper task.
pub struct FeatureStore {
  sub_features : Array[(UInt, FeatureBit)]
  pos_features : Array[(UInt, FeatureBit)]
  lookups : Array[@internal.LookupData]
  subtables : Array[@internal.SubtableData]
  coverage : Array[UInt16]
  mut pos_start : Int
  mut sub_count : Int
  mut truncated : Bool
  mut groups : FeatureGroups
}

///|
/// A growable bitset used by the OT coverage cache builder.
priv struct BitSet {
  list : Array[UInt16]
  bits : Array[UInt64]
}

///|
fn BitSet::default() -> BitSet {
  BitSet::{ list: ([] : Array[UInt16]), bits: ([] : Array[UInt64]) }
}

///|
fn BitSet::clear(self : BitSet) -> Unit {
  self.list.clear()
  for i in 0..<self.bits.length() {
    self.bits.set(i, (0).to_uint64())
  }
}

///|
fn BitSet::insert(self : BitSet, value : UInt16) -> Bool {
  let v = value.to_int()
  let index = v / 64
  let shift = v & 63
  let bit = (1).to_uint64() << shift
  if index >= self.bits.length() {
    self.bits.resize(index + 8, (0).to_uint64())
    self.bits.set(index, self.bits[index] | bit)
    self.list.push(value)
    true
  } else {
    let word = self.bits[index]
    if (word & bit) != 0 {
      false
    } else {
      self.bits.set(index, word | bit)
      self.list.push(value)
      true
    }
  }
}

///|
/// Builds a compact coverage cache used to cheaply skip lookups.
///
/// Format matches `upstream swash/src/shape/at.rs`:
/// `[min, max, bitset words (u16)]`, keyed by base index into `FeatureStore.coverage`.
struct CoverageBuilder {
  coverage : BitSet
  mut min : UInt16
  mut max : UInt16
}

///|
fn CoverageBuilder::default() -> CoverageBuilder {
  CoverageBuilder::{
    coverage: BitSet::default(),
    min: 0xFFFFU.to_uint16(),
    max: 0,
  }
}

///|
fn CoverageBuilder::begin(self : CoverageBuilder) -> Unit {
  self.coverage.clear()
  self.min = 0xFFFFU.to_uint16()
  self.max = 0
}

///|
fn CoverageBuilder::add(self : CoverageBuilder, glyph_id : UInt16) -> Unit {
  if self.coverage.insert(glyph_id) {
    if glyph_id < self.min {
      self.min = glyph_id
    }
    if glyph_id > self.max {
      self.max = glyph_id
    }
  }
}

///|
fn CoverageBuilder::add_coverage(
  self : CoverageBuilder,
  data : Bytes,
  base : Int,
) -> Unit? {
  let b = @internal.BeBytes::new(data)
  let fmt = match b.read_u16(base) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let len = match b.read_u16(base + 2) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let arr = base + 4
  if fmt == 1 {
    for i in 0..<len {
      let g = match b.read_u16(arr + i * 2) {
        None => return None
        Some(v) => v.to_uint16()
      }
      self.add(g)
    }
  } else if fmt == 2 {
    for i in 0..<len {
      let rec = arr + i * 6
      let first = match b.read_u16(rec) {
        None => return None
        Some(v) => v.to_uint16()
      }
      let last = match b.read_u16(rec + 2) {
        None => return None
        Some(v) => v.to_uint16()
      }
      let mut g = first.to_int()
      let end = last.to_int()
      while g <= end {
        self.add(g.to_uint16())
        g = g + 1
      }
    }
  } else {
    return None
  }
  Some(())
}

///|
fn CoverageBuilder::finish(self : CoverageBuilder, out : Array[UInt16]) -> UInt {
  if self.coverage.list.length() == 0 {
    return 0xFFFFFFFFU
  }
  let key = out.length().reinterpret_as_uint()
  out.push(self.min)
  out.push(self.max)
  let bit_base = out.length()
  let range_len = self.max.to_int() - self.min.to_int() + 1
  out.resize(out.length() + (range_len + 15) / 16, (0).to_uint16())
  for g in self.coverage.list.iter() {
    let bit = g.to_int() - self.min.to_int()
    let idx = bit_base + bit / 16
    let word = out[idx]
    out.set(idx, word | ((1).to_uint16() << (bit & 15)))
  }
  key
}

///|
/// Builder for a feature cache.
pub struct FeatureStoreBuilder {
  indices : Array[(UInt16, FeatureBit, Byte)]
  coverage : CoverageBuilder
  mut next_bit : FeatureBit
}

///|
pub fn FeatureStoreBuilder::default() -> FeatureStoreBuilder {
  FeatureStoreBuilder::{
    indices: [],
    coverage: CoverageBuilder::default(),
    next_bit: 0,
  }
}

///|
pub fn FeatureStoreBuilder::build(
  self : FeatureStoreBuilder,
  store : Ref[FeatureStore],
  data : Bytes,
  coords : ArrayView[Int],
  gdef : @internal.Gdef,
  gsub : StageOffsets,
  gpos : StageOffsets,
) -> Unit {
  store.val.clear()
  if gsub.base != 0U {
    FeatureStoreBuilder::build_stage(
      self,
      store,
      data,
      coords,
      gdef,
      gsub,
      (0).to_byte(),
    )
    store.val.sub_features.sort_by((a, b) => if a.0 < b.0 {
      -1
    } else if a.0 > b.0 {
      1
    } else {
      0
    })
  }
  store.val.sub_count = store.val.sub_features.length()
  store.val.pos_start = store.val.lookups.length()
  if gpos.base != 0U {
    FeatureStoreBuilder::build_stage(
      self,
      store,
      data,
      coords,
      gdef,
      gpos,
      (1).to_byte(),
    )
    store.val.pos_features.sort_by((a, b) => if a.0 < b.0 {
      -1
    } else if a.0 > b.0 {
      1
    } else {
      0
    })
  }
}

///|
fn FeatureStoreBuilder::build_stage(
  self : FeatureStoreBuilder,
  store : Ref[FeatureStore],
  data : Bytes,
  coords : ArrayView[Int],
  gdef : @internal.Gdef,
  offsets : StageOffsets,
  stage : Byte,
) -> Unit {
  self.next_bit = 0
  self.indices.clear()
  let gdef_opt : @internal.Gdef? = if gdef.ok() { Some(gdef) } else { None }
  let base = offsets.base.reinterpret_as_int()
  let b = @internal.BeBytes::new(data)
  let lbase = offsets.lang.reinterpret_as_int()
  let list_base = match b.read_u16(base + 8) {
    None => return
    Some(v) => offsets.base + v
  }
  let vars : @internal.FeatureSubsts? = @internal.FeatureSubsts::new(
    data,
    offsets.vars,
    coords,
  )
  let fbase = match b.read_u16(base + 6) {
    None => return
    Some(v) => base + v.reinterpret_as_int()
  }
  let count = match b.read_u16(lbase + 4) {
    None => return
    Some(v) => v.reinterpret_as_int()
  }
  let actual_count = if count > MAX_CACHED_FEATURES {
    MAX_CACHED_FEATURES
  } else {
    count
  }
  if actual_count < count {
    store.val.truncated = true
  }
  let features = if stage == (0).to_byte() {
    store.val.sub_features
  } else {
    store.val.pos_features
  }
  for i in 0..<actual_count {
    let findex = match b.read_u16(lbase + 6 + i * 2) {
      None => return
      Some(v) => v.to_uint16()
    }
    let rec = fbase + 2 + findex.to_int() * 6
    let ftag = match b.read_u32(rec) {
      None => return
      Some(v) => v
    }
    let fbit = self.next_bit
    self.next_bit = self.next_bit + 1
    let mask : Byte = if stage == (0).to_byte() {
      match ftag {
        ISOL => ISOL_MASK
        INIT => INIT_MASK
        MEDI => MEDI_MASK
        FINA => FINA_MASK
        MED2 => MED2_MASK
        FIN2 => FIN2_MASK
        FIN3 => FIN3_MASK
        LJMO => LJMO_MASK
        VJMO => VJMO_MASK
        TJMO => TJMO_MASK
        _ => NONE_MASK
      }
    } else {
      (0).to_byte()
    }
    features.push((ftag, fbit))
    let foffset = match vars {
      None => fbase + b.read_u16(rec + 4).unwrap_or(0).reinterpret_as_int()
      Some(v) =>
        match v.apply(data, findex) {
          None => fbase + b.read_u16(rec + 4).unwrap_or(0).reinterpret_as_int()
          Some(off) => off.reinterpret_as_int()
        }
    }
    let lcount = match b.read_u16(foffset + 2) {
      None => return
      Some(v) => v.reinterpret_as_int()
    }
    for j in 0..<lcount {
      let lookup_index = match b.read_u16(foffset + 4 + j * 2) {
        None => return
        Some(v) => v.to_uint16()
      }
      self.indices.push((lookup_index, fbit, mask))
    }
  }
  self.indices.sort_by((a, b) => a.0.to_int() - b.0.to_int())
  let mut last_index : UInt16? = (None : UInt16?)
  for triple in self.indices.iter() {
    let (index, feature, lmask) = triple
    match last_index {
      Some(li) =>
        if li == index {
          if store.val.lookups.length() != 0 {
            let last = store.val.lookups[store.val.lookups.length() - 1]
            let lookup = last
            lookup.set_feature(feature)
            store.val.lookups.push(lookup)
          }
          continue
        }
      None => ()
    }
    match
      @internal.lookup_data(data, stage, list_base, index, lmask, gdef_opt) {
      None => ()
      Some(lookup0) => {
        let start = store.val.subtables.length()
        self.coverage.begin()
        let lookup = lookup0
        match
          FeatureStoreBuilder::collect_subtables(self, store, data, lookup) {
          Some(true) => {
            lookup.set_coverage(self.coverage.finish(store.val.coverage))
            lookup.set_feature(feature)
            store.val.lookups.push(lookup)
            last_index = Some(index)
          }
          _ =>
            // Failed to collect subtables or none were recognized.
            store.val.subtables.truncate(start)
        }
      }
    }
  }
}

///|
fn FeatureStoreBuilder::collect_subtables(
  self : FeatureStoreBuilder,
  store : Ref[FeatureStore],
  data : Bytes,
  lookup : @internal.LookupData,
) -> Bool? {
  let start = store.val.subtables.length()
  if start >= 0xFFFF {
    return None
  }
  let count = lookup.count.to_int()
  for i in 0..<count {
    match lookup.subtable_data(data, i.to_uint16()) {
      None => ()
      Some(s) => {
        let base = s.offset.reinterpret_as_int() + s.coverage.to_int()
        match self.coverage.add_coverage(data, base) {
          None => return None
          Some(_) => ()
        }
        store.val.subtables.push(s)
      }
    }
  }
  let end = store.val.subtables.length()
  if end >= 0xFFFF {
    return None
  }
  lookup.set_subtables(start.to_uint16(), end.to_uint16())
  Some(end > start)
}

///|
/// Scratch storage used by the OT lookup application engine.
pub struct Storage {
  stack : Array[LookupState]
  ids : Array[UInt16]
  indices : Array[Int]
}

///|
pub fn Storage::default() -> Storage {
  Storage::{
    stack: Array::makei(MAX_NESTED_LOOKUPS, _ => LookupState::default()),
    ids: Array::makei(MAX_SEQUENCE, _ => (0).to_uint16()),
    indices: Array::makei(MAX_SEQUENCE, _ => 0),
  }
}

///|
/// Lookup cursor state for nested lookups.
struct LookupState {
  mut skip_state : SkipState
  mut cur : Int
  mut end : Int
}

///|
fn LookupState::default() -> LookupState {
  LookupState::{ skip_state: SkipState::default(), cur: 0, end: 0 }
}

///|
/// Temporary 4-tuple used for GPOS value records.
priv struct Pos4 {
  mut x : Double
  mut y : Double
  mut xadvance : Double
  mut yadvance : Double
}

///|
fn Pos4::default() -> Pos4 {
  Pos4::{ x: 0.0, y: 0.0, xadvance: 0.0, yadvance: 0.0 }
}

///|
/// Popcount for u16 formats (used by value record sizing).
fn popcount_u16(v : UInt16) -> Int {
  let mut x = v.to_int() & 0xFFFF
  let mut n = 0
  while x != 0 {
    n = n + (x & 1)
    x = x >> 1
  }
  n
}

///|
/// Context used by the OT lookup application engine.
priv struct ApplyContext {
  stage : Byte
  data : Bytes
  gsubgpos : UInt
  defs : @internal.Gdef
  coords : ArrayView[Int]
  enable_var : Bool
  store : FeatureStore
  storage : Storage
  mut top : Byte
  mut arg : UInt16
  start : Int
  mut end : Int
  mut s : LookupState
  buf : Buffer
}

///|
fn ApplyContext::new(
  stage : Byte,
  data : Bytes,
  gsubgpos : UInt,
  defs : @internal.Gdef,
  coords : ArrayView[Int],
  store : FeatureStore,
  storage : Storage,
  buffer : Buffer,
  range : IndexRange,
) -> ApplyContext {
  ApplyContext::{
    stage,
    data,
    gsubgpos,
    defs,
    coords,
    enable_var: defs.has_var_store() && coords.length() != 0,
    store,
    storage,
    top: (0).to_byte(),
    arg: (0).to_uint16(),
    start: range.start,
    end: range.end,
    s: LookupState::default(),
    buf: buffer,
  }
}

///|
fn ApplyContext::apply_skip_state(self : ApplyContext) -> Unit {
  let ss = self.s.skip_state
  let bs = self.buf.skip_state
  if ss.flags == bs.flags &&
    ss.mask == bs.mask &&
    ss.mark_check == bs.mark_check &&
    ss.mark_class == bs.mark_class &&
    ss.mark_set == bs.mark_set {
    return
  }
  self.buf.skip_state = ss
  self.update_glyphs_skip(None)
}

///|
fn ApplyContext::update_glyphs_skip(
  self : ApplyContext,
  range : IndexRange?,
) -> Unit {
  let (start, end) = match range {
    None => (0, self.buf.glyphs.length())
    Some(r) => (r.start, r.end)
  }
  let ss = self.s.skip_state
  let mask = ss.mask
  if ss.mark_check != (0).to_byte() {
    if ss.mark_set != 0U {
      for i in start..<end {
        let g = self.buf.glyphs[i]
        g.skip = (ss.flags & ((1).to_byte() << g.class.to_int())) != 0 ||
          (g.mask & mask) != mask
        if !g.skip && g.class == (3).to_byte() {
          g.skip = self.defs.mark_set_coverage(ss.mark_set, g.id) is None
        }
        self.buf.glyphs.set(i, g)
      }
    } else {
      for i in start..<end {
        let g = self.buf.glyphs[i]
        g.skip = (ss.flags & ((1).to_byte() << g.class.to_int())) != 0 ||
          (g.mask & mask) != mask
        if !g.skip && g.class == (3).to_byte() {
          g.skip = g.mark_type != ss.mark_class
        }
        self.buf.glyphs.set(i, g)
      }
    }
  } else if mask != (0).to_byte() {
    for i in start..<end {
      let g = self.buf.glyphs[i]
      g.skip = (ss.flags & ((1).to_byte() << g.class.to_int())) != 0 ||
        (g.mask & mask) != mask
      self.buf.glyphs.set(i, g)
    }
  } else {
    for i in start..<end {
      let g = self.buf.glyphs[i]
      g.skip = (ss.flags & ((1).to_byte() << g.class.to_int())) != 0
      self.buf.glyphs.set(i, g)
    }
  }
}

///|
fn ApplyContext::update_glyphs(
  self : ApplyContext,
  start : Int,
  end : Int,
) -> Unit {
  if self.defs.has_mark_classes() {
    for i in start..<end {
      let g = self.buf.glyphs[i]
      let class = self.defs.class(g.id).to_byte()
      g.class = class
      g.mark_type = if class == (3).to_byte() {
        self.defs.mark_class(g.id).to_byte()
      } else {
        (0).to_byte()
      }
      self.buf.glyphs.set(i, g)
    }
  } else {
    for i in start..<end {
      let g = self.buf.glyphs[i]
      g.class = self.defs.class(g.id).to_byte()
      self.buf.glyphs.set(i, g)
    }
  }
  self.update_glyphs_skip(Some(IndexRange::new(start, end)))
}

///|
fn ApplyContext::update_glyph(self : ApplyContext, index : Int) -> Unit {
  let ss = self.s.skip_state
  let mask = ss.mask
  let g = self.buf.glyphs[index]
  let class = self.defs.class(g.id).to_byte()
  g.class = class
  g.skip = (ss.flags & ((1).to_byte() << class.to_int())) != 0 ||
    (g.mask & mask) != mask
  if class == (3).to_byte() {
    g.mark_type = if self.defs.has_mark_classes() {
      self.defs.mark_class(g.id).to_byte()
    } else {
      (0).to_byte()
    }
    if ss.mark_check != (0).to_byte() && !g.skip {
      if ss.mark_set != 0U {
        g.skip = self.defs.mark_set_coverage(ss.mark_set, g.id) is None
      } else {
        g.skip = g.mark_type != ss.mark_class
      }
    }
  } else {
    g.mark_type = (0).to_byte()
  }
  self.buf.glyphs.set(index, g)
}

///|
fn ApplyContext::ignored(self : ApplyContext, index : Int) -> Bool {
  self.buf.glyphs[index].skip
}

///|
fn ApplyContext::next(self : ApplyContext, index : Int) -> Int? {
  for i in (index + 1)..<self.s.end {
    if !self.ignored(i) {
      return Some(i)
    }
  }
  None
}

///|
fn ApplyContext::previous(self : ApplyContext, index : Int) -> Int? {
  if index > self.start {
    let mut i = index - 1
    while i >= self.start {
      if !self.ignored(i) {
        return Some(i)
      }
      if i == self.start {
        break
      }
      i = i - 1
    }
  }
  None
}

///|
fn ApplyContext::previous_base(self : ApplyContext, index : Int) -> Int? {
  if index > self.start {
    let mut i = index - 1
    while i >= self.start {
      if !self.ignored(i) {
        let class = self.buf.glyphs[i].class
        if class != (3).to_byte() {
          return Some(i)
        }
      }
      if i == self.start {
        break
      }
      i = i - 1
    }
  }
  None
}

///|
fn ApplyContext::move_first(self : ApplyContext) -> Bool {
  while self.s.cur < self.s.end {
    if !self.buf.glyphs[self.s.cur].skip {
      break
    }
    self.s.cur = self.s.cur + 1
  }
  self.s.cur < self.s.end
}

///|
fn ApplyContext::move_last(self : ApplyContext) -> Bool {
  if self.s.end == 0 {
    return false
  }
  self.s.cur = self.s.end - 1
  while self.ignored(self.s.cur) {
    if self.s.cur == 0 {
      return false
    }
    self.s.cur = self.s.cur - 1
  }
  true
}

///|
fn ApplyContext::move_next(self : ApplyContext) -> Bool {
  self.s.cur = self.s.cur + 1
  while self.s.cur < self.s.end {
    if !self.buf.glyphs[self.s.cur].skip {
      break
    }
    self.s.cur = self.s.cur + 1
  }
  self.s.cur < self.s.end
}

///|
fn ApplyContext::move_to(self : ApplyContext, index : Int) -> Bool {
  if !self.move_first() {
    return false
  }
  for _ in 0..<index {
    if !self.move_next() {
      return false
    }
  }
  true
}

///|
fn ApplyContext::collect_sequence(self : ApplyContext, len : Int) -> Bool {
  let avail = self.s.end - self.s.cur
  if avail < len + 1 {
    return false
  }
  let mut collected = 0
  let mut i = self.s.cur + 1
  while i < self.s.end {
    let g = self.buf.glyphs[i]
    if !g.skip {
      self.storage.indices.set(collected, i)
      self.storage.ids.set(collected, g.id)
      collected = collected + 1
      if collected == len {
        return true
      }
    }
    i = i + 1
  }
  false
}

///|
fn ApplyContext::extend(self : ApplyContext, count : Int) -> Unit {
  self.end = self.end + count
  self.s.end = self.s.end + count
  self.s.cur = self.s.cur + count
  let top = self.top.to_int()
  for i in 0..<top {
    let st = self.storage.stack[i]
    st.end = st.end + count
    st.cur = st.cur + count
    self.storage.stack.set(i, st)
  }
}

///|
fn ApplyContext::match_backtrack(
  self : ApplyContext,
  start : Int,
  len : Int,
  pred : (Int, UInt16) -> Bool,
) -> Bool? {
  let mut idx = start
  for i in 0..<len {
    match self.previous(idx) {
      None => return None
      Some(p) => {
        idx = p
        if !pred(i, self.buf.glyphs[idx].id) {
          return None
        }
      }
    }
  }
  Some(true)
}

///|
fn ApplyContext::match_sequence(
  self : ApplyContext,
  start : Int,
  len : Int,
  pred : (Int, UInt16) -> Bool,
) -> Int? {
  let mut idx = start
  for i in 0..<len {
    match self.next(idx) {
      None => return None
      Some(n) => {
        idx = n
        if !pred(i, self.buf.glyphs[idx].id) {
          return None
        }
      }
    }
  }
  Some(idx)
}

///|
fn ApplyContext::apply(
  self : ApplyContext,
  lookup : @internal.LookupData,
  subtables : (Int, Int),
  cur : Int,
  end : Int?,
  first : Int,
) -> Bool? {
  let feature_index = lookup.feature.to_int()
  self.arg = if lookup.stage == (0).to_byte() {
    self.buf.sub_args[feature_index]
  } else {
    self.buf.pos_args[feature_index]
  }
  self.s.skip_state = SkipState::{
    flags: lookup.ignored,
    mask: lookup.mask,
    mark_check: lookup.mark_check,
    mark_class: lookup.mark_class,
    mark_set: lookup.mark_set,
  }
  self.s.cur = cur
  self.s.end = end.unwrap_or(self.end)
  self.apply_skip_state()
  let mut applied = false
  let (sub_start, sub_end) = subtables
  if lookup.kind is @internal.LookupKind::RevChainContext {
    if !self.move_last() {
      return Some(false)
    }
    while true {
      let i = self.s.cur
      match self.buf.glyphs.get(i) {
        None => return None
        Some(gd) =>
          if !gd.skip {
            let id = gd.id
            if self.store.covers(lookup.coverage, id) {
              for t in sub_start..<sub_end {
                let s = self.store.subtables[t]
                match s.coverage(self.data, id) {
                  None => ()
                  Some(ix) =>
                    if self.apply_subtable(s, ix.to_int(), i, id) == Some(true) {
                      applied = true
                      break
                    }
                }
              }
            }
          }
      }
      if self.s.cur == 0 {
        break
      }
      self.s.cur = self.s.cur - 1
    }
  } else {
    if !self.move_to(first) {
      return Some(false)
    }
    while self.s.cur < self.s.end {
      let i = self.s.cur
      match self.buf.glyphs.get(i) {
        None => return None
        Some(gd) =>
          if !gd.skip {
            let id = gd.id
            if self.store.covers(lookup.coverage, id) {
              for t in sub_start..<sub_end {
                let s = self.store.subtables[t]
                match s.coverage(self.data, id) {
                  None => ()
                  Some(ix) =>
                    if self.apply_subtable(s, ix.to_int(), i, id) == Some(true) {
                      applied = true
                      break
                    }
                }
              }
            }
          }
      }
      self.s.cur = self.s.cur + 1
    }
  }
  Some(applied)
}

///|
fn ApplyContext::apply_subtable(
  self : ApplyContext,
  subtable : @internal.SubtableData,
  index : Int,
  cur : Int,
  g : UInt16,
) -> Bool? {
  let b = @internal.BeBytes::new(self.data)
  let kind = subtable.kind
  let base = subtable.offset.reinterpret_as_int()
  match kind {
    @internal.SubtableKind::SingleSub1 => {
      let delta = match b.read_i16(base + 4) {
        None => return None
        Some(v) => v
      }
      let subst = (g.to_int() + delta).to_uint16()
      self.buf.substitute(cur, subst)
      self.update_glyph(cur)
      Some(true)
    }
    @internal.SubtableKind::SingleSub2 => {
      let arr = base + 6
      let subst = match b.read_u16(arr + index * 2) {
        None => return None
        Some(v) => v.to_uint16()
      }
      self.buf.substitute(cur, subst)
      self.update_glyph(cur)
      Some(true)
    }
    @internal.SubtableKind::MultiSub1 => {
      let seqbase = match b.read_u16(base + 6 + index * 2) {
        None => return None
        Some(v) => base + v.reinterpret_as_int()
      }
      let seqlen = match b.read_u16(seqbase) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      if seqlen > MAX_SEQUENCE {
        return Some(false)
      }
      let seqarr = seqbase + 2
      for i in 0..<seqlen {
        let subst = match b.read_u16(seqarr + i * 2) {
          None => return None
          Some(v) => v.to_uint16()
        }
        self.storage.ids.set(i, subst)
      }
      self.buf.substitute_multiple(cur, self.storage.ids[0:seqlen])
      self.update_glyphs(cur, cur + seqlen)
      self.extend(seqlen - 1)
      Some(true)
    }
    @internal.SubtableKind::AltSub1 => {
      let offset = match b.read_u16(base + 6 + index * 2) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      if offset == 0 {
        return Some(false)
      }
      let arg = self.arg.to_int()
      let setbase = base + offset
      let count = match b.read_u16(setbase) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      if arg >= count {
        return Some(false)
      }
      let subst = match b.read_u16(setbase + 2 + arg * 2) {
        None => return None
        Some(v) => v.to_uint16()
      }
      self.buf.substitute(cur, subst)
      self.update_glyph(cur)
      Some(true)
    }
    @internal.SubtableKind::LigSub1 => {
      let setbase = match b.read_u16(base + 6 + index * 2) {
        None => return None
        Some(v) => base + v.reinterpret_as_int()
      }
      let ligcount = match b.read_u16(setbase) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      let mut seqlen = 0
      for i in 0..<ligcount {
        let ligbase = match b.read_u16(setbase + 2 + i * 2) {
          None => return None
          Some(v) => setbase + v.reinterpret_as_int()
        }
        let mut compcount = match b.read_u16(ligbase + 2) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        if compcount == 0 {
          continue
        }
        compcount = compcount - 1
        if compcount >= MAX_SEQUENCE {
          continue
        }
        let arr = ligbase + 4
        if seqlen < compcount {
          if !self.collect_sequence(compcount) {
            continue
          }
          seqlen = compcount
        }
        let mut matched = true
        for j in 0..<compcount {
          let expected = match b.read_u16(arr + j * 2) {
            None => return None
            Some(v) => v.to_uint16()
          }
          if expected != self.storage.ids[j] {
            matched = false
            break
          }
        }
        if !matched {
          continue
        }
        let glyph = match b.read_u16(ligbase) {
          None => return None
          Some(v) => v.to_uint16()
        }
        self.buf.substitute_ligature(
          cur,
          glyph,
          self.storage.indices[0:compcount],
        )
        self.update_glyph(cur)
        return Some(true)
      }
      None
    }
    @internal.SubtableKind::SingleAdj1 => {
      let pos = Pos4::default()
      let format = match b.read_u16(base + 4) {
        None => return None
        Some(v) => v.to_uint16()
      }
      match self.value_record(base, base + 6, format, pos) {
        None => return None
        Some(_) => ()
      }
      self.buf.position(cur, pos.x, pos.y, pos.xadvance, pos.yadvance)
      Some(true)
    }
    @internal.SubtableKind::SingleAdj2 => {
      let vf = match b.read_u16(base + 4) {
        None => return None
        Some(v) => v.to_uint16()
      }
      let len = popcount_u16(vf) * 2
      let pos = Pos4::default()
      match self.value_record(base, base + 8 + index * len, vf, pos) {
        None => return None
        Some(_) => ()
      }
      self.buf.position(cur, pos.x, pos.y, pos.xadvance, pos.yadvance)
      Some(true)
    }
    @internal.SubtableKind::PairAdj1 => {
      let next = match self.next(cur) {
        None => return None
        Some(v) => v
      }
      let g2 = self.buf.glyphs[next].id
      let vf1 = match b.read_u16(base + 4) {
        None => return None
        Some(v) => v.to_uint16()
      }
      let vf2 = match b.read_u16(base + 6) {
        None => return None
        Some(v) => v.to_uint16()
      }
      let len1 = popcount_u16(vf1) * 2
      let step = len1 + popcount_u16(vf2) * 2 + 2
      let setbase = match b.read_u16(base + 10 + index * 2) {
        None => return None
        Some(v) => base + v.reinterpret_as_int()
      }
      let count = match b.read_u16(setbase) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      let vbase = setbase + 2
      let mut l = 0
      let mut h = count
      while l < h {
        let i = (l + h) / 2
        let v = vbase + i * step
        let gv = match b.read_u16(v) {
          None => return None
          Some(x) => x.to_uint16()
        }
        if g2 > gv {
          l = i + 1
        } else if g2 < gv {
          h = i
        } else {
          if vf1 != 0 {
            let pos = Pos4::default()
            match self.value_record(setbase, v + 2, vf1, pos) {
              None => return None
              Some(_) => ()
            }
            self.buf.position(cur, pos.x, pos.y, pos.xadvance, pos.yadvance)
          }
          if vf2 != 0 {
            let pos = Pos4::default()
            match self.value_record(setbase, v + 2 + len1, vf2, pos) {
              None => return None
              Some(_) => ()
            }
            self.buf.position(next, pos.x, pos.y, pos.xadvance, pos.yadvance)
          }
          return Some(true)
        }
      }
      None
    }
    @internal.SubtableKind::PairAdj2 => {
      let next = match self.next(cur) {
        None => return None
        Some(v) => v
      }
      let g2 = self.buf.glyphs[next].id
      let vf1 = match b.read_u16(base + 4) {
        None => return None
        Some(v) => v.to_uint16()
      }
      let vf2 = match b.read_u16(base + 6) {
        None => return None
        Some(v) => v.to_uint16()
      }
      let len1 = popcount_u16(vf1) * 2
      let step = len1 + popcount_u16(vf2) * 2
      let class1 = match b.read_u16(base + 8) {
        None => return None
        Some(v) => self.class(base + v.reinterpret_as_int(), g).to_int()
      }
      let class2 = match b.read_u16(base + 10) {
        None => return None
        Some(v) => self.class(base + v.reinterpret_as_int(), g2).to_int()
      }
      let class2_count = match b.read_u16(base + 14) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      let v = base + 16 + class1 * step * class2_count + class2 * step
      if vf1 != 0 {
        let pos = Pos4::default()
        match self.value_record(base, v, vf1, pos) {
          None => return None
          Some(_) => ()
        }
        self.buf.position(cur, pos.x, pos.y, pos.xadvance, pos.yadvance)
      }
      if vf2 != 0 {
        let pos = Pos4::default()
        match self.value_record(base, v + len1, vf2, pos) {
          None => return None
          Some(_) => ()
        }
        self.buf.position(next, pos.x, pos.y, pos.xadvance, pos.yadvance)
      }
      Some(true)
    }
    @internal.SubtableKind::Cursive1 => {
      let next = match self.next(cur) {
        None => return None
        Some(v) => v
      }
      if next - cur > 255 {
        return Some(false)
      }
      let g2 = self.buf.glyphs[next].id
      let index2 = match subtable.coverage(self.data, g2) {
        None => return None
        Some(v) => v.to_int()
      }
      let recbase = base + 6
      let mut exit_offset = match b.read_u16(recbase + index * 4 + 2) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      let mut entry_offset = match b.read_u16(recbase + index2 * 4) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      if exit_offset == 0 || entry_offset == 0 {
        return Some(false)
      }
      exit_offset = exit_offset + base
      entry_offset = entry_offset + base
      let exit = match self.anchor(exit_offset) {
        None => return None
        Some(v) => v
      }
      let entry = match self.anchor(entry_offset) {
        None => return None
        Some(v) => v
      }
      self.buf.position_cursive(cur, next, entry.0 - exit.0, entry.1 - exit.1)
      Some(true)
    }
    @internal.SubtableKind::MarkToBase1 | @internal.SubtableKind::MarkToMark1 => {
      let prev = if kind is @internal.SubtableKind::MarkToBase1 {
        match self.previous_base(cur) {
          None => return None
          Some(v) => v
        }
      } else {
        match self.previous(cur) {
          None => return None
          Some(v) => v
        }
      }
      let diff = cur - prev
      if diff > 255 {
        return Some(false)
      }
      let g2 = self.buf.glyphs[prev].id
      let base_cov = match b.read_u16(base + 4) {
        None => return None
        Some(v) => base + v.reinterpret_as_int()
      }
      let index2 = match self.coverage(base_cov, g2) {
        None => return None
        Some(v) => v.to_int()
      }
      let (mark_class, mark_anchor) = {
        let markbase = match b.read_u16(base + 8) {
          None => return None
          Some(v) => base + v.reinterpret_as_int()
        }
        let a = match self.mark_anchor(markbase, index.to_uint16()) {
          None => return None
          Some(v) => v
        }
        (a.0.to_int(), a.1)
      }
      let base_anchor = {
        let class_count = match b.read_u16(base + 6) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        let basebase = match b.read_u16(base + 10) {
          None => return None
          Some(v) => base + v.reinterpret_as_int()
        }
        let base_count = match b.read_u16(basebase) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        let count = base_count * class_count
        let ix = class_count * index2 + mark_class
        if ix >= count {
          return Some(false)
        }
        let abase = match b.read_u16(basebase + 2 + ix * 2) {
          None => return None
          Some(v) => basebase + v.reinterpret_as_int()
        }
        match self.anchor(abase) {
          None => return None
          Some(v) => v
        }
      }
      self.buf.position_mark(
        cur,
        prev,
        base_anchor.0 - mark_anchor.0,
        base_anchor.1 - mark_anchor.1,
      )
      Some(true)
    }
    @internal.SubtableKind::MarkToLig1 => {
      let comp_index = self.buf.glyphs[cur].component.to_int()
      if comp_index == 0xFF {
        return None
      }
      let prev = match self.previous_base(cur) {
        None => return None
        Some(v) => v
      }
      let diff = cur - prev
      if diff > 255 {
        return None
      }
      let g2 = self.buf.glyphs[prev].id
      let mark_index = index.to_uint16()
      let base_index = {
        let base_cov = match b.read_u16(base + 4) {
          None => return None
          Some(v) => base + v.reinterpret_as_int()
        }
        match self.coverage(base_cov, g2) {
          None => return None
          Some(v) => v
        }
      }
      let class_count = match b.read_u16(base + 6) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      let mark_base = match b.read_u16(base + 8) {
        None => return None
        Some(v) => base + v.reinterpret_as_int()
      }
      let mark_anchor = match self.mark_anchor(mark_base, mark_index) {
        None => return None
        Some(v) => v
      }
      let mark_class = mark_anchor.0.to_int()
      let mark_anchor = mark_anchor.1
      let mut lig_array = match b.read_u16(base + 10) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      if lig_array == 0 {
        return None
      }
      lig_array = lig_array + base
      let lig_array_len = match b.read_u16(lig_array) {
        None => return None
        Some(v) => v.to_uint16()
      }
      if base_index >= lig_array_len {
        return None
      }
      let mut lig_attach = match
        b.read_u16(lig_array + 2 + base_index.to_int() * 2) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      if lig_attach == 0 {
        return None
      }
      lig_attach = lig_attach + lig_array
      let comp_count = match b.read_u16(lig_attach) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      if comp_count == 0 || comp_index >= comp_count {
        return None
      }
      let comp_rec = lig_attach +
        2 +
        comp_index * class_count * 2 +
        mark_class * 2
      let anchor_offset = match b.read_u16(comp_rec) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      if anchor_offset == 0 {
        return None
      }
      let base_anchor = match self.anchor(lig_attach + anchor_offset) {
        None => return None
        Some(v) => v
      }
      self.buf.position_mark(
        cur,
        prev,
        base_anchor.0 - mark_anchor.0,
        base_anchor.1 - mark_anchor.1,
      )
      Some(true)
    }
    @internal.SubtableKind::Context1 => {
      let set_index = index
      let mut off = base + 4
      let set_count = match b.read_u16(off) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      off = off + 2
      let set_offsets = match read_u16_array(b, off, set_count) {
        None => return None
        Some(v) => v
      }
      off = off + set_count * 2
      if set_index < 0 || set_index >= set_count {
        return None
      }
      let mut offset = set_offsets[set_index].to_int()
      if offset == 0 {
        return Some(false)
      }
      offset = offset + base
      off = offset
      let rule_count = match b.read_u16(off) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      off = off + 2
      let rule_offsets = match read_u16_array(b, off, rule_count) {
        None => return None
        Some(v) => v
      }
      for i in 0..<rule_count {
        let rule_offset = offset + rule_offsets[i].to_int()
        let mut c = rule_offset
        let mut input_count = match b.read_u16(c) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        c = c + 2
        let subst_count = match b.read_u16(c) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        c = c + 2
        let mut input_end = cur
        if input_count > 1 {
          input_count = input_count - 1
          let seq = match read_u16_array(b, c, input_count) {
            None => return None
            Some(v) => v
          }
          c = c + input_count * 2
          match self.match_sequence(cur, input_count, (j, id) => id == seq[j]) {
            None => continue
            Some(end_ix) => input_end = end_ix
          }
        }
        self.apply_contextual(b, c, subst_count, input_end) |> ignore
        return Some(true)
      }
      None
    }
    @internal.SubtableKind::Context2 => {
      let mut off = base + 4
      let mut input_classdef = match b.read_u16(off) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      off = off + 2
      if input_classdef == 0 {
        return Some(false)
      }
      input_classdef = input_classdef + base
      let set_index = self.class(input_classdef, g).to_int()
      let set_count = match b.read_u16(off) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      off = off + 2
      let set_offsets = match read_u16_array(b, off, set_count) {
        None => return None
        Some(v) => v
      }
      off = off + set_count * 2
      if set_index < 0 || set_index >= set_count {
        return None
      }
      let mut offset = set_offsets[set_index].to_int()
      if offset == 0 {
        return Some(false)
      }
      offset = offset + base
      off = offset
      let rule_count = match b.read_u16(off) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      off = off + 2
      let rule_offsets = match read_u16_array(b, off, rule_count) {
        None => return None
        Some(v) => v
      }
      for i in 0..<rule_count {
        let rule_offset = offset + rule_offsets[i].to_int()
        let mut c = rule_offset
        let mut input_count = match b.read_u16(c) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        c = c + 2
        let subst_count = match b.read_u16(c) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        c = c + 2
        let mut input_end = cur
        if input_count > 1 {
          input_count = input_count - 1
          let seq = match read_u16_array(b, c, input_count) {
            None => return None
            Some(v) => v
          }
          c = c + input_count * 2
          match
            self.match_sequence(cur, input_count, (j, id) => self.class(
                input_classdef, id,
              ) ==
              seq[j]) {
            None => continue
            Some(end_ix) => input_end = end_ix
          }
        }
        self.apply_contextual(b, c, subst_count, input_end) |> ignore
        return Some(true)
      }
      None
    }
    @internal.SubtableKind::Context3 => {
      let mut c = base + 2
      let mut input_count = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      c = c + 2
      if input_count == 0 {
        return None
      }
      input_count = input_count - 1
      let subst_count = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      c = c + 2
      c = c + 2 // skip coverage for the first glyph
      let input = match read_u16_array(b, c, input_count) {
        None => return None
        Some(v) => v
      }
      c = c + input_count * 2
      let input_end = match
        self.match_sequence(cur, input_count, (j, id) => self.coverage(
            base + input[j].to_int(),
            id,
          )
          is Some(_)) {
        None => return None
        Some(v) => v
      }
      self.apply_contextual(b, c, subst_count, input_end) |> ignore
      Some(true)
    }
    @internal.SubtableKind::ChainContext1 => {
      let set_index = index
      let mut off = base + 4
      let set_count = match b.read_u16(off) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      off = off + 2
      let set_offsets = match read_u16_array(b, off, set_count) {
        None => return None
        Some(v) => v
      }
      if set_index < 0 || set_index >= set_count {
        return None
      }
      let mut offset = set_offsets[set_index].to_int()
      if offset == 0 {
        return Some(false)
      }
      offset = offset + base
      off = offset
      let rule_count = match b.read_u16(off) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      off = off + 2
      let rule_offsets = match read_u16_array(b, off, rule_count) {
        None => return None
        Some(v) => v
      }
      for i in 0..<rule_count {
        let rule_offset = offset + rule_offsets[i].to_int()
        let mut c = rule_offset
        let backtrack_count = match b.read_u16(c) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        c = c + 2
        if backtrack_count != 0 {
          let seq = match read_u16_array(b, c, backtrack_count) {
            None => return None
            Some(v) => v
          }
          c = c + backtrack_count * 2
          let pred = (j, id) => id == seq[j]
          if self.match_backtrack(cur, backtrack_count, pred) is None {
            continue
          }
        }
        let mut input_count = match b.read_u16(c) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        c = c + 2
        let mut input_end = cur
        if input_count > 1 {
          input_count = input_count - 1
          let seq = match read_u16_array(b, c, input_count) {
            None => return None
            Some(v) => v
          }
          c = c + input_count * 2
          match self.match_sequence(cur, input_count, (j, id) => id == seq[j]) {
            None => continue
            Some(end_ix) => input_end = end_ix
          }
        }
        let lookahead_count = match b.read_u16(c) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        c = c + 2
        if lookahead_count != 0 {
          let seq = match read_u16_array(b, c, lookahead_count) {
            None => return None
            Some(v) => v
          }
          c = c + lookahead_count * 2
          let pred = (j, id) => id == seq[j]
          if self.match_sequence(input_end, lookahead_count, pred) is None {
            continue
          }
        }
        let count = match b.read_u16(c) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        c = c + 2
        self.apply_contextual(b, c, count, input_end) |> ignore
        return Some(true)
      }
      None
    }
    @internal.SubtableKind::ChainContext2 => {
      let mut c = base + 4
      let backtrack_classdef_rel = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      let backtrack_classdef = base + backtrack_classdef_rel
      c = c + 2
      let mut input_classdef = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      c = c + 2
      if input_classdef == 0 {
        return Some(false)
      }
      input_classdef = input_classdef + base
      let set_index = self.class(input_classdef, g).to_int()
      let lookahead_classdef_rel = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      let lookahead_classdef = base + lookahead_classdef_rel
      c = c + 2
      let set_count = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      c = c + 2
      let set_offsets = match read_u16_array(b, c, set_count) {
        None => return None
        Some(v) => v
      }
      c = c + set_count * 2
      if set_index < 0 || set_index >= set_count {
        return None
      }
      let mut offset = set_offsets[set_index].to_int()
      if offset == 0 {
        return Some(false)
      }
      offset = offset + base
      let mut off = offset
      let rule_count = match b.read_u16(off) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      off = off + 2
      let rule_offsets = match read_u16_array(b, off, rule_count) {
        None => return None
        Some(v) => v
      }
      for i in 0..<rule_count {
        let rule_offset = offset + rule_offsets[i].to_int()
        let mut d = rule_offset
        let backtrack_count = match b.read_u16(d) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        d = d + 2
        if backtrack_count != 0 {
          let seq = match read_u16_array(b, d, backtrack_count) {
            None => return None
            Some(v) => v
          }
          d = d + backtrack_count * 2
          let pred = (j, id) => self.class(backtrack_classdef, id) == seq[j]
          if self.match_backtrack(cur, backtrack_count, pred) is None {
            continue
          }
        }
        let mut input_count = match b.read_u16(d) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        d = d + 2
        let mut input_end = cur
        if input_count > 1 {
          input_count = input_count - 1
          let seq = match read_u16_array(b, d, input_count) {
            None => return None
            Some(v) => v
          }
          d = d + input_count * 2
          match
            self.match_sequence(cur, input_count, (j, id) => self.class(
                input_classdef, id,
              ) ==
              seq[j]) {
            None => continue
            Some(end_ix) => input_end = end_ix
          }
        }
        let lookahead_count = match b.read_u16(d) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        d = d + 2
        if lookahead_count != 0 {
          let seq = match read_u16_array(b, d, lookahead_count) {
            None => return None
            Some(v) => v
          }
          d = d + lookahead_count * 2
          let pred = (j, id) => self.class(lookahead_classdef, id) == seq[j]
          if self.match_sequence(input_end, lookahead_count, pred) is None {
            continue
          }
        }
        let count = match b.read_u16(d) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        d = d + 2
        self.apply_contextual(b, d, count, input_end) |> ignore
        return Some(true)
      }
      None
    }
    @internal.SubtableKind::ChainContext3 => {
      let mut c = base + 2
      let backtrack_count = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      c = c + 2
      if backtrack_count != 0 {
        if backtrack_count > cur - self.start {
          return None
        }
        let backtrack = match read_u16_array(b, c, backtrack_count) {
          None => return None
          Some(v) => v
        }
        c = c + backtrack_count * 2
        match
          self.match_backtrack(cur, backtrack_count, (j, id) => self.coverage(
              base + backtrack.get(j).unwrap_or((0).to_uint16()).to_int(),
              id,
            )
            is Some(_)) {
          None => return None
          Some(_) => ()
        }
      }
      let input_count = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int() - 1
      }
      c = c + 2
      c = c + 2 // skip coverage for the first glyph
      let mut input_end = cur
      if input_count != 0 {
        let input = match read_u16_array(b, c, input_count) {
          None => return None
          Some(v) => v
        }
        c = c + input_count * 2
        input_end = match
          self.match_sequence(cur, input_count, (j, id) => self.coverage(
              base + input.get(j).unwrap_or((0).to_uint16()).to_int(),
              id,
            )
            is Some(_)) {
          None => return None
          Some(v) => v
        }
      }
      let lookahead_count = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      c = c + 2
      if lookahead_count != 0 {
        if lookahead_count > self.s.end - input_end {
          return None
        }
        let lookahead = match read_u16_array(b, c, lookahead_count) {
          None => return None
          Some(v) => v
        }
        c = c + lookahead_count * 2
        match
          self.match_sequence(input_end, lookahead_count, (j, id) => self.coverage(
              base + lookahead.get(j).unwrap_or((0).to_uint16()).to_int(),
              id,
            )
            is Some(_)) {
          None => return None
          Some(_) => ()
        }
      }
      let count = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      c = c + 2
      self.apply_contextual(b, c, count, input_end) |> ignore
      Some(true)
    }
    @internal.SubtableKind::RevChainContext1 => {
      let mut c = base + 4
      let backtrack_count = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      c = c + 2
      if backtrack_count != 0 {
        if backtrack_count > cur - self.start {
          return None
        }
        let backtrack = match read_u16_array(b, c, backtrack_count) {
          None => return None
          Some(v) => v
        }
        c = c + backtrack_count * 2
        match
          self.match_backtrack(cur, backtrack_count, (j, id) => self.coverage(
              base + backtrack.get(j).unwrap_or((0).to_uint16()).to_int(),
              id,
            )
            is Some(_)) {
          None => return None
          Some(_) => ()
        }
      }
      let lookahead_count = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      c = c + 2
      if lookahead_count != 0 {
        if lookahead_count + cur + 1 > self.s.end {
          return None
        }
        let lookahead = match read_u16_array(b, c, lookahead_count) {
          None => return None
          Some(v) => v
        }
        c = c + lookahead_count * 2
        match
          self.match_sequence(cur, lookahead_count, (j, id) => self.coverage(
              base + lookahead.get(j).unwrap_or((0).to_uint16()).to_int(),
              id,
            )
            is Some(_)) {
          None => return None
          Some(_) => ()
        }
      }
      let count = match b.read_u16(c) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      c = c + 2
      let substs = match read_u16_array(b, c, count) {
        None => return None
        Some(v) => v
      }
      if index < 0 || index >= count {
        return None
      }
      self.buf.substitute(cur, substs[index])
      Some(true)
    }
  }
}

///|
fn ApplyContext::apply_nested(
  self : ApplyContext,
  index : UInt16,
  cur : Int,
  end : Int,
  first : Int,
) -> Bool? {
  if self.top.to_int() == MAX_NESTED_LOOKUPS {
    return None
  }
  let b = @internal.BeBytes::new(self.data)
  let list_rel = match b.read_u16(self.gsubgpos.reinterpret_as_int() + 8) {
    None => return None
    Some(v) => v
  }
  let list_base = self.gsubgpos + list_rel
  let lookup = match
    @internal.lookup_data(
      self.data,
      self.stage,
      list_base,
      index,
      (0).to_byte(),
      Some(self.defs),
    ) {
    None => return None
    Some(v) => v
  }
  self.storage.stack.set(self.top.to_int(), self.s)
  self.top = (self.top.to_int() + 1).to_byte()
  let v = self.apply_uncached(lookup, cur, end + 1, first)
  self.top = (self.top.to_int() - 1).to_byte()
  self.s = self.storage.stack[self.top.to_int()]
  v
}

///|
fn ApplyContext::apply_uncached(
  self : ApplyContext,
  lookup : @internal.LookupData,
  cur : Int,
  end : Int,
  first : Int,
) -> Bool? {
  let b = @internal.BeBytes::new(self.data)
  let base = lookup.offset.reinterpret_as_int()
  self.s.cur = cur
  let buf_len = self.buf.len()
  self.s.end = if end < buf_len { end } else { buf_len }
  let mut applied = false
  let subtables = base + 6
  let count = lookup.count.to_int()
  let ext = lookup.is_ext
  let kind = lookup.kind
  let reverse = lookup.kind is @internal.LookupKind::RevChainContext
  if reverse {
    if !self.move_last() {
      return Some(false)
    }
  } else if !self.move_to(first) {
    return Some(false)
  }
  let cur = self.s.cur
  let g = self.buf.glyphs[cur].id
  for i in 0..<count {
    let subtable_rel = match b.read_u16(subtables + i * 2) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    let mut subtable = base + subtable_rel
    if ext {
      let ext_rel = match b.read_u32(subtable + 4) {
        None => return None
        Some(v) => v.reinterpret_as_int()
      }
      subtable = subtable + ext_rel
    }
    let fmt = match b.read_u16(subtable) {
      None => return None
      Some(v) => v.to_uint16()
    }
    match
      @internal.subtable_data(
        self.data,
        subtable.reinterpret_as_uint(),
        kind,
        fmt,
      ) {
      None => ()
      Some(s) =>
        match s.coverage(self.data, g) {
          None => ()
          Some(ix) =>
            if self.apply_subtable(s, ix.to_int(), cur, g) == Some(true) {
              applied = true
              break
            }
        }
    }
  }
  Some(applied)
}

///|
fn ApplyContext::apply_contextual(
  self : ApplyContext,
  b : @internal.BeBytes,
  offset : Int,
  count : Int,
  end : Int,
) -> Bool? {
  let mut applied = false
  let mut offset = offset
  let start = self.s.cur
  for _ in 0..<count {
    let first = match b.read_u16(offset) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    offset = offset + 2
    let lookup = match b.read_u16(offset) {
      None => return None
      Some(v) => v.to_uint16()
    }
    offset = offset + 2
    if self.apply_nested(lookup, start, end, first) == Some(true) {
      applied = true
    }
  }
  if applied {
    self.s.cur = end
  }
  Some(applied)
}

///|
fn ApplyContext::coverage(
  self : ApplyContext,
  coverage_offset : Int,
  glyph_id : UInt16,
) -> UInt16? {
  @internal.coverage(self.data, coverage_offset.reinterpret_as_uint(), glyph_id)
}

///|
fn ApplyContext::class(
  self : ApplyContext,
  classdef_offset : Int,
  glyph_id : UInt16,
) -> UInt16 {
  @internal.classdef(self.data, classdef_offset.reinterpret_as_uint(), glyph_id)
}

///|
fn ApplyContext::value_record(
  self : ApplyContext,
  parent_offset : Int,
  offset : Int,
  format : UInt16,
  pos : Pos4,
) -> Unit? {
  let b = @internal.BeBytes::new(self.data)
  let mut offset = offset
  let fmt = format.to_int() & 0xFFFF
  if fmt == 4 {
    pos.xadvance = match b.read_i16(offset) {
      None => return None
      Some(v) => v.to_double()
    }
    return Some(())
  }
  if (fmt & 1) != 0 {
    pos.x = match b.read_i16(offset) {
      None => return None
      Some(v) => v.to_double()
    }
    offset = offset + 2
  }
  if (fmt & 2) != 0 {
    pos.y = match b.read_i16(offset) {
      None => return None
      Some(v) => v.to_double()
    }
    offset = offset + 2
  }
  if (fmt & 4) != 0 {
    pos.xadvance = match b.read_i16(offset) {
      None => return None
      Some(v) => v.to_double()
    }
    offset = offset + 2
  }
  if (fmt & 8) != 0 {
    pos.yadvance = match b.read_i16(offset) {
      None => return None
      Some(v) => v.to_double()
    }
    offset = offset + 2
  }
  if (fmt & (0x10 | 0x20 | 0x40 | 0x80)) == 0 {
    return Some(())
  }
  if self.enable_var {
    if (fmt & 0x10) != 0 {
      let delta = match
        self.value_delta(
          parent_offset,
          match b.read_u16(offset) {
            None => return None
            Some(v) => v.to_uint16()
          },
        ) {
        None => return None
        Some(v) => v
      }
      pos.x = pos.x + delta
      offset = offset + 2
    }
    if (fmt & 0x20) != 0 {
      let delta = match
        self.value_delta(
          parent_offset,
          match b.read_u16(offset) {
            None => return None
            Some(v) => v.to_uint16()
          },
        ) {
        None => return None
        Some(v) => v
      }
      pos.y = pos.y + delta
      offset = offset + 2
    }
    if (fmt & 0x40) != 0 {
      let delta = match
        self.value_delta(
          parent_offset,
          match b.read_u16(offset) {
            None => return None
            Some(v) => v.to_uint16()
          },
        ) {
        None => return None
        Some(v) => v
      }
      pos.xadvance = pos.xadvance + delta
      offset = offset + 2
    }
    if (fmt & 0x80) != 0 {
      let delta = match
        self.value_delta(
          parent_offset,
          match b.read_u16(offset) {
            None => return None
            Some(v) => v.to_uint16()
          },
        ) {
        None => return None
        Some(v) => v
      }
      pos.yadvance = pos.yadvance + delta
    }
  }
  Some(())
}

///|
fn ApplyContext::value_delta(
  self : ApplyContext,
  parent_offset : Int,
  offset : UInt16,
) -> Double? {
  if offset == 0 {
    return Some(0.0)
  }
  let b = @internal.BeBytes::new(self.data)
  let offset = parent_offset + offset.to_int()
  let format = match b.read_u16(offset + 4) {
    None => return None
    Some(v) => v.reinterpret_as_int() & 0xFFFF
  }
  if format != 0x8000 {
    return Some(0.0)
  }
  let outer = match b.read_u16(offset) {
    None => return None
    Some(v) => v.to_uint16()
  }
  let inner = match b.read_u16(offset + 2) {
    None => return None
    Some(v) => v.to_uint16()
  }
  Some(self.defs.delta(outer, inner, self.coords))
}

///|
fn ApplyContext::anchor(self : ApplyContext, offset : Int) -> (Double, Double)? {
  let b = @internal.BeBytes::new(self.data)
  let format = match b.read_u16(offset) {
    None => return None
    Some(v) => v.reinterpret_as_int() & 0xFFFF
  }
  let mut x = match b.read_i16(offset + 2) {
    None => return None
    Some(v) => v.to_double()
  }
  let mut y = match b.read_i16(offset + 4) {
    None => return None
    Some(v) => v.to_double()
  }
  if format == 3 && self.defs.has_var_store() && self.coords.length() != 0 {
    let dx = match
      self.value_delta(
        offset,
        match b.read_u16(offset + 6) {
          None => return None
          Some(v) => v.to_uint16()
        },
      ) {
      None => return None
      Some(v) => v
    }
    let dy = match
      self.value_delta(
        offset,
        match b.read_u16(offset + 8) {
          None => return None
          Some(v) => v.to_uint16()
        },
      ) {
      None => return None
      Some(v) => v
    }
    x = x + dx
    y = y + dy
  }
  Some((x, y))
}

///|
fn ApplyContext::mark_anchor(
  self : ApplyContext,
  marks : Int,
  index : UInt16,
) -> (UInt16, (Double, Double))? {
  let b = @internal.BeBytes::new(self.data)
  let count = match b.read_u16(marks) {
    None => return None
    Some(v) => v.to_uint16()
  }
  if index >= count {
    return None
  }
  let rec = marks + 2 + index.to_int() * 4
  let class = match b.read_u16(rec) {
    None => return None
    Some(v) => v.to_uint16()
  }
  let offset = match b.read_u16(rec + 2) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if offset == 0 {
    return None
  }
  let anchor = match self.anchor(marks + offset) {
    None => return None
    Some(v) => v
  }
  Some((class, anchor))
}

///|
fn read_u16_array(
  b : @internal.BeBytes,
  offset : Int,
  count : Int,
) -> Array[UInt16]? {
  if count < 0 {
    return None
  }
  if !b.check_range(offset, count * 2) {
    return None
  }
  let out : Array[UInt16] = []
  for i in 0..<count {
    let v = match b.read_u16(offset + i * 2) {
      None => return None
      Some(v) => v.to_uint16()
    }
    out.push(v)
  }
  Some(out)
}

///|
/// Applies lookups for either substitutions (`stage=0`) or positioning (`stage=1`).
///
/// This is ported from `upstream swash/src/shape/at.rs` (`apply`) and is
/// completed as part of ro7.2.3.
pub fn apply(
  stage : Byte,
  data : Bytes,
  base : UInt,
  coords : ArrayView[Int],
  gdef : @internal.Gdef,
  storage : Storage,
  store : FeatureStore,
  feature_mask : FeatureMask,
  buffer : Buffer,
  buffer_range : IndexRange?,
) -> Bool? {
  if base == 0U || feature_mask.is_empty() {
    return Some(false)
  }
  let range = match buffer_range {
    None => IndexRange::new(0, buffer.len())
    Some(r) => r
  }
  let acx = ApplyContext::new(
    stage, data, base, gdef, coords, store, storage, buffer, range,
  )
  let (lookup_start, lookup_end) = if stage == (0).to_byte() {
    (0, store.pos_start)
  } else {
    (store.pos_start, store.lookups.length())
  }
  let mut applied = false
  for i in lookup_start..<lookup_end {
    let lookup = store.lookups[i]
    if !feature_mask.has(lookup.feature) {
      continue
    }
    let start = lookup.subtables.0.to_int()
    let end = lookup.subtables.1.to_int()
    if start < 0 || end < start || end > store.subtables.length() {
      return None
    }
    if acx.apply(lookup, (start, end), range.start, None, 0) == Some(true) {
      applied = true
    }
  }
  Some(applied)
}

///|
pub fn FeatureStore::default() -> FeatureStore {
  FeatureStore::{
    sub_features: [],
    pos_features: [],
    lookups: [],
    subtables: [],
    coverage: [],
    pos_start: 0,
    sub_count: 0,
    truncated: false,
    groups: FeatureGroups::default(),
  }
}

///|
pub fn FeatureStore::clear(self : FeatureStore) -> Unit {
  self.sub_features.clear()
  self.pos_features.clear()
  self.lookups.clear()
  self.subtables.clear()
  self.coverage.clear()
  self.pos_start = 0
  self.sub_count = 0
  self.truncated = false
  self.groups = FeatureGroups::default()
}

///|
pub fn FeatureStore::sub_bit(
  self : FeatureStore,
  feature : UInt,
) -> FeatureBit? {
  // Binary search by tag.
  let mut l = 0
  let mut h = self.sub_features.length()
  while l < h {
    let mid = (l + h) / 2
    let (t, b) = self.sub_features[mid]
    if feature < t {
      h = mid
    } else if feature > t {
      l = mid + 1
    } else {
      return Some(b)
    }
  }
  None
}

///|
pub fn FeatureStore::pos_bit(
  self : FeatureStore,
  feature : UInt,
) -> FeatureBit? {
  let mut l = 0
  let mut h = self.pos_features.length()
  while l < h {
    let mid = (l + h) / 2
    let (t, b) = self.pos_features[mid]
    if feature < t {
      h = mid
    } else if feature > t {
      l = mid + 1
    } else {
      return Some(b)
    }
  }
  None
}

///|
/// Returns new `basic` and `position` masks based on the specified custom features.
pub fn FeatureStore::custom_masks(
  self : FeatureStore,
  features : ArrayView[@swash.FeatureSetting],
  sub_args : Array[UInt16],
  pos_args : Array[UInt16],
  dir : Direction,
) -> (FeatureMask, FeatureMask) {
  // NOTE: the `args` arrays are owned by `Buffer` in the upstream pipeline.
  sub_args.clear()
  for _ in 0..<self.sub_features.length() {
    sub_args.push((0).to_uint16())
  }
  pos_args.clear()
  for _ in 0..<self.pos_features.length() {
    pos_args.push((0).to_uint16())
  }
  let sub = FeatureStore::custom_masks_for_stage(
    self.sub_features,
    features,
    self.groups.basic,
    sub_args,
  )
  let pos = FeatureStore::custom_masks_for_stage(
    self.pos_features,
    features,
    self.groups.position,
    pos_args,
  )
  if dir == Direction::RightToLeft {
    sub.or_assign(self.groups.rtl)
  }
  (sub, pos)
}

///|
fn FeatureStore::custom_masks_for_stage(
  stage_features : Array[(UInt, FeatureBit)],
  requested_features : ArrayView[@swash.FeatureSetting],
  mask0 : FeatureMask,
  args : Array[UInt16],
) -> FeatureMask {
  let mask = mask0
  for req in requested_features.iter() {
    let tag = req.tag
    // Find bit index.
    let mut l = 0
    let mut h = stage_features.length()
    while l < h {
      let mid = (l + h) / 2
      let (t, b) = stage_features[mid]
      if tag < t {
        h = mid
      } else if tag > t {
        l = mid + 1
      } else {
        let ix = b.to_int()
        let arg = req.value
        args[ix] = arg
        if arg != 0 {
          mask.set(b)
        } else {
          mask.clear(b)
        }
        break
      }
    }
  }
  mask
}

///|
/// Computes feature groups for a script based on available features.
pub fn FeatureStore::groups(
  self : FeatureStore,
  script : @swash.Script,
) -> FeatureGroups {
  let g = FeatureGroups::default()
  feature_masks(self, Some(g.vert), Some(g.position), [VRT2])
  feature_masks(self, Some(g.rtl), Some(g.position), [RTLM])
  if g.vert.is_empty() {
    feature_masks(self, Some(g.vert), Some(g.position), [VERT])
  }
  if script.is_complex() {
    if script is @swash.Script::Myanmar {
      feature_masks(self, Some(g.default), Some(g.position), [
        CALT,
        CCMP,
        LOCL,
        RVRN,
      ])
      g.reph = self.sub_bit(RPHF)
      g.pref = self.sub_bit(PREF)
      feature_masks(self, Some(g.stage1), Some(g.position), [BLWF, PSTF])
      feature_masks(self, Some(g.stage2), Some(g.position), [
        PRES,
        ABVS,
        BLWS,
        PSTS,
      ])
      feature_masks(self, Some(g.basic), Some(g.position), [
        DIST,
        KERN,
        MARK,
        MKMK,
      ])
    } else {
      feature_masks(self, Some(g.default), Some(g.position), [
        AKHN,
        CALT,
        CCMP,
        LOCL,
        NUKT,
        RVRN,
      ])
      g.reph = self.sub_bit(RPHF)
      g.pref = self.sub_bit(PREF)
      feature_masks(self, Some(g.stage1), Some(g.position), [
        ABVF,
        BLWF,
        CJCT,
        HALF,
        PSTF,
        RKRF,
        VATU,
      ])
      if script.is_joined() {
        feature_masks(self, Some(g.stage2), Some(g.position), [
          FIN2,
          FIN3,
          FINA,
          INIT,
          ISOL,
          MED2,
          MEDI,
        ])
      }
      feature_masks(self, Some(g.basic), Some(g.position), [
        ABVS,
        BLWS,
        CALT,
        CLIG,
        HALN,
        LIGA,
        PRES,
        PSTS,
        RCLT,
        RLIG,
      ])
      feature_masks(self, Some(g.basic), Some(g.position), [
        ABVM,
        BLWM,
        CURS,
        DIST,
        KERN,
        MARK,
        MKMK,
      ])
    }
  } else if script is @swash.Script::Hangul {
    feature_masks(self, Some(g.basic), Some(g.position), [
      CCMP,
      LJMO,
      RVRN,
      TJMO,
      VJMO,
    ])
  } else {
    if script.is_joined() {
      feature_masks(self, Some(g.basic), Some(g.position), [
        CALT,
        CCMP,
        CLIG,
        FIN2,
        FIN3,
        FINA,
        INIT,
        ISOL,
        LIGA,
        LOCL,
        MED2,
        MEDI,
        MSET,
        RLIG,
        RVRN,
      ])
    } else {
      feature_masks(self, Some(g.basic), Some(g.position), [
        CALT,
        CCMP,
        CLIG,
        LIGA,
        LOCL,
        RVRN,
      ])
    }
    feature_masks(self, Some(g.basic), Some(g.position), [
      CURS,
      DIST,
      KERN,
      MARK,
      MKMK,
    ])
  }
  g
}

///|
fn FeatureStore::covers(
  self : FeatureStore,
  key : UInt,
  glyph_id : UInt16,
) -> Bool {
  if key == 0xFFFFFFFFU {
    return true
  }
  let cache = self.coverage
  let base = key.reinterpret_as_int()
  if base < 0 || base + 1 >= cache.length() {
    return false
  }
  let first = cache[base]
  let last = cache[base + 1]
  if glyph_id >= first && glyph_id <= last {
    let bit = (glyph_id - first).to_int()
    let idx = base + 2 + bit / 16
    if idx < 0 || idx >= cache.length() {
      return false
    }
    (cache[idx] & ((1).to_uint16() << (bit & 15))) != 0
  } else {
    false
  }
}

///|
fn feature_masks(
  store : FeatureStore,
  sub_mask : FeatureMask?,
  pos_mask : FeatureMask?,
  features : ArrayView[UInt],
) -> Unit {
  match sub_mask {
    None => ()
    Some(m) =>
      for feature in features.iter() {
        match store.sub_bit(feature) {
          None => ()
          Some(bit) => m.set(bit)
        }
      }
  }
  match pos_mask {
    None => ()
    Some(m) =>
      for feature in features.iter() {
        match store.pos_bit(feature) {
          None => ()
          Some(bit) => m.set(bit)
        }
      }
  }
}
