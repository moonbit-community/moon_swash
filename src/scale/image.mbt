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
/// Rendered glyph image.
///
/// Ported from upstream `swash/src/scale/image.rs` (Apache-2.0 OR MIT).

///|
/// Content of a scaled glyph image.
pub(all) enum Content {
  /// 8-bit alpha mask.
  Mask
  /// 32-bit RGBA subpixel mask.
  SubpixelMask
  /// 32-bit RGBA bitmap.
  Color
}

///|
pub fn Content::default() -> Content {
  Content::Mask
}

///|
/// Scaled glyph image.
pub struct Image {
  /// Source of the image.
  mut source : Source
  /// Content of the image.
  mut content : Content
  /// Offset and size of the image.
  mut placement : Placement
  /// Raw image data.
  mut data : Bytes
}

///|
pub fn Image::new() -> Image {
  Image::{
    source: Source::default(),
    content: Content::default(),
    placement: Placement::{ left: 0, top: 0, width: 0U, height: 0U },
    data: Bytes::from_array([]),
  }
}

///|
pub fn Image::clear(self : Image) -> Unit {
  self.source = Source::default()
  self.content = Content::default()
  self.placement = Placement::{ left: 0, top: 0, width: 0U, height: 0U }
  self.data = Bytes::from_array([])
}

///|
pub fn Image::source(self : Image) -> Source {
  self.source
}

///|
pub fn Image::content(self : Image) -> Content {
  self.content
}

///|
pub fn Image::placement(self : Image) -> Placement {
  self.placement
}

///|
pub fn Image::data(self : Image) -> Bytes {
  self.data
}

test "Image::new produces empty image" {
  let img = Image::new()
  inspect(
    match img.source() {
      Outline => true
      _ => false
    },
    content="true",
  )
  inspect(
    match img.content() {
      Mask => true
      _ => false
    },
    content="true",
  )
  inspect(img.placement().width, content="0")
  inspect(img.data().length(), content="0")
}

test "Image::clear resets fields" {
  let img = Image::new()
  img.clear()
  inspect(
    match img.source() {
      Outline => true
      _ => false
    },
    content="true",
  )
  inspect(
    match img.content() {
      Mask => true
      _ => false
    },
    content="true",
  )
  inspect(img.data().length(), content="0")
}
