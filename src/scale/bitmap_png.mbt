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
/// PNG helpers (scaffold).
///
/// Upstream swash decodes embedded PNG glyph bitmaps and relies on `yazi` for
/// zlib inflation of IDAT chunks. We keep a minimal shared building block here
/// so the rest of the bitmap pipeline can be ported incrementally.

///|
/// Returns true if the data begins with the PNG signature.
pub fn is_png(data : Bytes) -> Bool {
  data.length() >= 8 &&
  data.get(0) == Some(b'\x89') &&
  data.get(1) == Some(b'P') &&
  data.get(2) == Some(b'N') &&
  data.get(3) == Some(b'G') &&
  data.get(4) == Some(b'\r') &&
  data.get(5) == Some(b'\n') &&
  data.get(6) == Some(b'\x1A') &&
  data.get(7) == Some(b'\n')
}

///|
/// Inflates a zlib stream.
///
/// In PNG this is used for concatenated IDAT data.
pub fn inflate_zlib(data : Bytes) -> Array[Byte] raise @yazi.YaziError {
  let (out, _) = @yazi.decompress(data, @yazi.Format::Zlib)
  out
}

// ---- Internal PNG decoder (ported from swash-reference) --------------------

///|
const PNG_IHDR_LEN : Int = 13

///|
const CHUNK_IHDR : UInt = 0x49484452 // "IHDR"

///|
const CHUNK_PLTE : UInt = 0x504c5445 // "PLTE"

///|
const CHUNK_TRNS : UInt = 0x74524e53 // "tRNS"

///|
const CHUNK_IDAT : UInt = 0x49444154 // "IDAT"

///|
const CHUNK_GAMA : UInt = 0x67414d41 // "gAMA"

///|
const CHUNK_IEND : UInt = 0x49454e44 // "IEND"

// Color types.

///|
const COLOR_GREYSCALE : UInt = 0

///|
const COLOR_TRUECOLOR : UInt = 2

///|
const COLOR_INDEXED : UInt = 3

///|
const COLOR_GREYSCALE_ALPHA : UInt = 4

///|
const COLOR_TRUECOLOR_ALPHA : UInt = 6

///|
let adam7_row_start : Array[Int] = [0, 0, 4, 0, 2, 0, 1]

///|
let adam7_row_inc : Array[Int] = [8, 8, 8, 4, 4, 2, 2]

///|
let adam7_col_start : Array[Int] = [0, 4, 0, 2, 0, 1, 0]

///|
let adam7_col_inc : Array[Int] = [8, 8, 4, 4, 2, 2, 1]

///|
fn get_u32be(buf : Bytes, offset : Int) -> UInt? {
  let b = buf
  guard offset >= 0 && b.length() - offset >= 4 else { None }
  match
    (b.get(offset), b.get(offset + 1), b.get(offset + 2), b.get(offset + 3)) {
    (Some(b0), Some(b1), Some(b2), Some(b3)) => {
      let u0 = b0.to_int().reinterpret_as_uint()
      let u1 = b1.to_int().reinterpret_as_uint()
      let u2 = b2.to_int().reinterpret_as_uint()
      let u3 = b3.to_int().reinterpret_as_uint()
      Some((u0 << 24) | (u1 << 16) | (u2 << 8) | u3)
    }
    _ => None
  }
}

///|
fn paeth(a : UInt, b : UInt, c : UInt) -> UInt {
  let pa = (b.reinterpret_as_int() - c.reinterpret_as_int()).abs()
  let pb = (a.reinterpret_as_int() - c.reinterpret_as_int()).abs()
  let pc = (a.reinterpret_as_int() +
  b.reinterpret_as_int() -
  c.reinterpret_as_int() -
  c.reinterpret_as_int()).abs()
  if pc < pa && pc < pb {
    c
  } else if pb < pa {
    b
  } else {
    a
  }
}

