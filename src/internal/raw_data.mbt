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
/// Font/collection probing helpers.
///
/// Ported from `swash/src/internal/mod.rs` (module `raw_data`).
///
/// swash is dual-licensed Apache-2.0 OR MIT.
pub type RawTag = UInt

///|
pub fn raw_tag(bytes : Bytes) -> RawTag? {
  if bytes.length() < 4 {
    return None
  }
  let b0_opt = bytes.get(0)
  let b1_opt = bytes.get(1)
  let b2_opt = bytes.get(2)
  let b3_opt = bytes.get(3)
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
const OTTO : RawTag = 0x4f54544f // "OTTO"

///|
const TTCF : RawTag = 0x74746366 // "ttcf"

///|
const FONT : RawTag = 0x00010000

///|
const TRUE : RawTag = 0x74727565 // "true"

///|
pub fn is_collection(data : Bytes) -> Bool {
  let tag = BeBytes::new(data).read_u32(0).unwrap_or(0)
  tag == TTCF
}

///|
pub fn is_font(data : Bytes, offset : Int) -> Bool {
  let tag = BeBytes::new(data).read_u32(offset).unwrap_or(0)
  tag == FONT || tag == OTTO || tag == TRUE
}

///|
pub fn count(data : Bytes) -> Int {
  if is_collection(data) {
    BeBytes::new(data).read_u32(8).unwrap_or(0).reinterpret_as_int()
  } else if is_font(data, 0) {
    1
  } else {
    0
  }
}

///|
pub fn offset(data : Bytes, index : Int) -> Int? {
  let total = count(data)
  if index < 0 || index >= total {
    return None
  }
  if is_font(data, 0) {
    Some(0)
  } else {
    BeBytes::new(data).read_u32(12 + index * 4).map(x => x.reinterpret_as_int())
  }
}
