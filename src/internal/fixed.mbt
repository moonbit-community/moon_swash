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
/// Minimal fixed point math types and functions used internally.
///
/// Ported from `swash/src/internal/fixed.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
/// Fixed point value in 16.16 format.
pub struct Fixed {
  value : Int
}

///|
pub fn Fixed::raw(self : Fixed) -> Int {
  self.value
}

///|
pub fn Fixed::from_raw(value : Int) -> Fixed {
  Fixed::{ value, }
}

///|
pub fn Fixed::min_value() -> Fixed {
  Fixed::{ value: (0x80000000 : UInt).reinterpret_as_int() }
}

///|
pub fn Fixed::max_value() -> Fixed {
  Fixed::{ value: 0x7FFFFFFF }
}

///|
pub fn Fixed::epsilon() -> Fixed {
  Fixed::{ value: 1 }
}

///|
pub fn Fixed::zero() -> Fixed {
  Fixed::{ value: 0 }
}

///|
pub fn Fixed::one() -> Fixed {
  Fixed::{ value: 0x10000 }
}

///|
pub fn Fixed::from_i32(x : Int) -> Fixed {
  Fixed::{ value: (x.reinterpret_as_uint() << 16).reinterpret_as_int() }
}

///|
pub fn Fixed::from_f32(x : Double) -> Fixed {
  Fixed::{ value: (x * 65536.0 + 0.5).to_int() }
}

///|
pub fn Fixed::from_f2dot14(x : Int) -> Fixed {
  Fixed::{ value: x * 4 }
}

///|
pub fn Fixed::round(self : Fixed) -> Fixed {
  let v = (self.value.reinterpret_as_uint() + 0x8000) & 0xFFFF0000
  Fixed::{ value: v.reinterpret_as_int() }
}

///|
pub fn Fixed::floor(self : Fixed) -> Fixed {
  let v = self.value.reinterpret_as_uint() & 0xFFFF0000
  Fixed::{ value: v.reinterpret_as_int() }
}

///|
pub fn Fixed::abs(self : Fixed) -> Fixed {
  Fixed::{ value: self.value.abs() }
}

///|
pub fn Fixed::min(self : Fixed, rhs : Fixed) -> Fixed {
  if self.value < rhs.value {
    self
  } else {
    rhs
  }
}

///|
pub fn Fixed::max(self : Fixed, rhs : Fixed) -> Fixed {
  if self.value > rhs.value {
    self
  } else {
    rhs
  }
}

///|
pub fn Fixed::fract(self : Fixed) -> Fixed {
  Fixed::{ value: self.value - self.floor().value }
}

///|
pub fn Fixed::to_i32(self : Fixed) -> Int {
  (self.value + 0x8000) >> 16
}

///|
pub fn Fixed::to_f32(self : Fixed) -> Double {
  self.value.to_double() / 65536.0
}

///|
pub fn Fixed::to_f2dot14(self : Fixed) -> Int {
  (self.value + 2) >> 2
}

///|
pub impl Add for Fixed with add(self, rhs) {
  Fixed::{
    value: (self.value.reinterpret_as_uint() + rhs.value.reinterpret_as_uint()).reinterpret_as_int(),
  }
}

///|
pub impl Sub for Fixed with sub(self, rhs) {
  Fixed::{
    value: (self.value.reinterpret_as_uint() - rhs.value.reinterpret_as_uint()).reinterpret_as_int(),
  }
}

///|
pub impl Mul for Fixed with mul(self, rhs) {
  Fixed::{ value: mul(self.value, rhs.value) }
}

///|
pub impl Div for Fixed with div(self, rhs) {
  Fixed::{ value: div(self.value, rhs.value) }
}

///|
pub impl Neg for Fixed with neg(self) {
  Fixed::{ value: -self.value }
}

///|
/// Fixed point floor (26.6).
pub fn floor(x : Int) -> Int {
  x & -64
}

///|
/// Fixed point ceil (26.6).
pub fn ceil(x : Int) -> Int {
  floor(x + 63)
}

///|
/// Fixed point round (26.6).
pub fn round(x : Int) -> Int {
  floor(x + 32)
}

///|
/// Fixed point multiply (16.16).
pub fn mul(a : Int, b : Int) -> Int {
  let ab = a.to_int64() * b.to_int64()
  let adj = 0x8000L - (if ab < 0L { 1L } else { 0L })
  ((ab + adj) >> 16).to_int()
}

///|
/// Fixed point divide (16.16).
pub fn div(a0 : Int, b0 : Int) -> Int {
  let mut a = a0
  let mut b = b0
  let mut s = 1
  if a < 0 {
    a = -a
    s = -1
  }
  if b < 0 {
    b = -b
    s = -s
  }
  let q : UInt = if b == 0 {
    0x7FFFFFFF
  } else {
    let au = a.reinterpret_as_uint().to_uint64()
    let bu = b.reinterpret_as_uint().to_uint64()
    let num = (au << 16) + (bu >> 1)
    (num / bu).to_int().reinterpret_as_uint()
  }
  let qi = q.reinterpret_as_int()
  if s < 0 {
    -qi
  } else {
    qi
  }
}

///|
/// Fixed point multiply/divide.
pub fn muldiv(a0 : Int, b0 : Int, c0 : Int) -> Int {
  let mut a = a0
  let mut b = b0
  let mut c = c0
  let mut s = 1
  if a < 0 {
    a = -a
    s = -1
  }
  if b < 0 {
    b = -b
    s = -s
  }
  if c < 0 {
    c = -c
    s = -s
  }
  let d : Int64 = if c > 0 {
    (a.to_int64() * b.to_int64() + (c.to_int64() >> 1)) / c.to_int64()
  } else {
    0x7FFFFFFFL
  }
  let di = d.to_int()
  if s < 0 {
    -di
  } else {
    di
  }
}

///|
test "Fixed 16.16 conversions and ops" {
  inspect(Fixed::from_i32(1).to_i32(), content="1")
  inspect((Fixed::from_i32(1) + Fixed::from_i32(2)).to_i32(), content="3")
  inspect((Fixed::from_i32(3) - Fixed::from_i32(1)).to_i32(), content="2")
  inspect((Fixed::from_i32(2) * Fixed::from_i32(3)).to_i32(), content="6")
}
