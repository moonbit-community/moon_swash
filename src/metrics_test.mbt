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
fn metrics_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn metrics_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn metrics_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn metrics_test_set_u16_be(buf : Array[Byte], off : Int, v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  buf[off] = ((u >> 8) & mask).to_byte()
  buf[off + 1] = (u & mask).to_byte()
}

///|
fn metrics_test_set_u32_be(buf : Array[Byte], off : Int, v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  buf[off] = ((v >> 24) & mask).to_byte()
  buf[off + 1] = ((v >> 16) & mask).to_byte()
  buf[off + 2] = ((v >> 8) & mask).to_byte()
  buf[off + 3] = (v & mask).to_byte()
}

///|
fn metrics_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  // Caller must provide tags in sorted order for internal table_range binary search.
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  metrics_test_push_u32_be(out, metrics_test_u32(0x00010000))
  metrics_test_push_u16_be(out, num_tables)
  metrics_test_push_u16_be(out, 0)
  metrics_test_push_u16_be(out, 0)
  metrics_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    metrics_test_push_u32_be(out, tag)
    metrics_test_push_u32_be(out, metrics_test_u32(0))
    metrics_test_push_u32_be(out, metrics_test_u32(offset))
    metrics_test_push_u32_be(out, metrics_test_u32(data.length()))
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
fn metrics_test_make_head(units_per_em : Int, loca_fmt : Int) -> Bytes {
  let buf : Array[Byte] = Array::makei(54, _ => b'\x00')
  metrics_test_set_u16_be(buf, 18, units_per_em)
  metrics_test_set_u16_be(buf, 50, loca_fmt)
  Bytes::from_array(buf.op_as_view())
}

///|
fn metrics_test_make_maxp(num_glyphs : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  metrics_test_push_u32_be(out, metrics_test_u32(0x00010000))
  metrics_test_push_u16_be(out, num_glyphs)
  Bytes::from_array(out.op_as_view())
}

///|
fn metrics_test_make_hhea(
  ascender : Int,
  descender : Int,
  line_gap : Int,
  max_advance : Int,
  num_long : Int,
) -> Bytes {
  let buf : Array[Byte] = Array::makei(36, _ => b'\x00')
  metrics_test_set_u16_be(buf, 4, ascender)
  metrics_test_set_u16_be(buf, 6, descender)
  metrics_test_set_u16_be(buf, 8, line_gap)
  metrics_test_set_u16_be(buf, 10, max_advance)
  metrics_test_set_u16_be(buf, 34, num_long)
  Bytes::from_array(buf.op_as_view())
}

///|
fn metrics_test_make_vhea(
  ascender : Int,
  descender : Int,
  line_gap : Int,
  max_advance : Int,
  num_long : Int,
) -> Bytes {
  metrics_test_make_hhea(ascender, descender, line_gap, max_advance, num_long)
}

///|
fn metrics_test_make_hmtx(advance : Int, lsb : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  metrics_test_push_u16_be(out, advance)
  metrics_test_push_u16_be(out, lsb)
  Bytes::from_array(out.op_as_view())
}

///|
fn metrics_test_make_vmtx(advance : Int, tsb : Int) -> Bytes {
  metrics_test_make_hmtx(advance, tsb)
}

///|
fn metrics_test_make_post(
  underline_pos : Int,
  underline_size : Int,
  fixed_pitch : Bool,
) -> Bytes {
  let buf : Array[Byte] = Array::makei(16, _ => b'\x00')
  metrics_test_set_u16_be(buf, 8, underline_pos)
  metrics_test_set_u16_be(buf, 10, underline_size)
  metrics_test_set_u32_be(
    buf,
    12,
    metrics_test_u32(if fixed_pitch { 1 } else { 0 }),
  )
  Bytes::from_array(buf.op_as_view())
}

///|
fn metrics_test_make_os2_typo(
  avg_width : Int,
  strikeout_pos : Int,
  strikeout_size : Int,
  typo_asc : Int,
  typo_desc : Int,
  typo_gap : Int,
  x_height : Int,
  cap_height : Int,
) -> Bytes {
  let buf : Array[Byte] = Array::makei(96, _ => b'\x00')
  // version=2
  metrics_test_set_u16_be(buf, 0, 2)
  metrics_test_set_u16_be(buf, 2, avg_width)
  metrics_test_set_u16_be(buf, 26, strikeout_size)
  metrics_test_set_u16_be(buf, 28, strikeout_pos)
  // fsSelection bit 7: use typographic metrics.
  metrics_test_set_u16_be(buf, 62, 0x0080)
  metrics_test_set_u16_be(buf, 68, typo_asc)
  metrics_test_set_u16_be(buf, 70, typo_desc)
  metrics_test_set_u16_be(buf, 72, typo_gap)
  metrics_test_set_u16_be(buf, 86, x_height)
  metrics_test_set_u16_be(buf, 88, cap_height)
  Bytes::from_array(buf.op_as_view())
}

