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
/// Scaling, hinting and rasterization of visual glyph representations.
///
/// This package is an early scaffold ported from upstream `swash/src/scale/*`.
/// The public data model aims to stay source-compatible with upstream where
/// practical; functional rasterization is implemented incrementally.

pub type PaletteIndex = UInt16
pub type StrikeIndex = UInt

///|
/// Bitmap strike selection mode.
pub(all) enum StrikeWith {
  ExactSize
  BestFit
  LargestSize
  Index(StrikeIndex)
}

///|
/// Glyph sources for the renderer.
pub(all) enum Source {
  /// Scalable outlines.
  Outline
  /// Layered color scalable outlines.
  ColorOutline(PaletteIndex)
  /// Embedded alpha bitmaps.
  Bitmap(StrikeWith)
  /// Embedded color bitmaps.
  ColorBitmap(StrikeWith)
}

///|
pub fn Source::default() -> Source {
  Source::Outline
}

test "Source::default is Outline" {
  let ok = match Source::default() {
    Outline => true
    _ => false
  }
  inspect(ok, content="true")
}
