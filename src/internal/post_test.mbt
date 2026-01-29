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
test "Post.name: version 1.0 uses default glyph names" {
  let buf : Array[Byte] = Array::makei(32, _ => b'\x00')
  // version = 0x00010000
  set_u32_be(buf, 0, 0x00010000)
  let post = Post::new(Bytes::from_array(buf.op_as_view())[:])
  inspect(post.has_names(), content="true")
  inspect(post.name(0).unwrap_or(""), content=".notdef")
  inspect(post.name(257).unwrap_or(""), content="dcroat")
  inspect(post.name(258) is None, content="true")
}

///|
test "Post.name: version 2.0 parses custom names" {
  // Minimal post v2.0:
  // - count=1
  // - glyphNameIndex[0]=258 (first custom string)
  // - custom string[0] = \"foo\"
  let buf : Array[Byte] = Array::makei(40, _ => b'\x00')
  set_u32_be(buf, 0, 0x00020000)
  set_u16_be(buf, 32, 1)
  set_u16_be(buf, 34, 258)
  buf[36] = b'\x03'
  buf[37] = b'f'
  buf[38] = b'o'
  buf[39] = b'o'
  let post = Post::new(Bytes::from_array(buf.op_as_view())[:])
  inspect(post.has_names(), content="true")
  inspect(post.name(0).unwrap_or(""), content="foo")
  inspect(post.name(1) is None, content="true")
}
