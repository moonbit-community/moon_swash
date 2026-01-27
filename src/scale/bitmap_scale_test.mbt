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
fn bitmap_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn bitmap_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn bitmap_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn bitmap_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  bitmap_test_push_u32_be(out, bitmap_test_u32(0x00010000))
  bitmap_test_push_u16_be(out, num_tables)
  bitmap_test_push_u16_be(out, 0)
  bitmap_test_push_u16_be(out, 0)
  bitmap_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    bitmap_test_push_u32_be(out, tag)
    bitmap_test_push_u32_be(out, bitmap_test_u32(0))
    bitmap_test_push_u32_be(out, bitmap_test_u32(offset))
    bitmap_test_push_u32_be(out, bitmap_test_u32(data.length()))
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
fn bitmap_test_build_maxp(num_glyphs : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  bitmap_test_push_u32_be(out, bitmap_test_u32(0x00010000))
  bitmap_test_push_u16_be(out, num_glyphs)
  Bytes::from_array(out.op_as_view())
}

///|
fn bitmap_test_build_sbix_with_glyph(
  ppem : Int,
  origin_x : Int,
  origin_y : Int,
  graphic_type : UInt,
  payload : Bytes,
) -> Bytes {
  let data_len = payload.length()
  let strike_off = 12
  let glyph_data_off = 12
  let glyph_end_off = glyph_data_off + 8 + data_len
  let out : Array[Byte] = Array::new()
  bitmap_test_push_u16_be(out, 1) // version
  bitmap_test_push_u16_be(out, 0) // flags
  bitmap_test_push_u32_be(out, bitmap_test_u32(1)) // numStrikes
  bitmap_test_push_u32_be(out, bitmap_test_u32(strike_off)) // strikeOffsets[0]
  // strike header
  bitmap_test_push_u16_be(out, ppem)
  bitmap_test_push_u16_be(out, 72)
  // glyphDataOffsets[numGlyphs+1] for numGlyphs=1
  bitmap_test_push_u32_be(out, bitmap_test_u32(glyph_data_off))
  bitmap_test_push_u32_be(out, bitmap_test_u32(glyph_end_off))
  // glyph record header
  bitmap_test_push_u16_be(out, origin_x & 0xFFFF)
  bitmap_test_push_u16_be(out, origin_y & 0xFFFF)
  bitmap_test_push_u32_be(out, graphic_type)
  for b in payload.iter() {
    out.push(b)
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn bitmap_test_build_cblc_index1(
  ppem_x : Int,
  ppem_y : Int,
  glyph_id : Int,
  image_format : Int,
  image_data_offset : Int,
  glyph_data_len : Int,
  bit_depth : Int,
  major : Int,
) -> Bytes {
  let out : Array[Byte] = Array::new()
  // major/minor
  bitmap_test_push_u16_be(out, major)
  bitmap_test_push_u16_be(out, 0)
  // numSizes = 1
  bitmap_test_push_u32_be(out, bitmap_test_u32(1))
  // BitmapSizeTable (48 bytes)
  bitmap_test_push_u32_be(out, bitmap_test_u32(56)) // indexSubTableArrayOffset
  bitmap_test_push_u32_be(out, bitmap_test_u32(24)) // indexTablesSize
  bitmap_test_push_u32_be(out, bitmap_test_u32(1)) // numberOfIndexSubTables
  bitmap_test_push_u32_be(out, bitmap_test_u32(0)) // colorRef
  for _ in 0..<24 {
    out.push(0 |> Int::to_byte)
  }
  bitmap_test_push_u16_be(out, glyph_id)
  bitmap_test_push_u16_be(out, glyph_id)
  out.push(ppem_x |> Int::to_byte)
  out.push(ppem_y |> Int::to_byte)
  out.push(bit_depth |> Int::to_byte)
  out.push(0 |> Int::to_byte)
  // IndexSubTableArray at offset 56
  bitmap_test_push_u16_be(out, glyph_id)
  bitmap_test_push_u16_be(out, glyph_id)
  bitmap_test_push_u32_be(out, bitmap_test_u32(64))
  // IndexSubTable1 at offset 64
  bitmap_test_push_u16_be(out, 1)
  bitmap_test_push_u16_be(out, image_format)
  bitmap_test_push_u32_be(out, bitmap_test_u32(image_data_offset))
  bitmap_test_push_u32_be(out, bitmap_test_u32(0))
  bitmap_test_push_u32_be(out, bitmap_test_u32(glyph_data_len))
  Bytes::from_array(out.op_as_view())
}

///|
fn bitmap_test_build_ebdt_format1() -> Bytes {
  let out : Array[Byte] = Array::new()
  // EBDT header: major=2, minor=0
  bitmap_test_push_u16_be(out, 2)
  bitmap_test_push_u16_be(out, 0)
  // small metrics: height=1, width=8, bearing_x=-1, bearing_y=2, advance=0
  out.push((1).to_byte())
  out.push((8).to_byte())
  out.push((255).to_byte()) // -1
  out.push((2).to_byte())
  out.push((0).to_byte())
  // 1 byte bitmap data: 0b10101010
  out.push((0xAA).to_byte())
  Bytes::from_array(out.op_as_view())
}

///|
test "Scaler.scale_color_bitmap decodes sbix PNG glyph into RGBA" {
  let png = Bytes::from_array(
    Array::from_fixed_array([
      137 |> Int::to_byte,
      80 |> Int::to_byte,
      78 |> Int::to_byte,
      71 |> Int::to_byte,
      13 |> Int::to_byte,
      10 |> Int::to_byte,
      26 |> Int::to_byte,
      10 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      13 |> Int::to_byte,
      73 |> Int::to_byte,
      72 |> Int::to_byte,
      68 |> Int::to_byte,
      82 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      1 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      1 |> Int::to_byte,
      8 |> Int::to_byte,
      6 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      31 |> Int::to_byte,
      21 |> Int::to_byte,
      196 |> Int::to_byte,
      137 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      13 |> Int::to_byte,
      73 |> Int::to_byte,
      68 |> Int::to_byte,
      65 |> Int::to_byte,
      84 |> Int::to_byte,
      120 |> Int::to_byte,
      156 |> Int::to_byte,
      99 |> Int::to_byte,
      248 |> Int::to_byte,
      207 |> Int::to_byte,
      192 |> Int::to_byte,
      240 |> Int::to_byte,
      31 |> Int::to_byte,
      0 |> Int::to_byte,
      5 |> Int::to_byte,
      0 |> Int::to_byte,
      1 |> Int::to_byte,
      255 |> Int::to_byte,
      137 |> Int::to_byte,
      153 |> Int::to_byte,
      61 |> Int::to_byte,
      29 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      0 |> Int::to_byte,
      73 |> Int::to_byte,
      69 |> Int::to_byte,
      78 |> Int::to_byte,
      68 |> Int::to_byte,
      174 |> Int::to_byte,
      66 |> Int::to_byte,
      96 |> Int::to_byte,
      130 |> Int::to_byte,
    ]).op_as_view(),
  )
  let maxp = bitmap_test_build_maxp(1)
  let sbix = bitmap_test_build_sbix_with_glyph(16, 1, 2, 0x706E6720, png) // "png "
  // NOTE: table records must be sorted by tag for swash's table directory binary search.
  let sfnt = bitmap_test_build_sfnt(
    Array::from_fixed_array([(0x6D617870, maxp), (0x73626978, sbix)]),
  )
  let font = @swash.FontRef::from_offset(sfnt, 0).unwrap()
  let cx = ScaleContext::new()
  let scaler = cx.builder(font).size(16.0).build()
  let img = scaler
    .scale_color_bitmap((0).to_uint16(), StrikeWith::ExactSize)
    .unwrap()
  inspect(
    match img.source() {
      ColorBitmap(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match img.content() {
      Color => true
      _ => false
    },
    content="true",
  )
  let p = img.placement()
  inspect(p.left, content="1")
  inspect(p.top, content="2")
  inspect(p.width, content="1")
  inspect(p.height, content="1")
  let data = img.data()
  inspect(data.length(), content="4")
  inspect(data[0].to_int(), content="255") // R
  inspect(data[1].to_int(), content="0") // G
  inspect(data[2].to_int(), content="0") // B
  inspect(data[3].to_int(), content="255") // A
}

///|
test "Scaler.scale_bitmap decodes EBDT 1bpp glyph into alpha mask" {
  let ebdt = bitmap_test_build_ebdt_format1()
  // glyph record starts after EBDT header (4 bytes)
  let glyph_len = 5 + 1
  let eblc = bitmap_test_build_cblc_index1(12, 12, 0, 1, 4, glyph_len, 1, 2)
  let maxp = bitmap_test_build_maxp(1)
  // NOTE: table records must be sorted by tag.
  let sfnt = bitmap_test_build_sfnt(
    Array::from_fixed_array([
      (0x45424454, ebdt), // "EBDT"
      (0x45424C43, eblc), // "EBLC"
      (0x6D617870, maxp), // "maxp"
    ]),
  )
  let font = @swash.FontRef::from_offset(sfnt, 0).unwrap()
  let cx = ScaleContext::new()
  let scaler = cx.builder(font).size(12.0).build()
  let img = scaler.scale_bitmap((0).to_uint16(), StrikeWith::ExactSize).unwrap()
  inspect(
    match img.source() {
      Bitmap(_) => true
      _ => false
    },
    content="true",
  )
  inspect(
    match img.content() {
      Mask => true
      _ => false
    },
    content="true",
  )
  let p = img.placement()
  inspect(p.left, content="-1")
  inspect(p.top, content="2")
  inspect(p.width, content="8")
  inspect(p.height, content="1")
  let data = img.data()
  inspect(data.length(), content="8")
  inspect(data[0].to_int(), content="255")
  inspect(data[1].to_int(), content="0")
  inspect(data[2].to_int(), content="255")
  inspect(data[3].to_int(), content="0")
  inspect(data[4].to_int(), content="255")
  inspect(data[5].to_int(), content="0")
  inspect(data[6].to_int(), content="255")
  inspect(data[7].to_int(), content="0")
}
