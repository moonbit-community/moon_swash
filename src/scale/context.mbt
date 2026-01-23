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
/// Scaling context and scaler scaffolding.
///
/// Port intent: align with upstream `swash::scale::ScaleContext/ScalerBuilder/Scaler`.
/// This is currently a functional skeleton: it provides the public API shape,
/// but does not yet implement actual outline extraction, hinting, or rasterization.

///|
pub struct ScaleContext {}

///|
pub fn ScaleContext::new() -> ScaleContext {
  ScaleContext::{}
}

///|
pub fn ScaleContext::builder(_self : ScaleContext, font : @swash.FontRef) -> ScalerBuilder {
  ScalerBuilder::{ font, size: 0.0, hint: false }
}

///|
/// Builder for configuring a scaler.
pub struct ScalerBuilder {
  font : @swash.FontRef
  size : Double
  hint : Bool
}

///|
pub fn ScalerBuilder::size(self : ScalerBuilder, ppem : Double) -> ScalerBuilder {
  ScalerBuilder::{ font: self.font, size: if ppem < 0.0 { 0.0 } else { ppem }, hint: self.hint }
}

///|
pub fn ScalerBuilder::hint(self : ScalerBuilder, yes : Bool) -> ScalerBuilder {
  ScalerBuilder::{ font: self.font, size: self.size, hint: yes }
}

///|
pub fn ScalerBuilder::build(self : ScalerBuilder) -> Scaler {
  Scaler::{ font: self.font, size: self.size, hint: self.hint }
}

///|
pub struct Scaler {
  font : @swash.FontRef
  size : Double
  hint : Bool
}

///|
pub fn Scaler::size(self : Scaler) -> Double {
  self.size
}

///|
pub fn Scaler::hint(self : Scaler) -> Bool {
  self.hint
}

///|
pub fn Scaler::scale_outline(_self : Scaler, _glyph_id : @swash.GlyphId) -> Outline? {
  // NOTE: Upstream swash uses skrifa for outline extraction. Per current plan,
  // we decode TrueType glyf outlines directly from font tables for now.
  let self = _self
  let glyph_id = _glyph_id

  let head = match @internal.Head::from_font(self.font) {
    None => return None
    Some(h) => h
  }
  let units_per_em = head.units_per_em()
  if units_per_em == 0 {
    return None
  }
  let scale = if self.size <= 0.0 { 1.0 } else { self.size / units_per_em.to_double() }

  let loca_fmt = head.index_to_location_format()
  let loca = @internal.table_offset(self.font, @internal.LOCA)
  let glyf = @internal.table_offset(self.font, @internal.GLYF)
  if loca == 0 || glyf == 0 {
    return None
  }
  decode_glyph_outline(self.font.data(), loca_fmt, loca, glyf, glyph_id, scale, 0)
}

test "ScaleContext builder scaffolding" {
  // Minimal TTF header tag 0x00010000 is enough for FontRef::from_offset.
  let data = Bytes::from_array([0, 1, 0, 0])
  let font = @swash.FontRef::from_offset(data, 0).unwrap()
  let cx = ScaleContext::new()
  let scaler = cx.builder(font).size(14.0).hint(true).build()
  inspect(scaler.size().to_int(), content="14")
  inspect(scaler.hint(), content="true")
}

fn read_u16_or_none(s : @internal.Stream) -> UInt? { s.read_u16() }
fn read_i16_or_none(s : @internal.Stream) -> Int? { s.read_i16() }
fn read_u8_or_none(s : @internal.Stream) -> Byte? { s.read_u8() }

fn read_f2dot14_or_none(s : @internal.Stream) -> Double? {
  read_i16_or_none(s).map(v => v.to_double() / 16384.0)
}

fn u8_to_i8(v : UInt) -> Int {
  let i = v.reinterpret_as_int()
  if i >= 128 { i - 256 } else { i }
}