///|
fn metrics_test_make_hvar_delta_50() -> Bytes {
  // Same minimal HVAR layout as moon_skrifa tests: +50 deltas when coord == 1.0.
  let out : Array[Byte] = Array::new()
  // version 1.0
  metrics_test_push_u16_be(out, 1)
  metrics_test_push_u16_be(out, 0)
  // itemVariationStoreOffset = 20
  metrics_test_push_u32_be(out, metrics_test_u32(20))
  // advanceWidthMappingOffset = 52 (after store)
  metrics_test_push_u32_be(out, metrics_test_u32(52))
  // lsbMappingOffset = 52
  metrics_test_push_u32_be(out, metrics_test_u32(52))
  // rsbMappingOffset = 0
  metrics_test_push_u32_be(out, metrics_test_u32(0))

  // ItemVariationStore at offset 20
  metrics_test_push_u16_be(out, 1) // format
  metrics_test_push_u32_be(out, metrics_test_u32(12)) // variationRegionListOffset
  metrics_test_push_u16_be(out, 1) // itemVariationDataCount
  metrics_test_push_u32_be(out, metrics_test_u32(22)) // itemVariationDataOffsets[0]

  // VariationRegionList at 20 + 12 = 32
  metrics_test_push_u16_be(out, 1) // axisCount
  metrics_test_push_u16_be(out, 1) // regionCount
  // Region 0: start=0, peak=1.0, end=1.0 (F2Dot14)
  metrics_test_push_u16_be(out, 0)
  metrics_test_push_u16_be(out, 16384)
  metrics_test_push_u16_be(out, 16384)

  // ItemVariationData at 20 + 22 = 42
  metrics_test_push_u16_be(out, 1) // itemCount
  metrics_test_push_u16_be(out, 1) // shortDeltaCount
  metrics_test_push_u16_be(out, 1) // regionIndexCount
  metrics_test_push_u16_be(out, 0) // regionIndexes[0]
  metrics_test_push_u16_be(out, 50) // deltaSets[0][0]

  // DeltaSetIndexMap at offset 52: entrySize=2, innerBits=8, mapCount=1, entry=0
  metrics_test_push_u16_be(out, 0x0017)
  metrics_test_push_u16_be(out, 1)
  metrics_test_push_u16_be(out, 0)
  Bytes::from_array(out.op_as_view())
}

///|
fn metrics_test_make_mvar_hasc_delta_10() -> Bytes {
  // MVAR header: version(1.0), reserved, valueRecordSize=8, valueRecordCount=1, storeOffset=20
  let out : Array[Byte] = Array::new()
  metrics_test_push_u32_be(out, metrics_test_u32(0x00010000))
  metrics_test_push_u16_be(out, 0) // reserved
  metrics_test_push_u16_be(out, 8) // valueRecordSize
  metrics_test_push_u16_be(out, 1) // valueRecordCount
  metrics_test_push_u16_be(out, 20) // itemVariationStoreOffset
  // ValueRecord[0]: tag=HASC, outer=0, inner=0
  metrics_test_push_u32_be(out, @internal.HASC)
  metrics_test_push_u16_be(out, 0)
  metrics_test_push_u16_be(out, 0)

  // ItemVariationStore at offset 20 (same as HVAR test, but delta=+10)
  metrics_test_push_u16_be(out, 1) // format
  metrics_test_push_u32_be(out, metrics_test_u32(12)) // variationRegionListOffset
  metrics_test_push_u16_be(out, 1) // itemVariationDataCount
  metrics_test_push_u32_be(out, metrics_test_u32(22)) // itemVariationDataOffsets[0]

  // VariationRegionList at 20 + 12 = 32
  metrics_test_push_u16_be(out, 1) // axisCount
  metrics_test_push_u16_be(out, 1) // regionCount
  metrics_test_push_u16_be(out, 0) // start
  metrics_test_push_u16_be(out, 16384) // peak
  metrics_test_push_u16_be(out, 16384) // end

  // ItemVariationData at 20 + 22 = 42
  metrics_test_push_u16_be(out, 1) // itemCount
  metrics_test_push_u16_be(out, 1) // shortDeltaCount
  metrics_test_push_u16_be(out, 1) // regionIndexCount
  metrics_test_push_u16_be(out, 0) // regionIndexes[0]
  metrics_test_push_u16_be(out, 10) // deltaSets[0][0]
  Bytes::from_array(out.op_as_view())
}

///|
fn metrics_test_make_vorg(default_origin : Int, glyph0_origin : Int) -> Bytes {
  let out : Array[Byte] = Array::new()
  metrics_test_push_u16_be(out, 1) // major
  metrics_test_push_u16_be(out, 0) // minor
  metrics_test_push_u16_be(out, default_origin) // defaultVertOriginY (i16)
  metrics_test_push_u16_be(out, 1) // numVertOriginYMetrics
  metrics_test_push_u16_be(out, 0) // glyphIndex
  metrics_test_push_u16_be(out, glyph0_origin) // vertOriginY (i16)
  Bytes::from_array(out.op_as_view())
}

