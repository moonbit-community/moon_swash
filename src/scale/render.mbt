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
/// Renderer scaffolding.
///
/// Ported in shape from upstream `swash::scale::Render`, but without the actual
/// rasterization pipeline (zeno Mask/Scratch) yet.

pub struct Render {
  sources : Array[Source]
  format : @zeno.Format
  offset : @zeno.Vector
}

///|
pub fn Render::new(sources : Array[Source]) -> Render {
  Render::{
    sources,
    format: @zeno.Format::Alpha,
    offset: @zeno.Vector::new(0.0, 0.0),
  }
}

///|
pub fn Render::format(self : Render, format : @zeno.Format) -> Render {
  Render::{ sources: self.sources, format, offset: self.offset }
}

///|
pub fn Render::offset(self : Render, offset : @zeno.Vector) -> Render {
  Render::{ sources: self.sources, format: self.format, offset }
}

///|
pub fn Render::render(_self : Render, _scaler : Scaler, _glyph_id : @swash.GlyphId) -> Image? {
  // TODO(swash): implement render using Outline/Bitmap sources.
  None
}

test "Render builder scaffolding" {
  let r = Render::new([Source::Outline]).format(@zeno.Format::Subpixel).offset(
    @zeno.Vector::new(0.25, 0.75),
  )
  inspect(r.sources.length(), content="1")
}
