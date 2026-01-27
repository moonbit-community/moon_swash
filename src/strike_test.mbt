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
fn strike_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn strike_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn strike_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn strike_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  // Caller must provide tags in sorted order for internal table_range binary search.
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  strike_test_push_u32_be(out, strike_test_u32(0x00010000))
  strike_test_push_u16_be(out, num_tables)
  strike_test_push_u16_be(out, 0)
  strike_test_push_u16_be(out, 0)
  strike_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    strike_test_push_u32_be(out, tag)
    strike_test_push_u32_be(out, strike_test_u32(0))
    strike_test_push_u32_be(out, strike_test_u32(offset))
    strike_test_push_u32_be(out, strike_test_u32(data.length()))
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
fn strike_test_build_maxp(num_glyphs : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  strike_test_push_u32_be(out, strike_test_u32(0x00010000))
  strike_test_push_u16_be(out, num_glyphs)
  Bytes::from_array(out.op_as_view())
}

///|
fn strike_test_build_sbix_two_strikes() -> Bytes {
  let out : Array[Byte] = Array::new()
  // sbix header
  strike_test_push_u16_be(out, 1) // version
  strike_test_push_u16_be(out, 0) // flags
  strike_test_push_u32_be(out, strike_test_u32(2)) // numStrikes
  // strikeOffsets (2 entries): header(8) + offsets(8) = 16, strike0 len=20 => strike1 at 36
  strike_test_push_u32_be(out, strike_test_u32(16))
  strike_test_push_u32_be(out, strike_test_u32(36))
  // strike0 @16: ppem=16, ppi=144
  strike_test_push_u16_be(out, 16)
  strike_test_push_u16_be(out, 144)
  // glyphDataOffsets[2] for 1 glyph: [12, 20]
  strike_test_push_u32_be(out, strike_test_u32(12))
  strike_test_push_u32_be(out, strike_test_u32(20))
  // glyph record: origin_x=1, origin_y=2, graphicType="png "
  strike_test_push_u16_be(out, 1)
  strike_test_push_u16_be(out, 2)
  strike_test_push_u32_be(out, 0x706E6720) // "png "
  // strike1 @36: ppem=32, ppi=72
  strike_test_push_u16_be(out, 32)
  strike_test_push_u16_be(out, 72)
  strike_test_push_u32_be(out, strike_test_u32(12))
  strike_test_push_u32_be(out, strike_test_u32(20))
  strike_test_push_u16_be(out, 3)
  strike_test_push_u16_be(out, 4)
  strike_test_push_u32_be(out, 0x706E6720) // "png "
  Bytes::from_array(out.op_as_view())
}

///|
fn strike_test_build_cblc_index1(
  ppem_x : Int,
  ppem_y : Int,
  glyph_id : Int,
  bit_depth : Int,
  major : Int,
) -> Bytes {
  let out : Array[Byte] = Array::new()
  // major/minor
  strike_test_push_u16_be(out, major)
  strike_test_push_u16_be(out, 0)
  // numSizes = 1
  strike_test_push_u32_be(out, strike_test_u32(1))
  // BitmapSizeTable (48 bytes)
  strike_test_push_u32_be(out, strike_test_u32(56)) // indexSubTableArrayOffset
  strike_test_push_u32_be(out, strike_test_u32(24)) // indexTablesSize
  strike_test_push_u32_be(out, strike_test_u32(1)) // numberOfIndexSubTables
  strike_test_push_u32_be(out, strike_test_u32(0)) // colorRef
  for _ in 0..<24 {
    out.push(0 |> Int::to_byte)
  }
  strike_test_push_u16_be(out, glyph_id)
  strike_test_push_u16_be(out, glyph_id)
  out.push(ppem_x |> Int::to_byte)
  out.push(ppem_y |> Int::to_byte)
  out.push(bit_depth |> Int::to_byte)
  out.push(0 |> Int::to_byte)
  // IndexSubTableArray at offset 56
  strike_test_push_u16_be(out, glyph_id)
  strike_test_push_u16_be(out, glyph_id)
  strike_test_push_u32_be(out, strike_test_u32(64))
  // IndexSubTable1 at offset 64 (unused by contains)
  strike_test_push_u16_be(out, 1)
  strike_test_push_u16_be(out, 1)
  strike_test_push_u32_be(out, strike_test_u32(4))
  strike_test_push_u32_be(out, strike_test_u32(0))
  strike_test_push_u32_be(out, strike_test_u32(0))
  Bytes::from_array(out.op_as_view())
}

