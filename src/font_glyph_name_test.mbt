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
fn push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn set_u16_be(buf : Array[Byte], off : Int, v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  buf[off] = ((u >> 8) & mask).to_byte()
  buf[off + 1] = (u & mask).to_byte()
}

///|
fn set_u32_be(buf : Array[Byte], off : Int, v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  buf[off] = ((v >> 24) & mask).to_byte()
  buf[off + 1] = ((v >> 16) & mask).to_byte()
  buf[off + 2] = ((v >> 8) & mask).to_byte()
  buf[off + 3] = (v & mask).to_byte()
}

///|
fn build_sfnt_1_table(tag : UInt, data : Bytes) -> Bytes {
  let out : Array[Byte] = Array::new()
  // sfnt version 1.0
  push_u32_be(out, 0x00010000)
  // numTables
  push_u16_be(out, 1)
  // searchRange/entrySelector/rangeShift (ignored by our parser)
  push_u16_be(out, 0)
  push_u16_be(out, 0)
  push_u16_be(out, 0)
  // Table record
  let header_len = 12 + 16
  push_u32_be(out, tag)
  push_u32_be(out, 0) // checksum
  push_u32_be(out, header_len.reinterpret_as_uint())
  push_u32_be(out, data.length().reinterpret_as_uint())
  // Table bytes
  for b in data.iter() {
    out.push(b)
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn make_post_v1() -> Bytes {
  let buf : Array[Byte] = Array::makei(32, _ => b'\x00')
  set_u32_be(buf, 0, 0x00010000)
  Bytes::from_array(buf.op_as_view())
}

///|
fn make_post_v2_foo() -> Bytes {
  let buf : Array[Byte] = Array::makei(40, _ => b'\x00')
  set_u32_be(buf, 0, 0x00020000)
  set_u16_be(buf, 32, 1) // glyph count
  set_u16_be(buf, 34, 258) // first custom string
  buf[36] = b'\x03'
  buf[37] = b'f'
  buf[38] = b'o'
  buf[39] = b'o'
  Bytes::from_array(buf.op_as_view())
}

///|
test "FontRef.glyph_name uses Post table name mapping" {
  let post = make_post_v1()
  let font_data = build_sfnt_1_table(0x706F7374, post)
  let font_opt = FontRef::from_offset(font_data, 0)
  if font_opt is Some(font) {
    inspect(font.glyph_name(0).unwrap_or(""), content=".notdef")
    inspect(font.table_by_tag(0x706F7374) is Some(_), content="true")
  } else {
    fail("expected synthetic sfnt to be recognized as a font")
  }
}

///|
test "FontRef.glyph_name supports Post v2.0 custom strings" {
  let post = make_post_v2_foo()
  let font_data = build_sfnt_1_table(0x706F7374, post)
  let font_opt = FontRef::from_offset(font_data, 0)
  if font_opt is Some(font) {
    inspect(font.glyph_name(0).unwrap_or(""), content="foo")
  } else {
    fail("expected synthetic sfnt to be recognized as a font")
  }
}
