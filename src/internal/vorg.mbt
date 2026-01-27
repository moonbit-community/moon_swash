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
/// Vertical origin table.
///
/// Ported from `swash/src/internal/vorg.rs` (swash is dual-licensed Apache-2.0 OR MIT).
pub const VORG : RawTag = 0x564F5247 // "VORG"

///|
/// Returns the vertical origin for the specified glyph.
pub fn origin(data : Bytes, vorg : UInt, glyph_id : UInt) -> Int? {
  if vorg == 0 {
    return None
  }
  let b = BeBytes::new(data)
  let base = vorg.reinterpret_as_int()
  let default = match b.read_i16(base + 4) {
    None => return None
    Some(v) => v
  }
  let count = match b.read_u16(base + 6) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let mut l = 0
  let mut h = count
  while l < h {
    let i = (l + h) / 2
    let rec = base + 8 + i * 4
    let g = match b.read_u16(rec) {
      None => return None
      Some(v) => v
    }
    if glyph_id < g {
      h = i
    } else if glyph_id > g {
      l = i + 1
    } else {
      return b.read_i16(rec + 2)
    }
  }
  Some(default)
}