///|
fn strike_test_dummy_table(len : Int) -> Bytes {
  Bytes::from_array(Array::makei(len, _ => b'\x00').op_as_view())
}

///|
test "FontRef::alpha_strikes parses EBLC strike metadata + coverage" {
  let ebdt = strike_test_dummy_table(4)
  let eblc = strike_test_build_cblc_index1(12, 12, 0, 1, 2)
  // NOTE: table records must be sorted by tag.
  let sfnt = strike_test_build_sfnt(
    Array::from_fixed_array([
        (0x45424454, ebdt), // "EBDT"
        (0x45424C43, eblc),
      ], // "EBLC"
    ),
  )
  let font = FontRef::from_offset(sfnt, 0).unwrap()
  let strikes = font.alpha_strikes()
  inspect(strikes.len(), content="1")
  let s0 = strikes.iter().next().unwrap()
  inspect(s0.ppi().to_int(), content="72")
  inspect(s0.ppem().to_int(), content="12")
  inspect(s0.bit_depth().to_int(), content="1")
  inspect(s0.contains((0).to_uint16()), content="true")
  inspect(s0.contains((1).to_uint16()), content="false")
}

///|
test "FontRef::color_strikes parses sbix strikes + find helpers" {
  let maxp = strike_test_build_maxp(1)
  let sbix = strike_test_build_sbix_two_strikes()
  let sfnt = strike_test_build_sfnt(
    Array::from_fixed_array([(0x6D617870, maxp), (0x73626978, sbix)]),
  )
  let font = FontRef::from_offset(sfnt, 0).unwrap()
  let strikes = font.color_strikes()
  inspect(strikes.len(), content="2")
  let exact = strikes
    .find_by_exact_ppem((16).to_uint16(), (0).to_uint16())
    .unwrap()
  inspect(exact.ppem().to_int(), content="16")
  inspect(exact.ppi().to_int(), content="144")
  let near = strikes
    .find_by_nearest_ppem((18).to_uint16(), (0).to_uint16())
    .unwrap()
  inspect(near.ppem().to_int(), content="32")
  let largest = strikes.find_by_largest_ppem((0).to_uint16()).unwrap()
  inspect(largest.ppem().to_int(), content="32")
}

///|
test "BitmapStrikesProxy prefers CBLC/CBDT when sbix missing" {
  let cbdt = strike_test_dummy_table(4)
  let cblc = strike_test_build_cblc_index1(20, 20, 0, 8, 3)
  let sfnt = strike_test_build_sfnt(
    Array::from_fixed_array([
        (0x43424454, cbdt), // "CBDT"
        (0x43424C43, cblc),
      ], // "CBLC"
    ),
  )
  let font = FontRef::from_offset(sfnt, 0).unwrap()
  let proxy = BitmapStrikesProxy::from_font(font)
  inspect(proxy.has_alpha(), content="false")
  inspect(proxy.has_color(), content="true")
  let strikes = proxy.materialize_color(font)
  let s0 = strikes.iter().next().unwrap()
  inspect(s0.ppem().to_int(), content="20")
  inspect(s0.ppi().to_int(), content="72")
  inspect(s0.bit_depth().to_int(), content="8")
  inspect(s0.contains((0).to_uint16()), content="true")
}
