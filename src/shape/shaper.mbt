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
/// Shaper context and builder scaffolding.
///
/// Port intent: align with upstream `swash-reference/src/shape/mod.rs` for
/// `Direction`, `ShapeContext`, `ShaperBuilder`, and `Shaper`.
///
/// Note: the actual shaping engines (OT/AT/AAT) are implemented in later
/// tasks; for now, `Shaper::add_cluster` only pushes mapped clusters into the
/// underlying `Buffer`.

///|
/// Text direction.
pub(all) enum Direction {
  LeftToRight
  RightToLeft
}

///|
pub impl Eq for Direction with equal(self, other) {
  match self {
    Direction::LeftToRight => other is Direction::LeftToRight
    Direction::RightToLeft => other is Direction::RightToLeft
  }
}

///|
const DEFAULT_SIZE : Int = 16

///|
struct State {
  buffer : Buffer
  order : Array[Int]
  glyphs : Array[GlyphData]
  store_builder : FeatureStoreBuilder
  mut disable_kern : Bool
  features : Array[@swash.FeatureSetting]
  selectors : Array[(UInt16, UInt16)]
}

///|
fn State::new() -> State {
  State::{
    buffer: Buffer::new(),
    order: [],
    glyphs: [],
    store_builder: FeatureStoreBuilder::default(),
    disable_kern: false,
    features: [],
    selectors: [],
  }
}

///|
fn State::reset(self : State) -> Unit {
  self.buffer.clear()
  self.disable_kern = false
  self.features.clear()
  self.selectors.clear()
}

///|
struct ContextState {
  font_cache : @swash.FontCache[FontEntry]
  feature_cache : FeatureCache
  coords : Array[Int]
  state : State
}

///|
fn ContextState::new(max_entries : Int) -> ContextState {
  ContextState::{
    font_cache: @swash.FontCache::new(max_entries),
    feature_cache: FeatureCache::new(max_entries),
    coords: [],
    state: State::new(),
  }
}

///|
/// Context that manages transient buffers for shaping.
///
/// This is intentionally minimal for ro7.1: caches and engines are introduced
/// in later shaping tasks.
pub struct ShapeContext {
  inner : Ref[ContextState]
}

///|
/// Creates a new shaping context.
pub fn ShapeContext::new() -> ShapeContext {
  ShapeContext::with_max_entries(DEFAULT_SIZE)
}

///|
/// Creates a new shaping context with the specified maximum number of cache entries.
pub fn ShapeContext::with_max_entries(max_entries : Int) -> ShapeContext {
  let mut max_entries0 = max_entries
  if max_entries0 < 1 {
    max_entries0 = 1
  } else if max_entries0 > 64 {
    max_entries0 = 64
  }
  ShapeContext::{ inner: Ref::new(ContextState::new(max_entries0)) }
}

///|
/// Creates a new builder for constructing a shaper with this context.
pub fn ShapeContext::builder(
  self : ShapeContext,
  font : @swash.FontRef,
) -> ShaperBuilder {
  let id0 = font.key().value()
  let id1 = (-1).to_int64().reinterpret_as_uint64()
  ShapeContext::builder_with_id(self, font, (id0, id1))
}

///|
/// Creates a new builder for constructing a shaper with this context.
pub fn ShapeContext::builder_with_id(
  self : ShapeContext,
  font : @swash.FontRef,
  id : (UInt64, UInt64),
) -> ShaperBuilder {
  let (font_id, font_entry) = self.inner.val.font_cache.get(
    font,
    Some(id),
    FontEntry::new,
  )
  self.inner.val.state.reset()
  self.inner.val.coords.clear()
  ShaperBuilder::{
    cx: self.inner,
    font,
    id0: font_id.0,
    id1: font_id.1,
    size: 0.0,
    script: @swash.Script::Latin,
    language: None,
    direction: Direction::LeftToRight,
    charmap: font_entry.val.charmap.materialize(font),
    dotted_circle: None,
    retain_ignorables: false,
    font_entry,
  }
}

///|
/// Builder for configuring a shaper.
pub struct ShaperBuilder {
  cx : Ref[ContextState]
  font : @swash.FontRef
  id0 : UInt64
  id1 : UInt64
  size : Double
  script : @swash.Script
  language : @swash.Language?
  direction : Direction
  font_entry : Ref[FontEntry]
  charmap : @swash.Charmap
  dotted_circle : GlyphId?
  retain_ignorables : Bool
}

///|
/// Specifies the script. The default value is `Script::Latin`.
pub fn ShaperBuilder::script(
  self : ShaperBuilder,
  script : @swash.Script,
) -> ShaperBuilder {
  ShaperBuilder::{
    cx: self.cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script,
    language: self.language,
    direction: self.direction,
    font_entry: self.font_entry,
    charmap: self.charmap,
    dotted_circle: self.dotted_circle,
    retain_ignorables: self.retain_ignorables,
  }
}

///|
/// Specifies the language. The default value is `None`.
pub fn ShaperBuilder::language(
  self : ShaperBuilder,
  language : @swash.Language?,
) -> ShaperBuilder {
  ShaperBuilder::{
    cx: self.cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language,
    direction: self.direction,
    font_entry: self.font_entry,
    charmap: self.charmap,
    dotted_circle: self.dotted_circle,
    retain_ignorables: self.retain_ignorables,
  }
}

///|
/// Specifies the text direction. The default value is `Direction::LeftToRight`.
pub fn ShaperBuilder::direction(
  self : ShaperBuilder,
  direction : Direction,
) -> ShaperBuilder {
  ShaperBuilder::{
    cx: self.cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language: self.language,
    direction,
    font_entry: self.font_entry,
    charmap: self.charmap,
    dotted_circle: self.dotted_circle,
    retain_ignorables: self.retain_ignorables,
  }
}