fn decode_glyph_outline(
  data : Bytes,
  loca_fmt : UInt,
  loca : UInt,
  glyf : UInt,
  glyph_id : UInt,
  scale : Double,
  depth : Int,
) -> Outline? {
  if depth > 16 {
    return None
  }
  let glyph_data = match @internal.get(data, loca_fmt, loca, glyf, glyph_id) {
    None => return None
    Some(v) => v
  }
  let s = @internal.Stream::from_view(glyph_data)
  let contours_i = match read_i16_or_none(s) {
    None => return None
    Some(v) => v
  }
  // Skip bounds (xMin,yMin,xMax,yMax).
  if !s.skip(8) {
    return None
  }
  if contours_i < 0 {
    return decode_compound_outline(data, loca_fmt, loca, glyf, s, scale, depth)
  }
  let contours = contours_i
  let end_pts : Array[Int] = []
  for _ in 0..<contours {
    let v = match read_u16_or_none(s) {
      None => return None
      Some(v) => v
    }
    end_pts.push(v.reinterpret_as_int())
  }
  if end_pts.length() == 0 {
    return Some(Outline::new())
  }
  let last_end = end_pts[end_pts.length() - 1]
  if last_end < 0 {
    return None
  }
  let point_count = last_end + 1

  let instr_len = match read_u16_or_none(s) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  if !s.skip(instr_len) {
    return None
  }

  // Flags (with repeat).
  let flags : Array[UInt] = []
  while flags.length() < point_count {
    let f = match read_u8_or_none(s) {
      None => return None
      Some(b) => b.to_int().reinterpret_as_uint()
    }
    if (f & 0x08) != 0 {
      let repeat = match read_u8_or_none(s) {
        None => return None
        Some(b) => b.to_int()
      }
      for _ in 0..<(repeat + 1) {
        flags.push(f)
      }
    } else {
      flags.push(f)
    }
  }
  if flags.length() != point_count {
    return None
  }

  // Coordinates are delta-encoded.
  let xs : Array[Int] = []
  let ys : Array[Int] = []
  let on_curve : Array[Bool] = []

  let mut x = 0
  for i in 0..<point_count {
    let f = flags[i]
    let dx = if (f & 0x02) != 0 {
      let b = match read_u8_or_none(s) {
        None => return None
        Some(v) => v.to_int()
      }
      if (f & 0x10) != 0 { b } else { -b }
    } else {
      if (f & 0x10) != 0 {
        0
      } else {
        match read_i16_or_none(s) {
          None => return None
          Some(v) => v
        }
      }
    }
    x = x + dx
    xs.push(x)
    on_curve.push((f & 0x01) != 0)
  }

  let mut y = 0
  for i in 0..<point_count {
    let f = flags[i]
    let dy = if (f & 0x04) != 0 {
      let b = match read_u8_or_none(s) {
        None => return None
        Some(v) => v.to_int()
      }
      if (f & 0x20) != 0 { b } else { -b }
    } else {
      if (f & 0x20) != 0 {
        0
      } else {
        match read_i16_or_none(s) {
          None => return None
          Some(v) => v
        }
      }
    }
    y = y + dy
    ys.push(y)
  }

  if xs.length() != point_count || ys.length() != point_count {
    return None
  }

  let pts : Array[@zeno.Point] = []
  for i in 0..<point_count {
    pts.push(
      @zeno.Vector::new(xs[i].to_double() * scale, ys[i].to_double() * scale),
    )
  }

  // Convert points (quadratic) to path verbs.
  let o = Outline::new()
  o.set_color(false)
  o.begin_layer(None)

  let mut start = 0
  for ci in 0..<end_pts.length() {
    let end = end_pts[ci]
    if end < start || end >= point_count {
      return None
    }
    emit_quadratic_contour(o, pts, on_curve, start, end)
    start = end + 1
  }
  o.finish()
  Some(o)
}

// TrueType compound glyph flags (subset).
const ARG_1_AND_2_ARE_WORDS : UInt = 0x0001
const ARGS_ARE_XY_VALUES : UInt = 0x0002
const WE_HAVE_A_SCALE : UInt = 0x0008
const MORE_COMPONENTS : UInt = 0x0020
const WE_HAVE_AN_X_AND_Y_SCALE : UInt = 0x0040
const WE_HAVE_A_TWO_BY_TWO : UInt = 0x0080

