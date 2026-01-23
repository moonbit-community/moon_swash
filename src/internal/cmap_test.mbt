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
struct CmapTestFont {
  data : Bytes
  offset : Int
}

///|
pub impl RawFont for CmapTestFont with data(self) {
  self.data
}

///|
pub impl RawFont for CmapTestFont with offset(self) {
  self.offset
}

///|
fn mk_font_with_cmap_format4() -> Bytes {
  // A minimal TrueType font with one "cmap" table containing a single
  // format-4 subtable mapping U+0041 ('A') -> glyph 3.
  Bytes::makei(76, i => if i == 0 {
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
    b'c'
  } else if i == 13 {
    b'm'
  } else if i == 14 {
    b'a'
  } else if i == 15 {
    b'p'
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
    b'\x2C'
  } else if i == 32 {
    b'\x00'
  } else if i == 33 {
    b'\x00'
  } else if i == 34 {
    b'\x00'
  } else if i == 35 {
    b'\x01'
  } else if i == 36 {
    b'\x00'
  } else if i == 37 {
    b'\x03'
  } else if i == 38 {
    b'\x00'
  } else if i == 39 {
    b'\x01'
  } else if i == 40 {
    b'\x00'
  } else if i == 41 {
    b'\x00'
  } else if i == 42 {
    b'\x00'
  } else if i == 43 {
    b'\x0C'
  } else if i == 44 {
    b'\x00'
  } else if i == 45 {
    b'\x04'
  } else if i == 46 {
    b'\x00'
  } else if i == 47 {
    b'\x20'
  } else if i == 48 {
    b'\x00'
  } else if i == 49 {
    b'\x00'
  } else if i == 50 {
    b'\x00'
  } else if i == 51 {
    b'\x04'
  } else if i == 58 {
    b'\x00'
  } else if i == 59 {
    b'\x41'
  } else if i == 60 {
    b'\xFF'
  } else if i == 61 {
    b'\xFF'
  } else if i == 62 {
    b'\x00'
  } else if i == 63 {
    b'\x00'
  } else if i == 64 {
    b'\x00'
  } else if i == 65 {
    b'\x41'
  } else if i == 66 {
    b'\xFF'
  } else if i == 67 {
    b'\xFF'
  } else if i == 68 {
    b'\xFF'
  } else if i == 69 {
    b'\xC2'
  } else if i == 70 {
    b'\x00'
  } else if i == 71 {
    b'\x01'
  } else if i == 72 {
    b'\x00'
  } else if i == 73 {
    b'\x00'
  } else if i == 74 {
    b'\x00'
  } else if i == 75 {
    b'\x00'
  } else {
    b'\x00'
  })
}

///|
test "cmap.subtable finds format 4 unicode encoding" {
  let data = mk_font_with_cmap_format4()
  let font = CmapTestFont::{ data, offset: 0 }
  inspect(subtable(font), content="Some((44, 4, false))")
}

///|
test "cmap.map maps U+0041 to glyph id" {
  let data = mk_font_with_cmap_format4()
  // subtable absolute offset is 0x20 + 0x0c = 44
  inspect(map(data, 44, 4, 0x41), content="Some(3)")
  inspect(map(data, 44, 4, 0x42), content="None")
}
