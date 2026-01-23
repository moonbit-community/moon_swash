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
/// Glyph metrics tables.
///
/// Ported from `swash/src/internal/xmtx.rs` (swash is dual-licensed Apache-2.0 OR MIT).
pub const HMTX : RawTag = 0x686D7478 // "hmtx"

///|
pub const VMTX : RawTag = 0x766D7478 // "vmtx"

///|
/// Returns the advance for the specified glyph.
pub fn advance(
  data : Bytes,
  xmtx : UInt,
  long_metric_count : UInt,
  glyph_id : UInt,
) -> UInt {
  let b = BeBytes::new(data)
  let offset = if glyph_id < long_metric_count {
    glyph_id.reinterpret_as_int() * 4
  } else {
    (long_metric_count - 1).reinterpret_as_int() * 4
  }
  let base = xmtx.reinterpret_as_int()
  b.read_u16(base + offset).unwrap_or(0)
}

///|
/// Returns the side bearing for the specified glyph.
pub fn sb(
  data : Bytes,
  xmtx : UInt,
  long_metric_count : UInt,
  glyph_id : UInt,
) -> Int {
  let b = BeBytes::new(data)
  let offset = if glyph_id < long_metric_count {
    glyph_id.reinterpret_as_int() * 4 + 2
  } else {
    long_metric_count.reinterpret_as_int() * 4 +
    (glyph_id - long_metric_count).reinterpret_as_int() * 2
  }
  let base = xmtx.reinterpret_as_int()
  b.read_i16(base + offset).unwrap_or(0)
}

///|
test "xmtx.advance/sb read long/short metrics" {
  // One long metric entry: advance=10, lsb=-2; then extra lsb for glyph 1: 5.
  let data = Bytes::makei(10, i => if i == 0 {
    b'\x00'
  } else if i == 1 {
    b'\x0A'
  } else if i == 2 {
    b'\xFF'
  } else if i == 3 {
    b'\xFE'
  } else if i == 4 {
    b'\x00'
  } else if i == 5 {
    b'\x05'
  } else {
    b'\x00'
  })
  inspect(advance(data, 0, 1, 0), content="10")
  inspect(sb(data, 0, 1, 0), content="-2")
  inspect(advance(data, 0, 1, 1), content="10")
  inspect(sb(data, 0, 1, 1), content="5")
}