///|
/// Specifies the font size in pixels per em. The default value is `0` which
/// will produce glyphs with offsets and advances in font units.
pub fn ShaperBuilder::size(
  self : ShaperBuilder,
  ppem : Double,
) -> ShaperBuilder {
  ShaperBuilder::{
    cx: self.cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: if ppem < 0.0 {
      0.0
    } else {
      ppem
    },
    script: self.script,
    language: self.language,
    direction: self.direction,
    font_entry: self.font_entry,
    charmap: self.charmap,
    dotted_circle: self.dotted_circle,
    retain_ignorables: self.retain_ignorables,
  }
}

///|
/// Adds feature settings to the shaper.
pub fn ShaperBuilder::features(
  self : ShaperBuilder,
  settings : Iter[@swash.FeatureSetting],
) -> ShaperBuilder {
  for s in settings {
    if s.tag == KERN {
      self.cx.val.state.disable_kern = s.value == 0
    }
    self.cx.val.state.features.push(s)
  }
  self
}

///|
/// Adds variation settings to the shaper.
pub fn ShaperBuilder::variations(
  self : ShaperBuilder,
  settings : Iter[@swash.VariationSetting],
) -> ShaperBuilder {
  if self.font_entry.val.coord_count != 0 {
    let vars = self.font.variations().to_array()
    self.cx.val.coords.resize(vars.length(), 0)
    for setting in settings {
      for axis in vars.iter() {
        if axis.tag() == setting.tag {
          let value = axis.normalize(setting.value)
          let ix = axis.index()
          if ix >= 0 && ix < self.cx.val.coords.length() {
            self.cx.val.coords[ix] = value
          }
        }
      }
    }
  }
  self
}

///|
/// Specifies whether to insert dotted circles for broken clusters. The default
/// value is `false`.
pub fn ShaperBuilder::insert_dotted_circles(
  self : ShaperBuilder,
  yes : Bool,
) -> ShaperBuilder {
  let dotted_circle = if yes {
    let gid = self.charmap.map(0x25CC)
    if gid != 0 {
      Some(gid)
    } else {
      None
    }
  } else {
    None
  }
  ShaperBuilder::{
    cx: self.cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language: self.language,
    direction: self.direction,
    font_entry: self.font_entry,
    charmap: self.charmap,
    dotted_circle,
    retain_ignorables: self.retain_ignorables,
  }
}

///|
/// Specifies whether characters defined as default ignorable should be retained
/// by the shaper. The default is `false`.
pub fn ShaperBuilder::retain_ignorables(
  self : ShaperBuilder,
  yes : Bool,
) -> ShaperBuilder {
  ShaperBuilder::{
    cx: self.cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language: self.language,
    direction: self.direction,
    font_entry: self.font_entry,
    charmap: self.charmap,
    dotted_circle: self.dotted_circle,
    retain_ignorables: yes,
  }
}

///|
/// Builds a shaper for the current configuration.
pub fn ShaperBuilder::build(self : ShaperBuilder) -> Shaper {
  let cx = self.cx
  cx.val.state.buffer.dotted_circle = self.dotted_circle
  cx.val.state.buffer.is_rtl = self.direction == Direction::RightToLeft
  let engine = Engine::new(
    self.font_entry.val.metadata,
    self.font.data(),
    cx.val.coords.op_as_view(),
    self.script,
    self.language,
  )
  let (store, sub_mask, pos_mask) = if engine.use_ot {
    let entry = cx.val.feature_cache.entry(
      (self.id0, self.id1),
      cx.val.coords.op_as_view(),
      engine.has_feature_vars(),
      engine.tags(),
    )
    let store_ref = match entry {
      FeatureCacheEntry::Present(s) => s
      FeatureCacheEntry::New(s) => {
        engine.collect_features(cx.val.state.store_builder, s)
        s
      }
    }
    let buf = cx.val.state.buffer
    let (sub, pos) = store_ref.val.custom_masks(
      cx.val.state.features.op_as_view(),
      buf.sub_args,
      buf.pos_args,
      self.direction,
    )
    (Some(store_ref), sub, pos)
  } else {
    (None, FeatureMask::default(), FeatureMask::default())
  }
  Shaper::{
    cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    font_entry: self.font_entry,
    charmap: self.charmap,
    size: self.size,
    script: self.script,
    language: self.language,
    direction: self.direction,
    retain_ignorables: self.retain_ignorables,
    engine,
    store,
    sub_mask,
    pos_mask,
  }
}

///|
/// Maps character clusters to (eventually) positioned glyph clusters.
///
/// In ro7.1 this shaper only collects clusters into the underlying `Buffer`.
pub struct Shaper {
  cx : Ref[ContextState]
  font : @swash.FontRef
  id0 : UInt64
  id1 : UInt64
  font_entry : Ref[FontEntry]
  charmap : @swash.Charmap
  size : Double
  script : @swash.Script
  language : @swash.Language?
  direction : Direction
  retain_ignorables : Bool
  engine : Engine
  store : Ref[FeatureStore]?
  sub_mask : FeatureMask
  pos_mask : FeatureMask
}

///|
/// Adds a character cluster to the shaper.
pub fn Shaper::add_cluster(self : Shaper, cluster : CharCluster) -> Unit {
  // The cluster must have been mapped to nominal glyph ids by the caller
  // (e.g. a font fallback selector).
  self.cx.val.state.buffer.push(cluster) |> ignore
}