///|
fn defilter(
  ty : UInt,
  source : Array[Byte],
  dest : Array[Byte],
  last : Array[Byte],
  bwidth : Int,
) -> Bool {
  let len = source.length()
  if dest.length() < len || last.length() < len {
    return false
  }
  match ty {
    0 =>
      for i in 0..<len {
        dest[i] = source[i]
      }
    1 => {
      for i in 0..<bwidth {
        dest[i] = source[i]
      }
      for i in bwidth..<len {
        let s = source[i].to_int().reinterpret_as_uint()
        let a = dest[i - bwidth].to_int().reinterpret_as_uint()
        dest[i] = ((s + a) & 255U).reinterpret_as_int().to_byte()
      }
    }
    2 =>
      for i in 0..<len {
        let s = source[i].to_int().reinterpret_as_uint()
        let a = last[i].to_int().reinterpret_as_uint()
        dest[i] = ((s + a) & 255U).reinterpret_as_int().to_byte()
      }
    3 => {
      for i in 0..<bwidth {
        let s = source[i].to_int().reinterpret_as_uint()
        let a = (last[i].to_int() / 2).reinterpret_as_uint()
        dest[i] = ((s + a) & 255U).reinterpret_as_int().to_byte()
      }
      for i in bwidth..<len {
        let s = source[i].to_int().reinterpret_as_uint()
        let a = ((dest[i - bwidth].to_int() + last[i].to_int()) / 2).reinterpret_as_uint()
        dest[i] = ((s + a) & 255U).reinterpret_as_int().to_byte()
      }
    }
    4 => {
      for i in 0..<bwidth {
        let s = source[i].to_int().reinterpret_as_uint()
        let a = last[i].to_int().reinterpret_as_uint()
        dest[i] = ((s + a) & 255U).reinterpret_as_int().to_byte()
      }
      for i in bwidth..<len {
        let a = dest[i - bwidth].to_int().reinterpret_as_uint()
        let b = last[i].to_int().reinterpret_as_uint()
        let c = last[i - bwidth].to_int().reinterpret_as_uint()
        let p = paeth(a, b, c).reinterpret_as_int()
        let s = source[i].to_int().reinterpret_as_uint()
        dest[i] = ((s + p.reinterpret_as_uint()) & 255U)
          .reinterpret_as_int()
          .to_byte()
      }
    }
    _ => return false
  }
  true
}

///|
fn normalize(
  source : Array[Byte],
  dest : Array[Byte],
  depth : UInt,
  palette : Bool,
  width : Int,
  trunc_16 : Bool,
) -> Bool {
  match depth {
    16 => {
      let needed = width
      if dest.length() < needed {
        return false
      }
      if trunc_16 {
        // Take the high byte for each 16-bit sample.
        for i in 0..<needed {
          dest[i] = source[i * 2]
        }
      } else {
        // Keep the big-endian 16-bit samples (unused in swash's RGBA8 path).
        for i in 0..<needed {
          dest[i] = source[i * 2]
        }
      }
    }
    8 => {
      if dest.length() < source.length() {
        return false
      }
      for i in 0..<source.length() {
        dest[i] = source[i]
      }
    }
    4 => {
      if dest.length() < width {
        return false
      }
      let conv = if !palette { 17 } else { 1 }
      for i in 0..<width {
        let s = source[i / 2].to_int().reinterpret_as_uint()
        let shift = 4 - i % 2 * 4
        let v = ((s >> shift) & 15) * conv.reinterpret_as_uint()
        dest[i] = v.reinterpret_as_int().to_byte()
      }
    }
    2 => {
      if dest.length() < width {
        return false
      }
      let conv = if !palette { 85 } else { 1 }
      for i in 0..<width {
        let s = source[i / 4].to_int().reinterpret_as_uint()
        let shift = 6 - i % 4 * 2
        let v = ((s >> shift) & 3) * conv.reinterpret_as_uint()
        dest[i] = v.reinterpret_as_int().to_byte()
      }
    }
    1 => {
      if dest.length() < width {
        return false
      }
      let conv = if !palette { 255 } else { 1 }
      for i in 0..<width {
        let s = source[i / 8].to_int().reinterpret_as_uint()
        let shift = 7 - i % 8
        let v = ((s >> shift) & 1) * conv.reinterpret_as_uint()
        dest[i] = v.reinterpret_as_int().to_byte()
      }
    }
    _ => return false
  }
  true
}

