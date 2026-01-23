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
struct TestFont {
  data : Bytes
  offset : Int
}

///|
pub impl RawFont for TestFont with data(self) {
  self.data
}

///|
pub impl RawFont for TestFont with offset(self) {
  self.offset
}

///|
fn mk_min_font() -> Bytes {
  // Minimal font with a single table record:
  // sfntVersion = 0x00010000
  // numTables = 1
  // record[0] tag="head", offset=0x20, length=4
  // table bytes = DE AD BE EF
  Bytes::makei(36, i => if i == 0 {
    b'\x00'
  } else if i == 1 {
    b'\x01'
  } else if i == 2 {
    b'\x00'
  } else if i == 3 {
    b'\x00'
  } else if i == 4 {
    b'\x00'
  } else if i == 5 {
    b'\x01'
  } else if i == 12 {
    b'h'
  } else if i == 13 {
    b'e'
  } else if i == 14 {
    b'a'
  } else if i == 15 {
    b'd'
  } else if i == 20 {
    b'\x00'
  } else if i == 21 {
    b'\x00'
  } else if i == 22 {
    b'\x00'
  } else if i == 23 {
    b'\x20'
  } else if i == 24 {
    b'\x00'
  } else if i == 25 {
    b'\x00'
  } else if i == 26 {
    b'\x00'
  } else if i == 27 {
    b'\x04'
  } else if i == 32 {
    b'\xDE'
  } else if i == 33 {
    b'\xAD'
  } else if i == 34 {
    b'\xBE'
  } else if i == 35 {
    b'\xEF'
  } else {
    b'\x00'
  })
}

///|
test "RawFont.table_range/table_data reads the table directory" {
  let data = mk_min_font()
  let font = TestFont::{ data, offset: 0 }
  let head_tag : RawTag = 0x68656164 // "head"
  inspect(table_range(font, head_tag), content="Some((32, 36))")
  let view_opt = table_data(font, head_tag)
  if view_opt is Some(view) {
    inspect(view.length(), content="4")
    inspect(view[0], content="b'\\xDE'")
    inspect(view[1], content="b'\\xAD'")
    inspect(view[2], content="b'\\xBE'")
    inspect(view[3], content="b'\\xEF'")
  } else {
    fail("expected Some(view)")
  }
}
