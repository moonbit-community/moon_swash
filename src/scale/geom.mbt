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
/// Minimal geometry types used by swash/scale.
///
/// Upstream swash depends on the external `zeno` crate. In this repo, we
/// provide a minimal local subset to keep mgstudio-swash progressing while
/// `moon_zeno` is being iterated independently.

pub(all) enum Verb {
  MoveTo
  LineTo
  QuadTo
  CurveTo
  Close
}

pub struct Vector {
  x : Double
  y : Double
}

pub type Point = Vector

pub fn Vector::new(x : Double, y : Double) -> Vector {
  Vector::{ x, y }
}

pub fn Vector::x(self : Vector) -> Double {
  self.x
}

pub fn Vector::y(self : Vector) -> Double {
  self.y
}

pub struct Transform {
  xx : Double
  xy : Double
  yx : Double
  yy : Double
  x : Double
  y : Double
}

pub fn Transform::identity() -> Transform {
  Transform::{ xx: 1.0, xy: 0.0, yx: 0.0, yy: 1.0, x: 0.0, y: 0.0 }
}

pub fn Transform::transform_point(self : Transform, point : Point) -> Point {
  Vector::new(
    point.x() * self.xx + point.y() * self.yx + self.x,
    point.x() * self.xy + point.y() * self.yy + self.y,
  )
}

pub struct Bounds {
  mut min : Point
  mut max : Point
  mut empty : Bool
}

pub fn Bounds::from_points(points : Array[Point]) -> Bounds {
  let b = Bounds::{ min: Vector::new(0.0, 0.0), max: Vector::new(0.0, 0.0), empty: true }
  for p in points {
    b.add_point(p)
  }
  b
}

pub fn Bounds::add_point(self : Bounds, p : Point) -> Unit {
  if self.empty {
    self.min = p
    self.max = p
    self.empty = false
    return
  }
  let x = p.x()
  let y = p.y()
  self.min = Vector::new(
    if self.min.x() < x { self.min.x() } else { x },
    if self.min.y() < y { self.min.y() } else { y },
  )
  self.max = Vector::new(
    if self.max.x() > x { self.max.x() } else { x },
    if self.max.y() > y { self.max.y() } else { y },
  )
}

pub fn Bounds::width(self : Bounds) -> Double {
  if self.empty { 0.0 } else { self.max.x() - self.min.x() }
}

pub fn Bounds::height(self : Bounds) -> Double {
  if self.empty { 0.0 } else { self.max.y() - self.min.y() }
}

pub struct Placement {
  left : Int
  top : Int
  width : UInt
  height : UInt
}

pub(all) enum Format {
  Alpha
  Subpixel
  CustomSubpixel(Array[Double])
}