///|
fn emit_rgba8(
  color_type : UInt,
  palette : Array[Byte],
  trans : Array[Byte],
  source : Array[Byte],
  image : Array[Byte],
  x : Int,
  y : Int,
  width : Int,
  inc : Int,
  len : Int,
) -> Bool {
  let mut out = y * width * 4 + x * 4
  let mut i = 0
  match color_type {
    COLOR_INDEXED => {
      let palette_len = palette.length()
      let trans_len = trans.length()
      for _ in 0..<len {
        let t = source[i].to_int()
        let p = t * 3
        if p + 2 >= palette_len {
          image[out] = (0).to_byte()
          image[out + 1] = (0).to_byte()
          image[out + 2] = (0).to_byte()
        } else {
          image[out] = palette[p]
          image[out + 1] = palette[p + 1]
          image[out + 2] = palette[p + 2]
        }
        image[out + 3] = if t >= trans_len { (255).to_byte() } else { trans[t] }
        i = i + 1
        out = out + 4 * inc
      }
    }
    COLOR_TRUECOLOR =>
      for _ in 0..<len {
        image[out] = source[i]
        image[out + 1] = source[i + 1]
        image[out + 2] = source[i + 2]
        image[out + 3] = (255).to_byte()
        i = i + 3
        out = out + 4 * inc
      }
    COLOR_TRUECOLOR_ALPHA =>
      for _ in 0..<len {
        image[out] = source[i]
        image[out + 1] = source[i + 1]
        image[out + 2] = source[i + 2]
        image[out + 3] = source[i + 3]
        i = i + 4
        out = out + 4 * inc
      }
    COLOR_GREYSCALE =>
      for j in 0..<len {
        let c = source[j]
        image[out] = c
        image[out + 1] = c
        image[out + 2] = c
        image[out + 3] = (255).to_byte()
        out = out + 4 * inc
      }
    COLOR_GREYSCALE_ALPHA =>
      for _ in 0..<len {
        let c = source[i]
        image[out] = c
        image[out + 1] = c
        image[out + 2] = c
        image[out + 3] = source[i + 1]
        i = i + 2
        out = out + 4 * inc
      }
    _ => return false
  }
  true
}

