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
/// Font references.
///
/// Ported from `swash/src/font.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
/// Reference to the content of a font file.
pub struct FontDataRef {
  data : Bytes
  len : Int
}

///|
pub fn FontDataRef::new(data : Bytes) -> FontDataRef? {
  if !@internal.is_font(data, 0) && !@internal.is_collection(data) {
    None
  } else {
    Some(FontDataRef::{ data, len: @internal.count(data) })
  }
}

///|
pub fn FontDataRef::is_collection(self : FontDataRef) -> Bool {
  @internal.is_collection(self.data)
}

///|
pub fn FontDataRef::data(self : FontDataRef) -> Bytes {
  self.data
}

///|
pub fn FontDataRef::len(self : FontDataRef) -> Int {
  self.len
}

///|
pub fn FontDataRef::is_empty(self : FontDataRef) -> Bool {
  self.len == 0
}

///|
pub fn FontDataRef::get(self : FontDataRef, index : Int) -> FontRef? {
  match @internal.offset(self.data, index) {
    None => None
    Some(off) => FontRef::from_offset(self.data, off)
  }
}

///|
pub fn FontDataRef::fonts(self : FontDataRef) -> Iter[FontRef] {
  let mut pos = 0
  Iter::new(fn() {
    guard pos < self.len else { None }
    let i = pos
    pos = pos + 1
    self.get(i)
  })
}

///|
/// Reference to a font.
pub struct FontRef {
  data : Bytes
  offset : Int
  key : CacheKey
}

///|
pub fn FontRef::data(self : FontRef) -> Bytes {
  self.data
}

///|
pub fn FontRef::offset(self : FontRef) -> Int {
  self.offset
}

///|
pub fn FontRef::key(self : FontRef) -> CacheKey {
  self.key
}

///|
pub fn FontRef::from_index(data : Bytes, index : Int) -> FontRef? {
  match FontDataRef::new(data) {
    None => None
    Some(d) => d.get(index)
  }
}

///|
pub fn FontRef::from_offset(data : Bytes, offset : Int) -> FontRef? {
  if !@internal.is_font(data, offset) {
    None
  } else {
    Some(FontRef::{ data, offset, key: CacheKey::new() })
  }
}

///|
pub impl @internal.RawFont for FontRef with data(self) {
  self.data
}

///|
pub impl @internal.RawFont for FontRef with offset(self) {
  self.offset
}

///|
pub fn FontRef::table_data(self : FontRef, tag : Tag) -> BytesView? {
  @internal.table_data(self, tag)
}

///|
test "FontDataRef/FontRef basic collection support" {
  // Collection with one font at offset 0x20.
  let data = Bytes::makei(36, i => if i == 0 {
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
    b'\x01'
  } else if i == 12 {
    b'\x00'
  } else if i == 13 {
    b'\x00'
  } else if i == 14 {
    b'\x00'
  } else if i == 15 {
    b'\x20'
  } else if i == 32 {
    b'\x00'
  } else if i == 33 {
    b'\x01'
  } else if i == 34 {
    b'\x00'
  } else if i == 35 {
    b'\x00'
  } else {
    b'\x00'
  })
  let fdr_opt = FontDataRef::new(data)
  if fdr_opt is Some(fdr) {
    inspect(fdr.is_collection(), content="true")
    inspect(fdr.len(), content="1")
    inspect(fdr.get(0) is Some(_), content="true")
  } else {
    fail("expected Some(FontDataRef)")
  }
}
