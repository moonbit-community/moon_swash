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
/// Ported from `swash-reference/src/shape/at.rs`.
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
/// Builder for a feature cache.
pub struct FeatureStoreBuilder {
  indices : Array[(UInt16, FeatureBit, Byte)]
  mut next_bit : FeatureBit
}

///|
pub fn FeatureStoreBuilder::default() -> FeatureStoreBuilder {
  FeatureStoreBuilder::{ indices: [], next_bit: 0 }
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
        let lookup = lookup0
        let (sub0, sub1) = FeatureStoreBuilder::collect_subtables(
          self, store, data, lookup,
        )
        if sub1 > sub0 {
          lookup.set_subtables(sub0, sub1)
          lookup.set_feature(feature)
          // Coverage key is left as the default "always true" sentinel for now.
          store.val.lookups.push(lookup)
          last_index = Some(index)
        } else {
          store.val.subtables.truncate(start)
        }
      }
    }
  }
}

///|
fn FeatureStoreBuilder::collect_subtables(
  _self : FeatureStoreBuilder,
  store : Ref[FeatureStore],
  data : Bytes,
  lookup : @internal.LookupData,
) -> (UInt16, UInt16) {
  let start = store.val.subtables.length()
  let count = lookup.count.to_int()
  for i in 0..<count {
    match lookup.subtable_data(data, i.to_uint16()) {
      None => ()
      Some(s) => store.val.subtables.push(s)
    }
  }
  let end = store.val.subtables.length()
  (start.to_uint16(), end.to_uint16())
}

///|
/// Scratch storage used by the OT lookup application engine.
pub struct Storage {}

///|
pub fn Storage::default() -> Storage {
  Storage::{  }
}

///|
/// Applies lookups for either substitutions (`stage=0`) or positioning (`stage=1`).
///
/// This is ported from `swash-reference/src/shape/at.rs` (`apply`) and is
/// completed as part of ro7.2.3.
pub fn apply(
  _stage : Byte,
  _data : Bytes,
  _base : UInt,
  _coords : ArrayView[Int],
  _gdef : @internal.Gdef,
  _storage : Storage,
  _store : FeatureStore,
  _feature_mask : FeatureMask,
  _buffer : Buffer,
  _buffer_range : IndexRange?,
) -> Bool? {
  None
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
