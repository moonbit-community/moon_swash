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
/// Parsing primitives.
///
/// Ported from `swash/src/internal/parse.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
pub struct BeBytes {
  data : BytesView
}

///|
pub fn BeBytes::new(data : Bytes) -> BeBytes {
  BeBytes::{ data: data[:] }
}

///|
pub fn BeBytes::from_view(data : BytesView) -> BeBytes {
  BeBytes::{ data, }
}

///|
pub fn BeBytes::with_offset(data : Bytes, offset : Int) -> BeBytes? {
  if offset < 0 || offset > data.length() {
    return None
  }
  Some(BeBytes::from_view(data[offset:]))
}

///|
pub fn BeBytes::data(self : BeBytes) -> BytesView {
  self.data
}

///|
pub fn BeBytes::len(self : BeBytes) -> Int {
  self.data.length()
}

///|
pub fn BeBytes::check_range(self : BeBytes, offset : Int, len : Int) -> Bool {
  let end = self.data.length()
  offset >= 0 && len >= 0 && offset < end && end - offset >= len
}

///|
pub fn BeBytes::ensure_range(self : BeBytes, offset : Int, len : Int) -> Bool {
  self.check_range(offset, len)
}

///|
pub fn BeBytes::read_u8(self : BeBytes, offset : Int) -> Byte? {
  self.data.get(offset)
}

///|
pub fn BeBytes::read_u16(self : BeBytes, offset : Int) -> UInt? {
  if !self.check_range(offset, 2) {
    return None
  }
  let b0_opt = self.data.get(offset)
  let b1_opt = self.data.get(offset + 1)
  if b0_opt is Some(b0) && b1_opt is Some(b1) {
    let u0 = b0.to_int().reinterpret_as_uint()
    let u1 = b1.to_int().reinterpret_as_uint()
    Some((u0 << 8) | u1)
  } else {
    None
  }
}

///|
pub fn BeBytes::read_u32(self : BeBytes, offset : Int) -> UInt? {
  if !self.check_range(offset, 4) {
    return None
  }
  let b0_opt = self.data.get(offset)
  let b1_opt = self.data.get(offset + 1)
  let b2_opt = self.data.get(offset + 2)
  let b3_opt = self.data.get(offset + 3)
  if b0_opt is Some(b0) &&
    b1_opt is Some(b1) &&
    b2_opt is Some(b2) &&
    b3_opt is Some(b3) {
    let u0 = b0.to_int().reinterpret_as_uint()
    let u1 = b1.to_int().reinterpret_as_uint()
    let u2 = b2.to_int().reinterpret_as_uint()
    let u3 = b3.to_int().reinterpret_as_uint()
    Some((u0 << 24) | (u1 << 16) | (u2 << 8) | u3)
  } else {
    None
  }
}

///|
pub fn BeBytes::read_i32(self : BeBytes, offset : Int) -> Int? {
  self.read_u32(offset).map(x => x.reinterpret_as_int())
}

///|
pub fn BeBytes::read_u64(self : BeBytes, offset : Int) -> UInt64? {
  if !self.check_range(offset, 8) {
    return None
  }
  let view = self.data
  match
    (
      view.get(offset),
      view.get(offset + 1),
      view.get(offset + 2),
      view.get(offset + 3),
      view.get(offset + 4),
      view.get(offset + 5),
      view.get(offset + 6),
      view.get(offset + 7),
    ) {
    (
      Some(b0),
      Some(b1),
      Some(b2),
      Some(b3),
      Some(b4),
      Some(b5),
      Some(b6),
      Some(b7),
    ) =>
      Some(
        (b0.to_uint64() << 56) |
        (b1.to_uint64() << 48) |
        (b2.to_uint64() << 40) |
        (b3.to_uint64() << 32) |
        (b4.to_uint64() << 24) |
        (b5.to_uint64() << 16) |
        (b6.to_uint64() << 8) |
        b7.to_uint64(),
      )
    _ => None
  }
}

///|
pub fn BeBytes::read_u24(self : BeBytes, offset : Int) -> UInt? {
  if !self.check_range(offset, 3) {
    return None
  }
  let b0_opt = self.data.get(offset)
  let b1_opt = self.data.get(offset + 1)
  let b2_opt = self.data.get(offset + 2)
  if b0_opt is Some(b0) && b1_opt is Some(b1) && b2_opt is Some(b2) {
    let u0 = b0.to_int().reinterpret_as_uint()
    let u1 = b1.to_int().reinterpret_as_uint()
    let u2 = b2.to_int().reinterpret_as_uint()
    Some((u0 << 16) | (u1 << 8) | u2)
  } else {
    None
  }
}

///|
pub fn BeBytes::read_i16(self : BeBytes, offset : Int) -> Int? {
  match self.read_u16(offset) {
    None => None
    Some(u) => {
      // Convert u16 bits to signed i16 in Int.
      let v = u.reinterpret_as_int()
      if u >= 0x8000 {
        Some(v - 0x10000)
      } else {
        Some(v)
      }
    }
  }
}

///|
pub struct Stream {
  data : BytesView
  mut offset : Int
}

///|
pub fn Stream::new(data : Bytes) -> Stream {
  Stream::{ data: data[:], offset: 0 }
}

///|
pub fn Stream::from_view(data : BytesView) -> Stream {
  Stream::{ data, offset: 0 }
}

///|
pub fn Stream::with_offset(data : Bytes, offset : Int) -> Stream? {
  if offset < 0 || offset > data.length() {
    return None
  }
  let slice = data[offset:]
  Some(Stream::{ data: slice, offset: 0 })
}

///|
pub fn Stream::len(self : Stream) -> Int {
  self.data.length()
}

///|
pub fn Stream::data(self : Stream) -> BytesView {
  self.data
}

///|
pub fn Stream::offset(self : Stream) -> Int {
  self.offset
}

///|
pub fn Stream::remaining(self : Stream) -> Int {
  self.data.length() - self.offset
}

///|
pub fn Stream::set_offset(self : Stream, offset : Int) -> Bool {
  if offset < 0 || offset > self.data.length() {
    return false
  }
  self.offset = offset
  true
}

///|
pub fn Stream::check_range(self : Stream, len : Int) -> Bool {
  len >= 0 && self.data.length() - self.offset >= len
}

///|
pub fn Stream::skip(self : Stream, bytes : Int) -> Bool {
  if bytes < 0 {
    return false
  }
  self.set_offset(self.offset + bytes)
}

///|
pub fn Stream::read_u8(self : Stream) -> Byte? {
  if !self.check_range(1) {
    return None
  }
  let value = self.data.get(self.offset)
  if value is Some(_) {
    self.offset = self.offset + 1
  }
  value
}

///|
pub fn Stream::read_u16(self : Stream) -> UInt? {
  if !self.check_range(2) {
    return None
  }
  let value = BeBytes::from_view(self.data).read_u16(self.offset)
  if value is Some(_) {
    self.offset = self.offset + 2
  }
  value
}

///|
pub fn Stream::read_u32(self : Stream) -> UInt? {
  if !self.check_range(4) {
    return None
  }
  let value = BeBytes::from_view(self.data).read_u32(self.offset)
  if value is Some(_) {
    self.offset = self.offset + 4
  }
  value
}

///|
pub fn Stream::read_i16(self : Stream) -> Int? {
  if !self.check_range(2) {
    return None
  }
  let value = BeBytes::from_view(self.data).read_i16(self.offset)
  if value is Some(_) {
    self.offset = self.offset + 2
  }
  value
}
