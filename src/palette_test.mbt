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
fn palette_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn palette_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn palette_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn palette_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  palette_test_push_u32_be(out, palette_test_u32(0x00010000))
  palette_test_push_u16_be(out, num_tables)
  palette_test_push_u16_be(out, 0)
  palette_test_push_u16_be(out, 0)
  palette_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    palette_test_push_u32_be(out, tag)
    palette_test_push_u32_be(out, palette_test_u32(0))
    palette_test_push_u32_be(out, palette_test_u32(offset))
    palette_test_push_u32_be(out, palette_test_u32(data.length()))
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
fn palette_test_make_cpal_v0() -> Bytes {
  let out : Array[Byte] = Array::new()
  palette_test_push_u16_be(out, 0) // version
  palette_test_push_u16_be(out, 2) // numPaletteEntries
  palette_test_push_u16_be(out, 1) // numPalettes
  palette_test_push_u16_be(out, 2) // numColorRecords
  palette_test_push_u32_be(out, palette_test_u32(14)) // offsetFirstColorRecord
  palette_test_push_u16_be(out, 0) // colorRecordIndices[0]
  // ColorRecord[0] = red (BGRA)
  out.push((0).to_byte())
  out.push((0).to_byte())
  out.push((255).to_byte())
  out.push((255).to_byte())
  // ColorRecord[1] = green (BGRA)
  out.push((0).to_byte())
  out.push((255).to_byte())
  out.push((0).to_byte())
  out.push((255).to_byte())
  Bytes::from_array(out.op_as_view())
}

///|
test "FontRef::color_palettes reads CPAL v0 colors" {
  let sfnt = palette_test_build_sfnt(
    Array::from_fixed_array([(0x4350414c, palette_test_make_cpal_v0())], // "CPAL"
    ),
  )
  let font = FontRef::from_offset(sfnt, 0).unwrap()
  let palettes = font.color_palettes()
  inspect(palettes.len(), content="1")
  let p0_opt = palettes.iter().next()
  if p0_opt is Some(p0) {
    inspect(p0.len().to_int().to_string(), content="2")
    let (r0, g0, b0, a0) = p0.get((0).to_uint16())
    inspect(r0.to_int().to_string(), content="255")
    inspect(g0.to_int().to_string(), content="0")
    inspect(b0.to_int().to_string(), content="0")
    inspect(a0.to_int().to_string(), content="255")
    let (r1, g1, b1, a1) = p0.get((1).to_uint16())
    inspect(r1.to_int().to_string(), content="0")
    inspect(g1.to_int().to_string(), content="255")
    inspect(b1.to_int().to_string(), content="0")
    inspect(a1.to_int().to_string(), content="255")
    inspect(p0.name_id() is None, content="true")
    inspect(p0.usability() is None, content="true")
  } else {
    fail("expected Some(palette)")
  }
}