fn decode_compound_outline(
  data : Bytes,
  loca_fmt : UInt,
  loca : UInt,
  glyf : UInt,
  s : @internal.Stream,
  scale : Double,
  depth : Int,
) -> Outline? {
  let out = Outline::new()
  out.set_color(false)
  out.begin_layer(None)

  loop {
    let flags = match read_u16_or_none(s) {
      None => return None
      Some(v) => v
    }
    let gi_u = match read_u16_or_none(s) {
      None => return None
      Some(v) => v
    }
    let glyph_index = gi_u.reinterpret_as_uint()

    // Arguments: we only support XY offsets for now.
    let (dx_i, dy_i) : (Int, Int) = if (flags & ARGS_ARE_XY_VALUES) == 0 {
      return None
    } else if (flags & ARG_1_AND_2_ARE_WORDS) != 0 {
      let dx = match read_i16_or_none(s) {
        None => return None
        Some(v) => v
      }
      let dy = match read_i16_or_none(s) {
        None => return None
        Some(v) => v
      }
      (dx, dy)
    } else {
      let dx = match read_u8_or_none(s) {
        None => return None
        Some(v) => u8_to_i8(v.to_int().reinterpret_as_uint())
      }
      let dy = match read_u8_or_none(s) {
        None => return None
        Some(v) => u8_to_i8(v.to_int().reinterpret_as_uint())
      }
      (dx, dy)
    }

    // Component transform.
    let mut xx = 1.0
    let mut xy = 0.0
    let mut yx = 0.0
    let mut yy = 1.0

    if (flags & WE_HAVE_A_SCALE) != 0 {
      let s0 = match read_f2dot14_or_none(s) {
        None => return None
        Some(v) => v
      }
      xx = s0
      yy = s0
    } else if (flags & WE_HAVE_AN_X_AND_Y_SCALE) != 0 {
      xx = match read_f2dot14_or_none(s) {
        None => return None
        Some(v) => v
      }
      yy = match read_f2dot14_or_none(s) {
        None => return None
        Some(v) => v
      }
    } else if (flags & WE_HAVE_A_TWO_BY_TWO) != 0 {
      xx = match read_f2dot14_or_none(s) {
        None => return None
        Some(v) => v
      }
      xy = match read_f2dot14_or_none(s) {
        None => return None
        Some(v) => v
      }
      yx = match read_f2dot14_or_none(s) {
        None => return None
        Some(v) => v
      }
      yy = match read_f2dot14_or_none(s) {
        None => return None
        Some(v) => v
      }
    }

    let child = match decode_glyph_outline(data, loca_fmt, loca, glyf, glyph_index, scale, depth + 1) {
      None => return None
      Some(o) => o
    }

    let tx = dx_i.to_double() * scale
    let ty = dy_i.to_double() * scale
    append_outline_transformed(out, child, xx, xy, yx, yy, tx, ty)

    if (flags & MORE_COMPONENTS) == 0 {
      break
    }
  }
  out.finish()
  Some(out)
}

fn apply_affine(
  p : @zeno.Point,
  xx : Double,
  xy : Double,
  yx : Double,
  yy : Double,
  tx : Double,
  ty : Double,
) -> @zeno.Point {
  @zeno.Vector::new(p.x() * xx + p.y() * yx + tx, p.x() * xy + p.y() * yy + ty)
}

fn append_outline_transformed(
  dst : Outline,
  src : Outline,
  xx : Double,
  xy : Double,
  yx : Double,
  yy : Double,
  tx : Double,
  ty : Double,
) -> Unit {
  let points = src.points()
  let verbs = src.verbs()
  let mut p = 0
  for v in verbs {
    match v {
      MoveTo => {
        dst.move_to(apply_affine(points[p], xx, xy, yx, yy, tx, ty))
        p = p + 1
      }
      LineTo => {
        dst.line_to(apply_affine(points[p], xx, xy, yx, yy, tx, ty))
        p = p + 1
      }
      QuadTo => {
        dst.quad_to(
          apply_affine(points[p], xx, xy, yx, yy, tx, ty),
          apply_affine(points[p + 1], xx, xy, yx, yy, tx, ty),
        )
        p = p + 2
      }
      CurveTo => {
        dst.curve_to(
          apply_affine(points[p], xx, xy, yx, yy, tx, ty),
          apply_affine(points[p + 1], xx, xy, yx, yy, tx, ty),
          apply_affine(points[p + 2], xx, xy, yx, yy, tx, ty),
        )
        p = p + 3
      }
      Close => dst.close()
    }
  }
}

