// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the Apache License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Glyph outline.
///
/// Ported from upstream `swash/src/scale/outline.rs` (Apache-2.0 OR MIT).
///
/// Note: MoonBit doesn't currently expose slice borrowing like Rust, so the
/// `Layer` accessors return index ranges into the shared points/verbs arrays.

pub struct LayerData {
  points_start : Int
  points_end : Int
  verbs_start : Int
  verbs_end : Int
  color_index : Option[UInt16]
}

///|
/// Scaled glyph outline represented as a collection of layers and a sequence
/// of points and verbs.
pub struct Outline {
  layers : Array[LayerData]
  points : Array[Point]
  verbs : Array[Verb]
  mut is_color : Bool
}

///|
pub fn Outline::new() -> Outline {
  Outline::{ layers: [], points: [], verbs: [], is_color: false }
}

///|
pub fn Outline::is_color(self : Outline) -> Bool {
  self.is_color
}

///|
pub fn Outline::len(self : Outline) -> Int {
  self.layers.length()
}

///|
pub fn Outline::is_empty(self : Outline) -> Bool {
  self.layers.length() == 0
}

///|
pub fn Outline::layer_data(self : Outline, index : Int) -> Option[LayerData] {
  if index < 0 || index >= self.layers.length() {
    None
  } else {
    Some(self.layers[index])
  }
}

///|
pub fn Outline::points(self : Outline) -> Array[Point] {
  self.points
}

///|
pub fn Outline::verbs(self : Outline) -> Array[Verb] {
  self.verbs
}

///|
pub fn Outline::bounds(self : Outline) -> Bounds {
  Bounds::from_points(self.points)
}

///|
pub fn Outline::transform(self : Outline, transform : Transform) -> Unit {
  for i in 0..<self.points.length() {
    self.points[i] = transform.transform_point(self.points[i])
  }
}

///|
pub fn Outline::clear(self : Outline) -> Unit {
  self.points.clear()
  self.verbs.clear()
  self.layers.clear()
  self.is_color = false
}

// ---- internal builders (ported from `pub(super)` APIs) ----

///| Internal builder method (upstream: `pub(super)`).
pub fn Outline::set_color(self : Outline, color : Bool) -> Unit {
  self.is_color = color
}

fn Outline::maybe_close(self : Outline) -> Unit {
  if self.verbs.length() == 0 {
    return
  }
  match self.verbs[self.verbs.length() - 1] {
    Verb::Close => return
    _ => ()
  }
  // Close current contour at layer boundary.
  self.verbs.push(Verb::Close)
}

///| Internal builder method (upstream: `pub(super)`).
pub fn Outline::begin_layer(self : Outline, color_index : Option[UInt16]) -> Unit {
  let points_end = self.points.length()
  let verbs_end = self.verbs.length()
  if self.layers.length() > 0 {
    let last = self.layers[self.layers.length() - 1]
    self.layers[self.layers.length() - 1] = LayerData::{
      points_start: last.points_start,
      points_end,
      verbs_start: last.verbs_start,
      verbs_end,
      color_index: last.color_index,
    }
  }
  self.layers.push(
    LayerData::{
      points_start: points_end,
      points_end,
      verbs_start: verbs_end,
      verbs_end,
      color_index,
    },
  )
}

///| Internal builder method (upstream: `pub(super)`).
pub fn Outline::finish(self : Outline) -> Unit {
  let points_end = self.points.length()
  let verbs_end = self.verbs.length()
  if self.layers.length() > 0 {
    let last = self.layers[self.layers.length() - 1]
    self.layers[self.layers.length() - 1] = LayerData::{
      points_start: last.points_start,
      points_end,
      verbs_start: last.verbs_start,
      verbs_end,
      color_index: last.color_index,
    }
  } else {
    self.layers.push(
      LayerData::{
        points_start: 0,
        points_end,
        verbs_start: 0,
        verbs_end,
        color_index: None,
      },
    )
  }
}

///| Internal builder method (upstream: `pub(super)`).
pub fn Outline::move_to(self : Outline, p : Point) -> Unit {
  self.maybe_close()
  self.points.push(p)
  self.verbs.push(Verb::MoveTo)
}

///| Internal builder method (upstream: `pub(super)`).
pub fn Outline::line_to(self : Outline, p : Point) -> Unit {
  self.points.push(p)
  self.verbs.push(Verb::LineTo)
}

///| Internal builder method (upstream: `pub(super)`).
pub fn Outline::quad_to(self : Outline, p0 : Point, p1 : Point) -> Unit {
  self.points.push(p0)
  self.points.push(p1)
  self.verbs.push(Verb::QuadTo)
}

///| Internal builder method (upstream: `pub(super)`).
pub fn Outline::curve_to(
  self : Outline,
  p0 : Point,
  p1 : Point,
  p2 : Point,
) -> Unit {
  self.points.push(p0)
  self.points.push(p1)
  self.points.push(p2)
  self.verbs.push(Verb::CurveTo)
}

///| Internal builder method (upstream: `pub(super)`).
pub fn Outline::close(self : Outline) -> Unit {
  self.verbs.push(Verb::Close)
}

test "Outline basic path recording" {
  let o = Outline::new()
  o.set_color(false)
  o.begin_layer(None)
  o.move_to(Vector::new(0.0, 0.0))
  o.line_to(Vector::new(10.0, 0.0))
  o.line_to(Vector::new(10.0, 10.0))
  o.quad_to(Vector::new(0.0, 10.0), Vector::new(0.0, 0.0))
  o.curve_to(
    Vector::new(1.0, 1.0),
    Vector::new(2.0, 2.0),
    Vector::new(3.0, 3.0),
  )
  o.close()
  o.finish()
  inspect(o.points().length(), content="8")
  inspect(o.verbs().length(), content="6")
  inspect(o.len(), content="1")
  inspect(o.bounds().width().to_int(), content="10")
  inspect(o.bounds().height().to_int(), content="10")
}
