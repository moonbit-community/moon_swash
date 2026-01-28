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
struct State {
  buffer : Buffer
}

///|
fn State::new() -> State {
  State::{ buffer: Buffer::new() }
}

///|
fn State::reset(self : State) -> Unit {
  self.buffer.clear()
}

///|
/// Context that manages transient buffers for shaping.
///
/// This is intentionally minimal for ro7.1: caches and engines are introduced
/// in later shaping tasks.
pub struct ShapeContext {
  state : Ref[State]
}

///|
/// Creates a new shaping context.
pub fn ShapeContext::new() -> ShapeContext {
  ShapeContext::{ state: Ref::new(State::new()) }
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
  self.state.val.reset()
  ShaperBuilder::{
    state: self.state,
    font,
    id0: id.0,
    id1: id.1,
    size: 0.0,
    script: @swash.Script::Latin,
    language: None,
    direction: Direction::LeftToRight,
    dotted_circle: None,
    retain_ignorables: false,
    features: [],
    variations: [],
  }
}

///|
/// Builder for configuring a shaper.
pub struct ShaperBuilder {
  state : Ref[State]
  font : @swash.FontRef
  id0 : UInt64
  id1 : UInt64
  size : Double
  script : @swash.Script
  language : @swash.Language?
  direction : Direction
  dotted_circle : GlyphId?
  retain_ignorables : Bool
  features : Array[@swash.FeatureSetting]
  variations : Array[@swash.VariationSetting]
}

///|
/// Specifies the script. The default value is `Script::Latin`.
pub fn ShaperBuilder::script(
  self : ShaperBuilder,
  script : @swash.Script,
) -> ShaperBuilder {
  ShaperBuilder::{
    state: self.state,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script,
    language: self.language,
    direction: self.direction,
    dotted_circle: self.dotted_circle,
    retain_ignorables: self.retain_ignorables,
    features: self.features,
    variations: self.variations,
  }
}

///|
/// Specifies the language. The default value is `None`.
pub fn ShaperBuilder::language(
  self : ShaperBuilder,
  language : @swash.Language?,
) -> ShaperBuilder {
  ShaperBuilder::{
    state: self.state,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language,
    direction: self.direction,
    dotted_circle: self.dotted_circle,
    retain_ignorables: self.retain_ignorables,
    features: self.features,
    variations: self.variations,
  }
}

///|
/// Specifies the text direction. The default value is `Direction::LeftToRight`.
pub fn ShaperBuilder::direction(
  self : ShaperBuilder,
  direction : Direction,
) -> ShaperBuilder {
  ShaperBuilder::{
    state: self.state,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language: self.language,
    direction,
    dotted_circle: self.dotted_circle,
    retain_ignorables: self.retain_ignorables,
    features: self.features,
    variations: self.variations,
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
    state: self.state,
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
    dotted_circle: self.dotted_circle,
    retain_ignorables: self.retain_ignorables,
    features: self.features,
    variations: self.variations,
  }
}

///|
/// Adds feature settings to the shaper.
pub fn ShaperBuilder::features(
  self : ShaperBuilder,
  settings : Iter[@swash.FeatureSetting],
) -> ShaperBuilder {
  for s in settings {
    self.features.push(s)
  }
  self
}

///|
/// Adds variation settings to the shaper.
pub fn ShaperBuilder::variations(
  self : ShaperBuilder,
  settings : Iter[@swash.VariationSetting],
) -> ShaperBuilder {
  for s in settings {
    self.variations.push(s)
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
    let cm = @swash.Charmap::from_font(self.font)
    let gid = cm.map(0x25CC)
    if gid != 0 {
      Some(gid)
    } else {
      None
    }
  } else {
    None
  }
  ShaperBuilder::{
    state: self.state,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language: self.language,
    direction: self.direction,
    dotted_circle,
    retain_ignorables: self.retain_ignorables,
    features: self.features,
    variations: self.variations,
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
    state: self.state,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language: self.language,
    direction: self.direction,
    dotted_circle: self.dotted_circle,
    retain_ignorables: yes,
    features: self.features,
    variations: self.variations,
  }
}

///|
/// Builds a shaper for the current configuration.
pub fn ShaperBuilder::build(self : ShaperBuilder) -> Shaper {
  self.state.val.reset()
  self.state.val.buffer.dotted_circle = self.dotted_circle
  self.state.val.buffer.is_rtl = self.direction == Direction::RightToLeft
  Shaper::{
    state: self.state,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language: self.language,
    direction: self.direction,
    retain_ignorables: self.retain_ignorables,
    features: self.features,
    variations: self.variations,
  }
}

///|
/// Maps character clusters to (eventually) positioned glyph clusters.
///
/// In ro7.1 this shaper only collects clusters into the underlying `Buffer`.
pub struct Shaper {
  state : Ref[State]
  font : @swash.FontRef
  id0 : UInt64
  id1 : UInt64
  size : Double
  script : @swash.Script
  language : @swash.Language?
  direction : Direction
  retain_ignorables : Bool
  features : Array[@swash.FeatureSetting]
  variations : Array[@swash.VariationSetting]
}

///|
/// Adds a character cluster to the shaper.
pub fn Shaper::add_cluster(self : Shaper, cluster : CharCluster) -> Unit {
  // The cluster must have been mapped to nominal glyph ids by the caller
  // (e.g. a font fallback selector).
  self.state.val.buffer.push(cluster) |> ignore
}
