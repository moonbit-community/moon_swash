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
/// Shaping engine that handles the various methods available in an OpenType font.
///
/// Ported from `swash-reference/src/shape/engine.rs`.

///|
pub(all) enum EngineMode {
  Simple
  Myanmar
  Complex
}

///|
pub impl Eq for EngineMode with equal(self, other) {
  match self {
    EngineMode::Simple => other is EngineMode::Simple
    EngineMode::Myanmar => other is EngineMode::Myanmar
    EngineMode::Complex => other is EngineMode::Complex
  }
}

///|
pub(all) enum SubMode {
  None
  Gsub
  Morx
}

///|
pub impl Eq for SubMode with equal(self, other) {
  match self {
    SubMode::None => other is SubMode::None
    SubMode::Gsub => other is SubMode::Gsub
    SubMode::Morx => other is SubMode::Morx
  }
}

///|
pub(all) enum PosMode {
  None
  Gpos
  Kerx
  Kern
}

///|
pub impl Eq for PosMode with equal(self, other) {
  match self {
    PosMode::None => other is PosMode::None
    PosMode::Gpos => other is PosMode::Gpos
    PosMode::Kerx => other is PosMode::Kerx
    PosMode::Kern => other is PosMode::Kern
  }
}

///|
/// Metadata for creating a shaping engine.
pub struct EngineMetadata {
  gdef : UInt
  gsub : UInt
  gpos : UInt
  morx : UInt
  kerx : UInt
  ankr : UInt
  kern : UInt
  sub_mode : SubMode
  pos_mode : PosMode
}

///|
pub fn EngineMetadata::from_font(font : @swash.FontRef) -> EngineMetadata {
  let gdef = font.table_offset(0x47444546) // "GDEF"
  let gsub = font.table_offset(0x47535542) // "GSUB"
  let gpos = font.table_offset(0x47504F53) // "GPOS"
  let morx = font.table_offset(0x6D6F7278) // "morx"
  let kerx = font.table_offset(0x6B657278) // "kerx"
  let ankr = font.table_offset(0x616E6B72) // "ankr"
  let kern = font.table_offset(0x6B65726E) // "kern"
  let mut sub_mode = SubMode::None
  if gsub != 0U {
    sub_mode = SubMode::Gsub
  } else if morx != 0U {
    sub_mode = SubMode::Morx
  }
  let mut pos_mode = PosMode::None
  if gpos != 0U {
    pos_mode = PosMode::Gpos
  } else if kerx != 0U {
    pos_mode = PosMode::Kerx
  } else if kern != 0U {
    pos_mode = PosMode::Kern
  }
  EngineMetadata::{
    gdef,
    gsub,
    gpos,
    morx,
    kerx,
    ankr,
    kern,
    sub_mode,
    pos_mode,
  }
}

///|
pub struct Engine {
  data : Bytes
  gdef : @internal.Gdef
  gsub : StageOffsets
  gpos : StageOffsets
  morx : UInt
  kerx : UInt
  ankr : UInt
  kern : UInt
  storage : Storage
  coords : ArrayView[Int]
  script : @swash.Script
  tags : (UInt, UInt, UInt, UInt)
  sub_mode : SubMode
  pos_mode : PosMode
  use_ot : Bool
  mode : EngineMode
}

