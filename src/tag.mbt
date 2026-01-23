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
/// Ported from `swash/src/tag.rs` (swash is dual-licensed Apache-2.0 OR MIT).
pub type Tag = UInt

///|
pub fn tag_from_bytes(bytes : Bytes) -> Tag? {
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
pub fn tag_from_str_lossy(s : String) -> Tag {
  let mut b0 : UInt = 32
  let mut b1 : UInt = 32
  let mut b2 : UInt = 32
  let mut b3 : UInt = 32
  let len = s.length()
  if len > 0 {
    b0 = s.code_unit_at(0).to_int().reinterpret_as_uint()
  }
  if len > 1 {
    b1 = s.code_unit_at(1).to_int().reinterpret_as_uint()
  }
  if len > 2 {
    b2 = s.code_unit_at(2).to_int().reinterpret_as_uint()
  }
  if len > 3 {
    b3 = s.code_unit_at(3).to_int().reinterpret_as_uint()
  }
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}
