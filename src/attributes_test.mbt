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
fn attributes_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn attributes_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn attributes_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn attributes_test_set_u16_be(buf : Array[Byte], off : Int, v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  buf[off] = ((u >> 8) & mask).to_byte()
  buf[off + 1] = (u & mask).to_byte()
}

///|
fn attributes_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  // Caller must provide tags in sorted order for internal table_range binary search.
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  attributes_test_push_u32_be(out, attributes_test_u32(0x00010000))
  attributes_test_push_u16_be(out, num_tables)
  attributes_test_push_u16_be(out, 0)
  attributes_test_push_u16_be(out, 0)
  attributes_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    attributes_test_push_u32_be(out, tag)
    attributes_test_push_u32_be(out, attributes_test_u32(0))
    attributes_test_push_u32_be(out, attributes_test_u32(offset))
    attributes_test_push_u32_be(out, attributes_test_u32(data.length()))
    offset = offset + data.length()
  }
  for t in tables {
    let (_, data) = t
    for b in data.iter() {
      out.push(b)
    }
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn attributes_test_make_os2(
  weight_class : Int,
  width_class : Int,
  selection : Int,
) -> Bytes {
  // Enough for offsets: 0..64 (fsSelection at 62)
  let buf : Array[Byte] = Array::makei(64, _ => b'\x00')
  // version=2
  attributes_test_set_u16_be(buf, 0, 2)
  // weight/width class
  attributes_test_set_u16_be(buf, 4, weight_class)
  attributes_test_set_u16_be(buf, 6, width_class)
  // selection flags
  attributes_test_set_u16_be(buf, 62, selection)
  Bytes::from_array(buf.op_as_view())
}

///|
test "FontRef::attributes from OS/2 italic/oblique flags" {
  let sfnt_italic = attributes_test_build_sfnt(
    Array::from_fixed_array([
      (@internal.OS_2, attributes_test_make_os2(700, 5, 0x0001)),
    ]),
  )
  let f0 = FontRef::from_offset(sfnt_italic, 0).unwrap()
  let a0 = f0.attributes()
  inspect(a0.weight() == Weight::bold(), content="true")
  inspect(a0.stretch() == Stretch::normal(), content="true")
  inspect(a0.style() == Style::Italic, content="true")
  let sfnt_oblique = attributes_test_build_sfnt(
    Array::from_fixed_array([
      (@internal.OS_2, attributes_test_make_os2(400, 5, 0x0200)),
    ]),
  )
  let f1 = FontRef::from_offset(sfnt_oblique, 0).unwrap()
  let a1 = f1.attributes()
  inspect(a1.style() is Style::Oblique(_), content="true")
}

///|
test "Attributes::synthesize embolden and skew fallbacks" {
  let base = Attributes::new(Stretch::normal(), Weight::normal(), Style::Normal)
  let req_bold = Attributes::new(
    Stretch::normal(),
    Weight::bold(),
    Style::Normal,
  )
  let s0 = base.synthesize(req_bold)
  inspect(s0.embolden(), content="true")
  inspect(s0.variations().length(), content="0")
  let req_italic = Attributes::new(
    Stretch::normal(),
    Weight::normal(),
    Style::Italic,
  )
  let s1 = base.synthesize(req_italic)
  inspect(s1.embolden(), content="false")
  if s1.skew() is Some(v) {
    inspect(v.to_int(), content="14")
  } else {
    fail("expected Some(skew)")
  }
}