fn midpoint(a : @zeno.Point, b : @zeno.Point) -> @zeno.Point {
  @zeno.Vector::new((a.x() + b.x()) * 0.5, (a.y() + b.y()) * 0.5)
}

fn emit_quadratic_contour(
  out : Outline,
  pts : Array[@zeno.Point],
  on_curve : Array[Bool],
  start : Int,
  end : Int,
) -> Unit {
  let first = pts[start]
  let last = pts[end]
  let first_on = on_curve[start]
  let last_on = on_curve[end]

  let start_index_opt : Option[Int] = if first_on {
    Some(start)
  } else if last_on {
    Some(end)
  } else {
    None
  }
  let start_point = match start_index_opt {
    None => midpoint(last, first)
    Some(i) => pts[i]
  }

  out.move_to(start_point)

  let mut prev_off : Option[@zeno.Point] = None
  let total = end - start + 1
  let mut remaining = total
  let mut idx = start
  match start_index_opt {
    None => ()
    Some(i) => {
      // Skip the MoveTo point if it is an actual point from the contour.
      remaining = remaining - 1
      idx = if i == start { start + 1 } else { start }
    }
  }

  for _ in 0..<remaining {
    let p = pts[idx]
    let on = on_curve[idx]
    idx = idx + 1
    if on {
      match prev_off {
        None => out.line_to(p)
        Some(c) => {
          out.quad_to(c, p)
          prev_off = None
        }
      }
    } else {
      match prev_off {
        None => prev_off = Some(p)
        Some(c) => {
          let m = midpoint(c, p)
          out.quad_to(c, m)
          prev_off = Some(p)
        }
      }
    }
  }

  // Finish to start.
  match prev_off {
    None => ()
    Some(c) => out.quad_to(c, start_point)
  }
  out.close()
}

fn mk_min_ttf_with_one_simple_glyph() -> Bytes {
  // Table directory with 3 tables: glyf, head, loca (sorted by tag).
  // Offsets: glyf=0x80 len=30, head=0xA0 len=54, loca=0xE0 len=4.
  let total = 0xE0 + 4
  Bytes::makei(total, i => {
    // sfntVersion 0x00010000
    if i == 0 { b'\x00' } else if i == 1 { b'\x01' } else if i == 2 { b'\x00' } else if i == 3 {
      b'\x00'
    } else if i == 4 { b'\x00' } else if i == 5 { b'\x03' } // numTables=3

    // record 0: "glyf"
    else if i == 12 { b'g' } else if i == 13 { b'l' } else if i == 14 { b'y' } else if i == 15 {
      b'f'
    } else if i == 20 { b'\x00' } else if i == 21 { b'\x00' } else if i == 22 {
      b'\x00'
    } else if i == 23 { b'\x80' } // offset 0x80
    else if i == 24 { b'\x00' } else if i == 25 { b'\x00' } else if i == 26 {
      b'\x00'
    } else if i == 27 { b'\x1E' } // len 30

    // record 1: "head"
    else if i == 28 { b'h' } else if i == 29 { b'e' } else if i == 30 { b'a' } else if i == 31 {
      b'd'
    } else if i == 36 { b'\x00' } else if i == 37 { b'\x00' } else if i == 38 {
      b'\x00'
    } else if i == 39 { b'\xA0' } // offset 0xA0
    else if i == 40 { b'\x00' } else if i == 41 { b'\x00' } else if i == 42 {
      b'\x00'
    } else if i == 43 { b'\x36' } // len 54

    // record 2: "loca"
    else if i == 44 { b'l' } else if i == 45 { b'o' } else if i == 46 { b'c' } else if i == 47 {
      b'a'
    } else if i == 52 { b'\x00' } else if i == 53 { b'\x00' } else if i == 54 {
      b'\x00'
    } else if i == 55 { b'\xE0' } // offset 0xE0
    else if i == 56 { b'\x00' } else if i == 57 { b'\x00' } else if i == 58 {
      b'\x00'
    } else if i == 59 { b'\x04' } // len 4

    // glyf glyph at 0x80 (30 bytes padded):
    // numberOfContours=1, xMin=0,yMin=0,xMax=50,yMax=50
    // endPts=[2], instructionLength=0
    // flags=[0x01,0x01,0x01]
    // xDeltas=[0,50,-50], yDeltas=[0,0,50]
    else if i == 0x80 { b'\x00' } else if i == 0x81 { b'\x01' } // contours
    else if i == 0x86 { b'\x00' } else if i == 0x87 { b'\x32' } // xMax=50
    else if i == 0x88 { b'\x00' } else if i == 0x89 { b'\x32' } // yMax=50
    else if i == 0x8A { b'\x00' } else if i == 0x8B { b'\x02' } // endPt=2
    else if i == 0x8C { b'\x00' } else if i == 0x8D { b'\x00' } // instrLen=0
    else if i == 0x8E { b'\x01' } else if i == 0x8F { b'\x01' } else if i == 0x90 {
      b'\x01'
    } // flags
    else if i == 0x91 { b'\x00' } else if i == 0x92 { b'\x00' } // dx0=0
    else if i == 0x93 { b'\x00' } else if i == 0x94 { b'\x32' } // dx1=50
    else if i == 0x95 { b'\xFF' } else if i == 0x96 { b'\xCE' } // dx2=-50
    else if i == 0x97 { b'\x00' } else if i == 0x98 { b'\x00' } // dy0=0
    else if i == 0x99 { b'\x00' } else if i == 0x9A { b'\x00' } // dy1=0
    else if i == 0x9B { b'\x00' } else if i == 0x9C { b'\x32' } // dy2=50

    // head table at 0xA0: unitsPerEm=1000 at offset +18, indexToLocFormat=0 at +50.
    else if i == 0xA0 + 18 { b'\x03' } else if i == 0xA0 + 19 { b'\xE8' }
    else if i == 0xA0 + 50 { b'\x00' } else if i == 0xA0 + 51 { b'\x00' }

    // loca table at 0xE0: [0, 15] (since end offset=30 bytes => 15*2)
    else if i == 0xE2 { b'\x00' } else if i == 0xE3 { b'\x0F' }
    else { b'\x00' }
  })
}

