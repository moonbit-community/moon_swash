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
/// Shaper that partitions by font using trait based per-cluster selection.
///
/// Ported from `swash-reference/src/shape/partition.rs`.

///|
/// Font selected for a cluster.
///
/// Note: upstream uses a trait with an associated type returned by the selector.
/// MoonBit traits do not support associated types, so we use a concrete carrier
/// struct for the selected font.
pub struct SelectedFont {
  font : @swash.FontRef
  id_override : (UInt64, UInt64)?
  synthesis : @swash.Synthesis?
}

///|
/// Creates a selected font wrapper.
pub fn SelectedFont::new(font : @swash.FontRef) -> SelectedFont {
  SelectedFont::{ font, id_override: None, synthesis: None }
}

///|
/// Returns a copy with an explicit cache id override.
pub fn SelectedFont::with_id_override(
  self : SelectedFont,
  id : (UInt64, UInt64),
) -> SelectedFont {
  SelectedFont::{
    font: self.font,
    id_override: Some(id),
    synthesis: self.synthesis,
  }
}

///|
/// Returns a copy with a synthesis state attached.
pub fn SelectedFont::with_synthesis(
  self : SelectedFont,
  syn : @swash.Synthesis,
) -> SelectedFont {
  SelectedFont::{
    font: self.font,
    id_override: self.id_override,
    synthesis: Some(syn),
  }
}

///|
/// Returns the underlying font.
pub fn SelectedFont::font(self : SelectedFont) -> @swash.FontRef {
  self.font
}

///|
/// Returns an optional override for cache identifier `(id0, id1)`.
pub fn SelectedFont::id_override(self : SelectedFont) -> (UInt64, UInt64)? {
  self.id_override
}

///|
/// Returns an optional synthesis state for the font.
pub fn SelectedFont::synthesis(self : SelectedFont) -> @swash.Synthesis? {
  self.synthesis
}

///|
/// Trait for types that can select appropriate fonts for character clusters.
pub(open) trait Selector {
  /// Selects a font for the specified character cluster.
  select_font(Self, cluster : CharCluster) -> SelectedFont?
}

///|
/// Trait for types that specify shaping options.
pub(open) trait ShapeOptions {
  script(Self) -> @swash.Script
  language(Self) -> @swash.Language?
  direction(Self) -> Direction
  size(Self) -> Double
  features(Self) -> Iter[@swash.FeatureSetting]
  variations(Self) -> Iter[@swash.VariationSetting]
  insert_dotted_circles(Self) -> Bool
}

///|
/// Simple implementation of the shape options trait.
pub struct SimpleShapeOptions {
  script : @swash.Script
  language : @swash.Language?
  direction : Direction
  size : Double
  features : Array[@swash.FeatureSetting]
  variations : Array[@swash.VariationSetting]
  insert_dotted_circles : Bool
}

///|
pub fn SimpleShapeOptions::default() -> SimpleShapeOptions {
  SimpleShapeOptions::{
    script: @swash.Script::Latin,
    language: None,
    direction: Direction::LeftToRight,
    size: 0.0,
    features: [],
    variations: [],
    insert_dotted_circles: false,
  }
}

///|
pub impl ShapeOptions for SimpleShapeOptions with script(self) {
  self.script
}

///|
pub impl ShapeOptions for SimpleShapeOptions with language(self) {
  self.language
}

///|
pub impl ShapeOptions for SimpleShapeOptions with direction(self) {
  self.direction
}

///|
pub impl ShapeOptions for SimpleShapeOptions with size(self) {
  self.size
}

///|
pub impl ShapeOptions for SimpleShapeOptions with features(self) {
  self.features.iter()
}

///|
pub impl ShapeOptions for SimpleShapeOptions with variations(self) {
  self.variations.iter()
}

///|
pub impl ShapeOptions for SimpleShapeOptions with insert_dotted_circles(self) {
  self.insert_dotted_circles
}

///|
fn selected_font_id(font : SelectedFont) -> (UInt64, UInt64) {
  match font.id_override() {
    Some(id) => id
    None => (font.font().key().value(), (-1).to_int64().reinterpret_as_uint64())
  }
}

///|
/// Shapes a run of text (provided as a `Token` iterator) using the specified
/// selector to assign per-cluster fonts.
pub fn[S : Selector, O : ShapeOptions] shape(
  context : ShapeContext,
  selector : S,
  options : O,
  tokens : Iter[@swash.Token],
  f : (SelectedFont, Shaper) -> Unit,
) -> Unit {
  let mut cluster = CharCluster::new()
  let parser0 = if options.direction() == Direction::RightToLeft {
    // Mirror characters for RTL text.
    @swash.Parser::new(
      options.script(),
      tokens.map((t : @swash.Token) => {
        let ch0 = t.ch()
        let ch = match @swash.Codepoint::mirror(ch0) {
          None => ch0
          Some(m) => m
        }
        @swash.Token::new(ch, t.offset(), t.len(), t.info(), t.data())
      }),
    )
  } else {
    @swash.Parser::new(options.script(), tokens)
  }
  if !parser0.next(cluster) {
    return
  }
  let mut current_font = selector.select_font(cluster)
  let mut parser1 = parser0
  while true {
    let (cont, parser2, cluster2, next_font) = shape_clusters(
      context, selector, options, parser1, cluster, current_font, f,
    )
    parser1 = parser2
    cluster = cluster2
    current_font = next_font
    if !cont {
      break
    }
  }
}

///|
fn[S : Selector, O : ShapeOptions] shape_clusters(
  context : ShapeContext,
  selector : S,
  options : O,
  parser : @swash.Parser,
  cluster : CharCluster,
  current_font : SelectedFont?,
  f : (SelectedFont, Shaper) -> Unit,
) -> (Bool, @swash.Parser, CharCluster, SelectedFont?) {
  match current_font {
    None => (false, parser, cluster, None)
    Some(font) => {
      let (id0, id1) = selected_font_id(font)
      let mut builder = context
        .builder_with_id(font.font(), (id0, id1))
        .script(options.script())
        .language(options.language())
        .direction(options.direction())
        .size(options.size())
        .features(options.features())
      match font.synthesis() {
        None => ()
        Some(syn) => builder = builder.variations(syn.variations().iter())
      }
      builder = builder
        .variations(options.variations())
        .insert_dotted_circles(options.insert_dotted_circles())
      let shaper = builder.build()
      while true {
        shaper.add_cluster(cluster)
        if !parser.next(cluster) {
          f(font, shaper)
          return (false, parser, cluster, None)
        }
        match selector.select_font(cluster) {
          None => return (false, parser, cluster, None)
          Some(next_font) => {
            let (nid0, nid1) = selected_font_id(next_font)
            if nid0 != id0 || nid1 != id1 {
              f(font, shaper)
              return (true, parser, cluster, Some(next_font))
            }
          }
        }
      } else {
        // Unreachable, but required because `while` is an expression.
        (false, parser, cluster, None)
      }
    }
  }
}
