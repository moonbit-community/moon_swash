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
/// Glyph cluster modeling-- output from the shaper.
///
/// Ported from `swash/src/shape/cluster.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
/// Information for a glyph.
pub struct GlyphInfo {
  bits : UInt16
}

///|
pub fn GlyphInfo::default() -> GlyphInfo {
  GlyphInfo::{ bits: 0 }
}

///|
pub fn GlyphInfo::new(bits : UInt16) -> GlyphInfo {
  GlyphInfo::{ bits, }
}

///|
/// Returns true if the glyph is an attached mark.
pub fn GlyphInfo::is_mark(self : GlyphInfo) -> Bool {
  (self.bits & MARK_ATTACH) != 0
}

///|
/// Glyph identifier and positioning information as a result of shaping.
pub struct Glyph {
  /// Glyph identifier.
  id : GlyphId
  /// Glyph flags.
  info : GlyphInfo
  /// Horizontal offset.
  x : Double
  /// Vertical offset.
  y : Double
  /// Advance width or height.
  advance : Double
  /// Arbitrary user data.
  data : UserData
}

///|
pub fn Glyph::default() -> Glyph {
  Glyph::{
    id: (0).to_uint16(),
    info: GlyphInfo::default(),
    x: 0.0,
    y: 0.0,
    advance: 0.0,
    data: 0U,
  }
}

///|
pub fn Glyph::id(self : Glyph) -> GlyphId {
  self.id
}

///|
pub fn Glyph::info(self : Glyph) -> GlyphInfo {
  self.info
}

///|
pub fn Glyph::x(self : Glyph) -> Double {
  self.x
}

///|
pub fn Glyph::y(self : Glyph) -> Double {
  self.y
}

///|
pub fn Glyph::advance(self : Glyph) -> Double {
  self.advance
}

///|
pub fn Glyph::data(self : Glyph) -> UserData {
  self.data
}

///|
/// Collection of glyphs and associated metadata corresponding to one or
/// more source clusters.
pub struct GlyphCluster {
  /// Full source range of the cluster in original units supplied to the shaper.
  source : SourceRange
  /// Information about the textual content of the cluster.
  info : ClusterInfo
  /// Sequence of glyphs for the cluster. May be empty for clusters whose
  /// source consisted entirely of control characters.
  glyphs : ArrayView[Glyph]
  /// If the cluster is a ligature, this contains the source range
  /// of each ligature component. Empty otherwise.
  components : ArrayView[SourceRange]
  /// Arbitrary user data-- taken from the initial character of the cluster.
  data : UserData
}

///|
pub fn GlyphCluster::source(self : GlyphCluster) -> SourceRange {
  self.source
}

///|
pub fn GlyphCluster::info(self : GlyphCluster) -> ClusterInfo {
  self.info
}

///|
pub fn GlyphCluster::glyphs(self : GlyphCluster) -> ArrayView[Glyph] {
  self.glyphs
}

///|
pub fn GlyphCluster::components(self : GlyphCluster) -> ArrayView[SourceRange] {
  self.components
}

///|
pub fn GlyphCluster::data(self : GlyphCluster) -> UserData {
  self.data
}

///|
/// Returns true if the cluster is empty. Empty clusters still represent
/// characters in the source text, but contain no glyphs. This will be
/// true, for example, with newline sequences (\n or \r\n) as well as other
/// control characters.
pub fn GlyphCluster::is_empty(self : GlyphCluster) -> Bool {
  self.glyphs.length() == 0
}

///|
/// Returns true if the cluster contains a single glyph. Note that a simple
/// cluster can also be a ligature.
pub fn GlyphCluster::is_simple(self : GlyphCluster) -> Bool {
  self.glyphs.length() == 1
}

///|
/// Returns true if the cluster corresponds to multiple source clusters.
/// Note that a ligature cluster can also be complex.
pub fn GlyphCluster::is_ligature(self : GlyphCluster) -> Bool {
  self.components.length() != 0
}

///|
/// Returns true if the cluster is complex-- that is if it contains more
/// than one glyph. This will be true for clusters containing marks and is
/// also commonly true for syllabic languages such as those in the Indic
/// family.
pub fn GlyphCluster::is_complex(self : GlyphCluster) -> Bool {
  self.glyphs.length() > 1
}

///|
/// Computes the full advance width or height of the cluster.
pub fn GlyphCluster::advance(self : GlyphCluster) -> Double {
  let mut advance = 0.0
  for g in self.glyphs {
    advance = advance + g.advance()
  }
  advance
}