///|
test "MetricsProxy materialize_metrics reads OS/2/post and synthesizes vertical metrics" {
  let sfnt = metrics_test_build_sfnt(
    Array::from_fixed_array([
      (
        @internal.OS_2,
        metrics_test_make_os2_typo(500, 50, 10, 800, -200, 100, 400, 700),
      ),
      (@internal.HEAD, metrics_test_make_head(1000, 0)),
      (@internal.HHEA, metrics_test_make_hhea(900, -250, 20, 1200, 1)),
      (@internal.HMTX, metrics_test_make_hmtx(1100, -10)),
      (@internal.MAXP, metrics_test_make_maxp(2)),
      (@internal.POST, metrics_test_make_post(-100, 20, true)),
    ]),
  )
  let font = FontRef::from_offset(sfnt, 0).unwrap()
  let proxy = MetricsProxy::from_font(font)
  let m = proxy.materialize_metrics(font, ([] : Array[Int]).op_as_view())
  inspect(m.units_per_em, content="1000")
  inspect(m.glyph_count, content="2")
  inspect(m.is_monospace, content="true")
  inspect(m.has_vertical_metrics, content="false")
  inspect(m.ascent.to_int(), content="800")
  inspect(m.descent.to_int(), content="200")
  inspect(m.leading.to_int(), content="100")
  inspect(m.vertical_ascent.to_int(), content="500")
  inspect(m.vertical_descent.to_int(), content="500")
  inspect(m.max_width.to_int(), content="1200")
  inspect(m.underline_offset.to_int(), content="-100")
  inspect(m.stroke_size.to_int(), content="20")
}

///|
test "GlyphMetrics applies HVAR deltas when coords are non-zero" {
  let sfnt = metrics_test_build_sfnt(
    Array::from_fixed_array([
      (@internal.HVAR, metrics_test_make_hvar_delta_50()),
      (@internal.HEAD, metrics_test_make_head(1000, 0)),
      (@internal.HHEA, metrics_test_make_hhea(0, 0, 0, 0, 1)),
      (@internal.HMTX, metrics_test_make_hmtx(500, 10)),
      (@internal.MAXP, metrics_test_make_maxp(1)),
    ]),
  )
  let font = FontRef::from_offset(sfnt, 0).unwrap()
  let gm0 = font.glyph_metrics(([] : Array[Int]).op_as_view())
  inspect(gm0.advance_width((0).to_uint16()).to_int(), content="500")
  inspect(gm0.lsb((0).to_uint16()).to_int(), content="10")
  let coords = Array::from_fixed_array([16384])
  let gm1 = font.glyph_metrics(coords.op_as_view())
  inspect(gm1.advance_width((0).to_uint16()).to_int(), content="550")
  inspect(gm1.lsb((0).to_uint16()).to_int(), content="60")
}

///|
test "MetricsProxy applies MVAR deltas to ascent" {
  let sfnt = metrics_test_build_sfnt(
    Array::from_fixed_array([
      (@internal.MVAR, metrics_test_make_mvar_hasc_delta_10()),
      (@internal.OS_2, metrics_test_make_os2_typo(0, 0, 0, 800, -200, 0, 0, 0)),
      (@internal.HEAD, metrics_test_make_head(1000, 0)),
      (@internal.HHEA, metrics_test_make_hhea(0, 0, 0, 0, 1)),
      (@internal.HMTX, metrics_test_make_hmtx(0, 0)),
      (@internal.MAXP, metrics_test_make_maxp(1)),
    ]),
  )
  let font = FontRef::from_offset(sfnt, 0).unwrap()
  let proxy = MetricsProxy::from_font(font)
  let coords = Array::from_fixed_array([16384])
  let m = proxy.materialize_metrics(font, coords.op_as_view())
  inspect(m.ascent.to_int(), content="810")
}

///|
test "GlyphMetrics uses VMTX+VORG for vertical metrics when present" {
  let sfnt = metrics_test_build_sfnt(
    Array::from_fixed_array([
      (@internal.VORG, metrics_test_make_vorg(900, 850)),
      (@internal.HEAD, metrics_test_make_head(1000, 0)),
      (@internal.HHEA, metrics_test_make_hhea(0, 0, 0, 0, 1)),
      (@internal.HMTX, metrics_test_make_hmtx(0, 0)),
      (@internal.MAXP, metrics_test_make_maxp(1)),
      (@internal.VHEA, metrics_test_make_vhea(0, 0, 0, 0, 1)),
      (@internal.VMTX, metrics_test_make_vmtx(800, 20)),
    ]),
  )
  let font = FontRef::from_offset(sfnt, 0).unwrap()
  let gm = font.glyph_metrics(([] : Array[Int]).op_as_view())
  inspect(gm.has_vertical_metrics(), content="true")
  inspect(gm.advance_height((0).to_uint16()).to_int(), content="800")
  inspect(gm.tsb((0).to_uint16()).to_int(), content="20")
  inspect(gm.vertical_origin((0).to_uint16()).to_int(), content="850")
}