test "Scaler.scale_outline decodes a simple glyf outline" {
  let data = mk_min_ttf_with_one_simple_glyph()
  let font = @swash.FontRef::from_offset(data, 0).unwrap()
  let cx = ScaleContext::new()
  // size=1000, unitsPerEm=1000 => scale=1.
  let scaler = cx.builder(font).size(1000.0).build()
  let outline = scaler.scale_outline(0).unwrap()
  inspect(outline.points().length(), content="3")
  inspect(outline.verbs().length(), content="4")
  inspect(outline.bounds().width().to_int(), content="50")
  inspect(outline.bounds().height().to_int(), content="50")
}

fn mk_min_ttf_with_compound_glyph() -> Bytes {
  // Two glyphs in glyf:
  // g0: simple triangle (30 bytes)
  // g1: compound referencing g0 with dx=100 (18 bytes, padded to 20)
  //
  // Offsets (loca fmt 0, word offsets):
  // g0 start=0, end=15
  // g1 start=15, end=25
  //
  // Table directory with 3 tables: glyf, head, loca.
  let total = 0xE0 + 6 // loca needs 3 u16s
  Bytes::makei(total, i => {
    // sfntVersion 0x00010000
    if i == 0 { b'\x00' } else if i == 1 { b'\x01' } else if i == 2 { b'\x00' } else if i == 3 {
      b'\x00'
    } else if i == 4 { b'\x00' } else if i == 5 { b'\x03' } // numTables=3

    // record 0: "glyf" offset 0x80 len 50
    else if i == 12 { b'g' } else if i == 13 { b'l' } else if i == 14 { b'y' } else if i == 15 {
      b'f'
    } else if i == 20 { b'\x00' } else if i == 21 { b'\x00' } else if i == 22 {
      b'\x00'
    } else if i == 23 { b'\x80' }
    else if i == 24 { b'\x00' } else if i == 25 { b'\x00' } else if i == 26 {
      b'\x00'
    } else if i == 27 { b'\x32' } // len 50

    // record 1: "head" offset 0xA0 len 54
    else if i == 28 { b'h' } else if i == 29 { b'e' } else if i == 30 { b'a' } else if i == 31 {
      b'd'
    } else if i == 36 { b'\x00' } else if i == 37 { b'\x00' } else if i == 38 {
      b'\x00'
    } else if i == 39 { b'\xA0' }
    else if i == 40 { b'\x00' } else if i == 41 { b'\x00' } else if i == 42 {
      b'\x00'
    } else if i == 43 { b'\x36' }

    // record 2: "loca" offset 0xE0 len 6
    else if i == 44 { b'l' } else if i == 45 { b'o' } else if i == 46 { b'c' } else if i == 47 {
      b'a'
    } else if i == 52 { b'\x00' } else if i == 53 { b'\x00' } else if i == 54 {
      b'\x00'
    } else if i == 55 { b'\xE0' }
    else if i == 56 { b'\x00' } else if i == 57 { b'\x00' } else if i == 58 {
      b'\x00'
    } else if i == 59 { b'\x06' }

    // glyph 0 at 0x80: same as mk_min_ttf_with_one_simple_glyph
    else if i == 0x80 { b'\x00' } else if i == 0x81 { b'\x01' }
    else if i == 0x86 { b'\x00' } else if i == 0x87 { b'\x32' }
    else if i == 0x88 { b'\x00' } else if i == 0x89 { b'\x32' }
    else if i == 0x8A { b'\x00' } else if i == 0x8B { b'\x02' }
    else if i == 0x8C { b'\x00' } else if i == 0x8D { b'\x00' }
    else if i == 0x8E { b'\x01' } else if i == 0x8F { b'\x01' } else if i == 0x90 {
      b'\x01'
    }
    else if i == 0x91 { b'\x00' } else if i == 0x92 { b'\x00' }
    else if i == 0x93 { b'\x00' } else if i == 0x94 { b'\x32' }
    else if i == 0x95 { b'\xFF' } else if i == 0x96 { b'\xCE' }
    else if i == 0x97 { b'\x00' } else if i == 0x98 { b'\x00' }
    else if i == 0x99 { b'\x00' } else if i == 0x9A { b'\x00' }
    else if i == 0x9B { b'\x00' } else if i == 0x9C { b'\x32' }

    // glyph 1 at 0x80 + 30 = 0x9E:
    // numberOfContours=-1, flags=ARGS_ARE_WORDS|ARGS_ARE_XY_VALUES, glyphIndex=0, dx=100, dy=0.
    else if i == 0x9E { b'\xFF' } else if i == 0x9F { b'\xFF' }
    else if i == 0xA8 { b'\x00' } else if i == 0xA9 { b'\x03' } // flags=0x0003
    else if i == 0xAA { b'\x00' } else if i == 0xAB { b'\x00' } // glyphIndex=0
    else if i == 0xAC { b'\x00' } else if i == 0xAD { b'\x64' } // dx=100
    else if i == 0xAE { b'\x00' } else if i == 0xAF { b'\x00' } // dy=0

    // head table at 0xA0: unitsPerEm=1000, indexToLocFormat=0.
    else if i == 0xA0 + 18 { b'\x03' } else if i == 0xA0 + 19 { b'\xE8' }
    else if i == 0xA0 + 50 { b'\x00' } else if i == 0xA0 + 51 { b'\x00' }

    // loca at 0xE0: [0,15,25]
    else if i == 0xE2 { b'\x00' } else if i == 0xE3 { b'\x0F' }
    else if i == 0xE4 { b'\x00' } else if i == 0xE5 { b'\x19' }
    else { b'\x00' }
  })
}

test "Scaler.scale_outline decodes a compound glyph with translation" {
  let data = mk_min_ttf_with_compound_glyph()
  let font = @swash.FontRef::from_offset(data, 0).unwrap()
  let cx = ScaleContext::new()
  let scaler = cx.builder(font).size(1000.0).build()
  let outline = scaler.scale_outline(1).unwrap()
  inspect(outline.points().length(), content="3")
  inspect(outline.verbs().length(), content="4")
  inspect(outline.points()[0].x().to_int(), content="100")
}