///|
pub fn Engine::new(
  metadata : EngineMetadata,
  font_data : Bytes,
  coords : ArrayView[Int],
  script : @swash.Script,
  language : @swash.Language?,
) -> Engine {
  let gdef = match @internal.Gdef::from_offset(font_data, metadata.gdef) {
    None => @internal.Gdef::empty()
    Some(g) => g
  }
  let script_tag = script.to_opentype()
  let lang_tag : UInt? = match language {
    None => None
    Some(l) => l.to_opentype()
  }
  let (gsub, stags) = if metadata.sub_mode == SubMode::Gsub {
    match StageOffsets::new(font_data, metadata.gsub, script_tag, lang_tag) {
      None => (StageOffsets::default(), (0U, 0U))
      Some((off, tags)) => (off, tags)
    }
  } else {
    (StageOffsets::default(), (0U, 0U))
  }
  let (gpos, ptags) = if metadata.pos_mode == PosMode::Gpos {
    match StageOffsets::new(font_data, metadata.gpos, script_tag, lang_tag) {
      None => (StageOffsets::default(), (0U, 0U))
      Some((off, tags)) => (off, tags)
    }
  } else {
    (StageOffsets::default(), (0U, 0U))
  }
  let tags : (UInt, UInt, UInt, UInt) = (stags.0, stags.1, ptags.0, ptags.1)
  let use_ot = gsub.lang != 0U || gpos.lang != 0U
  let mode = if gsub.lang != 0U && script.is_complex() {
    if script is @swash.Script::Myanmar {
      EngineMode::Myanmar
    } else {
      EngineMode::Complex
    }
  } else {
    EngineMode::Simple
  }
  let sub_mode = if metadata.sub_mode == SubMode::Gsub && gsub.lang == 0U {
    SubMode::None
  } else {
    metadata.sub_mode
  }
  let pos_mode = if metadata.pos_mode == PosMode::Gpos && gpos.lang == 0U {
    PosMode::None
  } else {
    metadata.pos_mode
  }
  Engine::{
    data: font_data,
    gdef,
    gsub,
    gpos,
    morx: metadata.morx,
    kerx: metadata.kerx,
    ankr: metadata.ankr,
    kern: metadata.kern,
    storage: Storage::default(),
    coords,
    script,
    tags,
    sub_mode,
    pos_mode,
    use_ot,
    mode,
  }
}

///|
/// OpenType shaping.
pub fn Engine::tags(self : Engine) -> (UInt, UInt, UInt, UInt) {
  self.tags
}

///|
/// Builds a feature store for the current engine configuration.
pub fn Engine::collect_features(
  self : Engine,
  builder : FeatureStoreBuilder,
  store : Ref[FeatureStore],
) -> Unit {
  builder.build(store, self.data, self.coords, self.gdef, self.gsub, self.gpos)
  store.val.groups = store.val.groups(self.script)
}

///|
/// Returns true if feature variations are supported.
pub fn Engine::has_feature_vars(self : Engine) -> Bool {
  self.gsub.vars != 0U || self.gpos.vars != 0U
}

///|
/// Sets glyph and mark classes for the specified range of the buffer.
pub fn Engine::set_classes(
  self : Engine,
  buffer : Buffer,
  range : IndexRange?,
) -> Unit {
  if !self.gdef.ok() {
    return
  }
  let (start, end) = match range {
    None => (0, buffer.glyphs.length())
    Some(r) => (r.start, r.end)
  }
  if self.gdef.has_mark_classes() {
    for i in start..<end {
      let g = buffer.glyphs[i]
      g.class = self.gdef.class(g.id).to_byte()
      g.mark_type = self.gdef.mark_class(g.id).to_byte()
      buffer.glyphs.set(i, g)
    }
  } else {
    for i in start..<end {
      let g = buffer.glyphs[i]
      g.class = self.gdef.class(g.id).to_byte()
      buffer.glyphs.set(i, g)
    }
  }
}

///|
/// Applies the GSUB features to the specified range of the buffer.
pub fn Engine::gsub(
  self : Engine,
  store : FeatureStore,
  feature_mask : FeatureMask,
  buffer : Buffer,
  buffer_range : IndexRange?,
) -> Bool {
  apply(
    (0).to_byte(),
    self.data,
    self.gsub.base,
    self.coords,
    self.gdef,
    self.storage,
    store,
    feature_mask,
    buffer,
    buffer_range,
  ) ==
  Some(true)
}

///|
/// Applies the GPOS features to the specified range of the buffer.
pub fn Engine::gpos(
  self : Engine,
  store : FeatureStore,
  feature_mask : FeatureMask,
  buffer : Buffer,
  buffer_range : IndexRange?,
) -> Bool {
  apply(
    (1).to_byte(),
    self.data,
    self.gpos.base,
    self.coords,
    self.gdef,
    self.storage,
    store,
    feature_mask,
    buffer,
    buffer_range,
  ) ==
  Some(true)
}
