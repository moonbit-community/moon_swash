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
/// Tests for AAT lookup table parsing.
fn push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  out.push(((u >> 8) & 0xFFU).to_byte())
  out.push((u & 0xFFU).to_byte())
}

///|
fn push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  out.push(((v >> 24) & 0xFFU).to_byte())
  out.push(((v >> 16) & 0xFFU).to_byte())
  out.push(((v >> 8) & 0xFFU).to_byte())
  out.push((v & 0xFFU).to_byte())
}

///|
test "aat_lookup_u16 format0" {
  let bytes : Array[Byte] = []
  push_u16_be(bytes, 0) // fmt
  push_u16_be(bytes, 10)
  push_u16_be(bytes, 11)
  push_u16_be(bytes, 12)
  let b = BeBytes::new(Bytes::from_array(bytes))
  inspect(aat_lookup_u16(b, 0, (0).to_uint16()), content="Some(10)")
  inspect(aat_lookup_u16(b, 0, (2).to_uint16()), content="Some(12)")
}

///|
test "aat_lookup_u16 format6" {
  let bytes : Array[Byte] = []
  push_u16_be(bytes, 6) // fmt
  push_u16_be(bytes, 0) // unused
  push_u16_be(bytes, 2) // nrecs
  push_u16_be(bytes, 0) // unused
  push_u32_be(bytes, 0U) // unused (padding to 12 bytes total)
  // records at offset 12: (glyph, value)
  push_u16_be(bytes, 3)
  push_u16_be(bytes, 9)
  push_u16_be(bytes, 10)
  push_u16_be(bytes, 7)
  let b = BeBytes::new(Bytes::from_array(bytes))
  inspect(aat_lookup_u16(b, 0, (3).to_uint16()), content="Some(9)")
  inspect(aat_lookup_u16(b, 0, (10).to_uint16()), content="Some(7)")
  inspect(aat_lookup_u16(b, 0, (4).to_uint16()), content="None")
}

///|
test "aat_lookup_u16 format8" {
  let bytes : Array[Byte] = []
  push_u16_be(bytes, 8) // fmt
  push_u16_be(bytes, 5) // first
  push_u16_be(bytes, 3) // count
  push_u16_be(bytes, 100)
  push_u16_be(bytes, 101)
  push_u16_be(bytes, 102)
  let b = BeBytes::new(Bytes::from_array(bytes))
  inspect(aat_lookup_u16(b, 0, (5).to_uint16()), content="Some(100)")
  inspect(aat_lookup_u16(b, 0, (7).to_uint16()), content="Some(102)")
  inspect(aat_lookup_u16(b, 0, (8).to_uint16()), content="None")
}