///|
fn decode_png(
  data : Bytes,
  scratch : Array[Byte],
  target : Array[Byte],
) -> (UInt, UInt)? {
  if data.length() < 33 || !is_png(data) {
    return None
  }
  // Validate IHDR.
  let len = get_u32be(data, 8)
  let ty = get_u32be(data, 12)
  if len != Some(PNG_IHDR_LEN.reinterpret_as_uint()) || ty != Some(CHUNK_IHDR) {
    return None
  }
  let width = match get_u32be(data, 16) {
    None => return None
    Some(v) => v
  }
  let height = match get_u32be(data, 20) {
    None => return None
    Some(v) => v
  }
  let depth = match data.get(24) {
    None => return None
    Some(v) => v.to_int().reinterpret_as_uint()
  }
  let color_type = match data.get(25) {
    None => return None
    Some(v) => v.to_int().reinterpret_as_uint()
  }
  let compression_method = match data.get(26) {
    None => return None
    Some(v) => v.to_int()
  }
  let filter_method = match data.get(27) {
    None => return None
    Some(v) => v.to_int()
  }
  let interlace_method = match data.get(28) {
    None => return None
    Some(v) => v.to_int()
  }
  if compression_method != 0 ||
    filter_method != 0 ||
    (interlace_method != 0 && interlace_method != 1) {
    return None
  }
  // Validate depth/color_type.
  match color_type {
    COLOR_GREYSCALE | COLOR_INDEXED => {
      if depth != 1 && depth != 2 && depth != 4 && depth != 8 && depth != 16 {
        return None
      }
      if color_type == COLOR_INDEXED && depth == 16 {
        return None
      }
    }
    COLOR_TRUECOLOR | COLOR_TRUECOLOR_ALPHA | COLOR_GREYSCALE_ALPHA =>
      if depth != 8 && depth != 16 {
        return None
      }
    _ => return None
  }
  let w = width.reinterpret_as_int()
  let h = height.reinterpret_as_int()
  if w < 0 || h < 0 {
    return None
  }
  if w == 0 || h == 0 {
    return Some((width, height))
  }
  if target.length() < (width * height * 4U).reinterpret_as_int() {
    return None
  }
  let channels = match color_type {
    COLOR_TRUECOLOR => 3
    COLOR_TRUECOLOR_ALPHA => 4
    COLOR_GREYSCALE_ALPHA => 2
    COLOR_GREYSCALE => 1
    COLOR_INDEXED => 1
    _ => return None
  }
  let bpp = depth.reinterpret_as_int() * channels
  let pitch = (w * bpp + 7) / 8
  let bwidth = (bpp + 7) / 8

  // Collect palette, transparency and concatenated IDAT.
  let palette : Array[Byte] = []
  let trans : Array[Byte] = []
  scratch.clear()
  let limit = data.length()
  let mut offset = 33
  while true {
    if offset + 8 > limit {
      return None
    }
    let clen = match get_u32be(data, offset) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    let cty = match get_u32be(data, offset + 4) {
      None => return None
      Some(v) => v
    }
    offset = offset + 8
    if clen < 0 || offset + clen > limit {
      return None
    }
    // chunk data in data[offset:offset+clen]
    match cty {
      CHUNK_PLTE => {
        palette.clear()
        for i in 0..<clen {
          match data.get(offset + i) {
            None => return None
            Some(b) => palette.push(b)
          }
        }
      }
      CHUNK_TRNS => {
        trans.clear()
        for i in 0..<clen {
          match data.get(offset + i) {
            None => return None
            Some(b) => trans.push(b)
          }
        }
      }
      CHUNK_IDAT =>
        for i in 0..<clen {
          match data.get(offset + i) {
            None => return None
            Some(b) => scratch.push(b)
          }
        }
      CHUNK_GAMA =>
        // Ignored in swash's RGBA8 output.
        ()
      CHUNK_IEND => break
      _ => ()
    }
    offset = offset + clen + 4 // skip CRC
  }

  // Inflate concatenated IDAT zlib.
  let idat = Bytes::from_array(scratch.op_as_view())
  let decomp_opt = Some(inflate_zlib(idat)) catch { _ => None }
  let decomp = match decomp_opt {
    None => return None
    Some(v) => v
  }
  if color_type == COLOR_INDEXED && palette.length() == 0 {
    return None
  }

  // Row buffers.
  let line : Array[Byte] = Array::makei(pitch, _ => b'\x00')
  let prev_line : Array[Byte] = Array::makei(pitch, _ => b'\x00')
  let out_line : Array[Byte] = Array::makei(w * 8, _ => b'\x00')
  if interlace_method == 0 {
    // Non-interlaced.
    for y in 0..<h {
      let base = y * (pitch + 1)
      if base + pitch + 1 > decomp.length() {
        return None
      }
      let ty = decomp[base].to_int().reinterpret_as_uint()
      let scan : Array[Byte] = Array::makei(pitch, i => decomp[base + 1 + i])
      if !defilter(ty, scan, line, prev_line, bwidth) {
        return None
      }
      if depth == 8U {
        if !emit_rgba8(color_type, palette, trans, line, target, 0, y, w, 1, w) {
          return None
        }
      } else {
        let has_palette = palette.length() != 0
        let needed = w * channels
        if !normalize(line, out_line, depth, has_palette, needed, true) {
          return None
        }
        if !emit_rgba8(
            color_type, palette, trans, out_line, target, 0, y, w, 1, w,
          ) {
          return None
        }
      }
      for i in 0..<pitch {
        prev_line[i] = line[i]
      }
    }
  } else {
    // Adam7 interlacing.
    let mut pass = 0
    let mut y = 0
    let mut off = 0
    while true {
      let cols = if pass == 0 {
        (w + 7) / 8
      } else if pass == 1 {
        (w + 3) / 8
      } else if pass == 2 {
        (w + 3) / 4
      } else if pass == 3 {
        (w + 1) / 4
      } else if pass == 4 {
        (w + 1) / 2
      } else if pass == 5 {
        w / 2
      } else if pass == 6 {
        w
      } else {
        return None
      }
      if cols == 0 {
        pass = pass + 1
        continue
      }
      let start = adam7_col_start[pass]
      let inc = adam7_col_inc[pass]
      let row_inc = adam7_row_inc[pass]
      while y < h {
        let pass_pitch = (cols * bpp + 7) / 8
        if off + pass_pitch + 1 > decomp.length() {
          return None
        }
        let row : Array[Byte] = Array::makei(pass_pitch + 1, i => decomp[off + i])
        off = off + pass_pitch + 1
        let ty = row[0].to_int().reinterpret_as_uint()
        let scan : Array[Byte] = Array::makei(pass_pitch, i => row[i + 1])
        if !defilter(ty, scan, line, prev_line, bwidth) {
          return None
        }
        if depth == 8U {
          if !emit_rgba8(
              color_type, palette, trans, line, target, start, y, w, inc, cols,
            ) {
            return None
          }
        } else {
          let has_palette = palette.length() != 0
          let needed = cols *
            (if color_type == COLOR_TRUECOLOR {
              3
            } else if color_type == COLOR_TRUECOLOR_ALPHA {
              4
            } else if color_type == COLOR_GREYSCALE_ALPHA {
              2
            } else {
              1
            })
          if !normalize(line, out_line, depth, has_palette, needed, true) {
            return None
          }
          if !emit_rgba8(
              color_type, palette, trans, out_line, target, start, y, w, inc, cols,
            ) {
            return None
          }
        }
        // swap prev and line
        for i in 0..<pass_pitch {
          prev_line[i] = line[i]
        }
        y = y + row_inc
      }
      if pass == 6 {
        break
      }
      pass = pass + 1
      y = adam7_row_start[pass]
      for i in 0..<prev_line.length() {
        prev_line[i] = (0).to_byte()
      }
    }
  }
  Some((width, height))
}
