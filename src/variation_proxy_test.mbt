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
fn variation_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn variation_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn variation_test_set_u16_be(buf : Array[Byte], off : Int, v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  buf[off] = ((u >> 8) & mask).to_byte()
  buf[off + 1] = (u & mask).to_byte()
}

///|
fn variation_test_set_i16_be(buf : Array[Byte], off : Int, v : Int) -> Unit {
  let u = if v < 0 { v + 0x10000 } else { v }
  variation_test_set_u16_be(buf, off, u)
}

///|
fn variation_test_set_u32_be(buf : Array[Byte], off : Int, v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  buf[off] = ((v >> 24) & mask).to_byte()
  buf[off + 1] = ((v >> 16) & mask).to_byte()
  buf[off + 2] = ((v >> 8) & mask).to_byte()
  buf[off + 3] = (v & mask).to_byte()
}

///|
fn variation_test_fixed_16_16(x : Int) -> UInt {
  x.reinterpret_as_uint() << 16
}

///|
fn variation_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  // Caller must provide tags in sorted order for internal table_range binary search.
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  variation_test_push_u32_be(out, 0x00010000) // sfnt version
  variation_test_push_u16_be(out, num_tables)
  variation_test_push_u16_be(out, 0)
  variation_test_push_u16_be(out, 0)
  variation_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    variation_test_push_u32_be(out, tag)
    variation_test_push_u32_be(out, 0) // checksum
    variation_test_push_u32_be(out, offset.reinterpret_as_uint())
    variation_test_push_u32_be(out, data.length().reinterpret_as_uint())
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
fn variation_test_make_fvar_one_axis_wght() -> Bytes {
  // fvar header (16) + 1 axis record (20) + 1 instance record (10)
  let buf : Array[Byte] = Array::makei(46, _ => b'\x00')
  // version 1.0 (major/minor)
  variation_test_set_u16_be(buf, 0, 1)
  variation_test_set_u16_be(buf, 2, 0)
  // axesOffset=16, axisCount=1, axisSize=20, instanceCount=1, instanceSize=10
  variation_test_set_u16_be(buf, 4, 16)
  variation_test_set_u16_be(buf, 8, 1)
  variation_test_set_u16_be(buf, 10, 20)
  variation_test_set_u16_be(buf, 12, 1)
  variation_test_set_u16_be(buf, 14, 10)

  // Axis record at 16
  variation_test_set_u32_be(buf, 16, 0x77676874) // "wght"
  variation_test_set_u32_be(buf, 20, variation_test_fixed_16_16(100))
  variation_test_set_u32_be(buf, 24, variation_test_fixed_16_16(400))
  variation_test_set_u32_be(buf, 28, variation_test_fixed_16_16(900))
  variation_test_set_u16_be(buf, 32, 0) // flags
  variation_test_set_u16_be(buf, 34, 256) // nameId

  // Instance record at 36
  variation_test_set_u16_be(buf, 36, 300) // subfamilyNameID
  variation_test_set_u16_be(buf, 38, 0) // flags
  variation_test_set_u32_be(buf, 40, variation_test_fixed_16_16(650))
  // optional postScriptNameID (not relied upon in tests)
  variation_test_set_u16_be(buf, 44, 301)
  Bytes::from_array(buf.op_as_view())
}

///|
fn variation_test_make_avar_remap_half_to_quarter() -> Bytes {
  // Header (8) + offset array (2) + axis map:
  // mapCount (2) + 3 entries (12) = 24 bytes total.
  let buf : Array[Byte] = Array::makei(24, _ => b'\x00')
  // major/minor
  variation_test_set_u16_be(buf, 0, 1)
  variation_test_set_u16_be(buf, 2, 0)
  // axisCount=1, reserved=0
  variation_test_set_u16_be(buf, 4, 1)
  variation_test_set_u16_be(buf, 6, 0)
  // axisSegmentMapOffset[0] = 10
  variation_test_set_u16_be(buf, 8, 10)
  // Axis segment map at 10
  variation_test_set_u16_be(buf, 10, 3) // positionMapCount
  // (-1 -> -1)
  variation_test_set_i16_be(buf, 12, -16384)
  variation_test_set_i16_be(buf, 14, -16384)
  // (0.5 -> 0.25)
  variation_test_set_i16_be(buf, 16, 8192)
  variation_test_set_i16_be(buf, 18, 4096)
  // (1 -> 1)
  variation_test_set_i16_be(buf, 20, 16384)
  variation_test_set_i16_be(buf, 22, 16384)
  Bytes::from_array(buf.op_as_view())
}

///|
test "VariationsProxy: materialize + find_by_tag + normalized_coords" {
  let fvar = variation_test_make_fvar_one_axis_wght()
  let font_data = variation_test_build_sfnt([
      // tags must be sorted
      (0x66766172, fvar),
    ], // "fvar"
  )
  let font = FontRef::from_offset(font_data, 0).unwrap()
  let proxy = VariationsProxy::from_font(font)
  let vars = proxy.materialize(font)
  let axis = vars.find_by_tag(0x77676874).unwrap()
  inspect(axis.normalize(650.0), content="8192")
  let settings : Array[VariationSetting] = [Setting::new(0x77676874, 650.0)]
  inspect(vars.normalized_coords(settings.iter()).to_array(), content="[8192]")
}

///|
test "AVAR remapping affects Variation.normalize" {
  let avar = variation_test_make_avar_remap_half_to_quarter()
  let fvar = variation_test_make_fvar_one_axis_wght()
  let font_data = variation_test_build_sfnt([
    (0x61766172, avar), // "avar"
    (0x66766172, fvar), // "fvar"
  ])
  let font = FontRef::from_offset(font_data, 0).unwrap()
  let axis = font.variations().find_by_tag(0x77676874).unwrap()
  // 650 maps to 0.5; avar remaps 0.5 -> 0.25.
  inspect(axis.normalize(650.0), content="4096")
}
