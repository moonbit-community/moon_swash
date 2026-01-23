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
test "raw_data is_font detects font headers" {
  inspect(is_font(b"\x00\x01\x00\x00", 0), content="true")
  inspect(is_font(b"OTTO", 0), content="true")
  inspect(is_font(b"true", 0), content="true")
  inspect(is_font(b"xxxx", 0), content="false")
}

///|
test "raw_data collection count and offsets" {
  // Build a minimal TTC:
  // 0..4: 'ttcf'
  // 8..12: numFonts = 2
  // 12..: offsets array [0x20, 0x40]
  let data = Bytes::makei(20, i => if i == 0 {
    b't'
  } else if i == 1 {
    b't'
  } else if i == 2 {
    b'c'
  } else if i == 3 {
    b'f'
  } else if i == 8 {
    b'\x00'
  } else if i == 9 {
    b'\x00'
  } else if i == 10 {
    b'\x00'
  } else if i == 11 {
    b'\x02'
  } else if i == 12 {
    b'\x00'
  } else if i == 13 {
    b'\x00'
  } else if i == 14 {
    b'\x00'
  } else if i == 15 {
    b'\x20'
  } else if i == 16 {
    b'\x00'
  } else if i == 17 {
    b'\x00'
  } else if i == 18 {
    b'\x00'
  } else if i == 19 {
    b'\x40'
  } else {
    b'\x00'
  })
  inspect(is_collection(data), content="true")
  inspect(count(data), content="2")
  inspect(offset(data, 0), content="Some(32)")
  inspect(offset(data, 1), content="Some(64)")
}
