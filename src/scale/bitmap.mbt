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
/// Bitmap helpers used by the renderer.
///
/// Ported from upstream `swash/src/scale/bitmap/mod.rs`.

///|
/// Alpha blends an 8-bit mask tinted with `color` into a target RGBA buffer.
pub fn blit(
  mask : Array[Byte],
  mask_width : UInt,
  mask_height : UInt,
  x : Int,
  y : Int,
  color : Array[Byte],
  target : Array[Byte],
  target_width : UInt,
  target_height : UInt,
) -> Unit {
  if mask_width == 0U ||
    mask_height == 0U ||
    target_width == 0U ||
    target_height == 0U {
    return
  }
  if color.length() < 4 {
    return
  }
  let source_width = mask_width.reinterpret_as_int()
  let source_height = mask_height.reinterpret_as_int()
  let dest_width = target_width.reinterpret_as_int()
  let dest_height = target_height.reinterpret_as_int()
  let source_x = if x < 0 { -x } else { 0 }
  let source_y = if y < 0 { -y } else { 0 }
  if source_x >= source_width || source_y >= source_height {
    return
  }
  let dest_x = if x < 0 { 0 } else { x }
  let dest_y = if y < 0 { 0 } else { y }
  if dest_x >= dest_width || dest_y >= dest_height {
    return
  }
  let source_end_x = source_width.min(dest_width - dest_x + source_x)
  let source_end_y = source_height.min(dest_height - dest_y + source_y)
  let dest_pitch = target_width.reinterpret_as_int() * 4
  let color_a = color[3].to_int().reinterpret_as_uint()
  let mut dy = dest_y
  for sy in source_y..<source_end_y {
    let src_row = sy * source_width
    let dst_row = dy * dest_pitch
    dy = dy + 1
    let mut dx = dest_x * 4
    for sx in source_x..<source_end_x {
      let a = (mask[src_row + sx].to_int().reinterpret_as_uint() * color_a) >> 8
      if a >= 255U {
        target[dst_row + dx + 0] = color[0]
        target[dst_row + dx + 1] = color[1]
        target[dst_row + dx + 2] = color[2]
        target[dst_row + dx + 3] = (255).to_byte()
      } else if a != 0U {
        let inverse_a = 255U - a
        for i in 0..<3 {
          let d = target[dst_row + dx + i].to_int().reinterpret_as_uint()
          let c = (inverse_a * d + a * color[i].to_int().reinterpret_as_uint()) >>
            8
          target[dst_row + dx + i] = c.reinterpret_as_int().to_byte()
        }
        let d = target[dst_row + dx + 3].to_int().reinterpret_as_uint()
        let c = (inverse_a * d + a * 255U) >> 8
        target[dst_row + dx + 3] = c.reinterpret_as_int().to_byte()
      }
      dx = dx + 4
    }
  }
}

///|
fn decode_ebdt_1bpp(
  data : BytesView,
  width : UInt,
  height : UInt,
  target : Array[Byte],
) -> Bool {
  let w = width.reinterpret_as_int()
  let h = height.reinterpret_as_int()
  if w <= 0 || h <= 0 {
    return false
  }
  let bytes_per_row = (w + 7) / 8
  let needed = bytes_per_row * h
  if data.length() < needed {
    return false
  }
  let expected = w * h
  if target.length() < expected {
    return false
  }
  let mut out = 0
  for y in 0..<h {
    let row = y * bytes_per_row
    for x in 0..<w {
      let byte_index = row + x / 8
      let bit_index = 7 - x % 8
      match data.get(byte_index) {
        None => return false
        Some(b) => {
          let bit = (b.to_int().reinterpret_as_uint() >> bit_index) & 1
          target[out] = if bit != 0 { (255).to_byte() } else { (0).to_byte() }
          out = out + 1
        }
      }
    }
  }
  true
}

///|
fn mitchell(x : Double) -> Double {
  let a = x.abs()
  if a < 1.0 {
    ((16.0 + a * a * (21.0 * a - 36.0)) / 18.0).abs()
  } else if a < 2.0 {
    ((32.0 + a * (-60.0 + a * (36.0 - 7.0 * a))) / 18.0).abs()
  } else {
    0.0
  }
}

///|
fn resize_weights(
  width : UInt,
  new_width : UInt,
  outx : UInt,
  weights : Array[Double],
) -> (Int, Int, Double) {
  // Mirrors upstream swash `sample_dir` weight computation for Mitchell.
  weights.clear()
  let ratio = width.to_double() / new_width.to_double()
  let sratio = if ratio > 1.0 { ratio } else { 1.0 }
  let src_support = 2.0 * sratio
  let isratio = 1.0 / sratio
  let inx = (outx.to_double() + 0.5) * ratio - 0.5
  let mut left = (inx - src_support).floor().to_int()
  let mut right = (inx + src_support).ceil().to_int()
  if left < 0 {
    left = 0
  }
  let max_left = width.reinterpret_as_int() - 1
  if left > max_left {
    left = max_left
  }
  if right < left + 1 {
    right = left + 1
  }
  let max_right = width.reinterpret_as_int()
  if right > max_right {
    right = max_right
  }
  // Limit weights to 64 samples like upstream.
  while right - left > 64 {
    right = right - 1
    left = left + 1
  }
  let mut sum = 0.0
  for i in left..<right {
    let w = mitchell((i.to_double() - inx) * isratio)
    weights.push(w)
    sum = sum + w
  }
  let isum = 1.0 / sum
  (left, right, isum)
}

///|
fn resize_mitchell_alpha(
  image : Array[Byte],
  width : UInt,
  height : UInt,
  target : Array[Byte],
  target_width : UInt,
  target_height : UInt,
  scratch : Array[Byte],
) -> Bool {
  if target_width == 0U || target_height == 0U {
    return true
  }
  let image_size = (width * height).reinterpret_as_int()
  if image.length() < image_size {
    return false
  }
  let target_size = (target_width * target_height).reinterpret_as_int()
  if target.length() < target_size {
    return false
  }

  // Horizontal pass: image -> scratch (target_width x height).
  scratch.clear()
  let scratch_size = (target_width * height).reinterpret_as_int()
  for _ in 0..<scratch_size {
    scratch.push((0).to_byte())
  }
  let weights : Array[Double] = []
  for outx in 0U..<target_width {
    let (left, right, isum) = resize_weights(width, target_width, outx, weights)
    for y in 0U..<height {
      let mut acc = 0.0
      let mut wi = 0
      for x in left..<right {
        let sx = x.reinterpret_as_uint()
        let a = image[(y * width + sx).reinterpret_as_int()]
          .to_int()
          .to_double() /
          255.0
        let wv = weights[wi]
        acc = acc + a * wv
        wi = wi + 1
      }
      let outa = (acc * isum * 255.0).to_int()
      scratch[(y * target_width + outx).reinterpret_as_int()] = outa.to_byte()
    }
  }

  // Recompute weights for vertical pass per outy.
  for outy in 0U..<target_height {
    let (top, bottom, isum) = resize_weights(
      height, target_height, outy, weights,
    )
    for x in 0U..<target_width {
      let mut acc = 0.0
      let mut wi = 0
      for y in top..<bottom {
        let sy = y.reinterpret_as_uint()
        let a = scratch[(sy * target_width + x).reinterpret_as_int()]
          .to_int()
          .to_double() /
          255.0
        let wv = weights[wi]
        acc = acc + a * wv
        wi = wi + 1
      }
      let outa = (acc * isum * 255.0).to_int()
      target[(outy * target_width + x).reinterpret_as_int()] = outa.to_byte()
    }
  }
  true
}

///|
fn resize_mitchell_rgba(
  image : Array[Byte],
  width : UInt,
  height : UInt,
  target : Array[Byte],
  target_width : UInt,
  target_height : UInt,
  scratch : Array[Byte],
) -> Bool {
  if target_width == 0U || target_height == 0U {
    return true
  }
  let image_size = (width * height * 4U).reinterpret_as_int()
  if image.length() < image_size {
    return false
  }
  let target_size = (target_width * target_height * 4U).reinterpret_as_int()
  if target.length() < target_size {
    return false
  }

  // Horizontal pass: image -> scratch (target_width x height x 4).
  scratch.clear()
  let scratch_size = (target_width * height * 4U).reinterpret_as_int()
  for _ in 0..<scratch_size {
    scratch.push((0).to_byte())
  }
  let weights : Array[Double] = []
  for outx in 0U..<target_width {
    let (left, right, isum) = resize_weights(width, target_width, outx, weights)
    for y in 0U..<height {
      let mut ar = 0.0
      let mut ag = 0.0
      let mut ab = 0.0
      let mut aa = 0.0
      let mut wi = 0
      for x in left..<right {
        let sx = x.reinterpret_as_uint()
        let base = ((y * width + sx) * 4U).reinterpret_as_int()
        let r = image[base + 0].to_int().to_double() / 255.0
        let g = image[base + 1].to_int().to_double() / 255.0
        let b = image[base + 2].to_int().to_double() / 255.0
        let a = image[base + 3].to_int().to_double() / 255.0
        let wv = weights[wi]
        ar = ar + r * wv * a
        ag = ag + g * wv * a
        ab = ab + b * wv * a
        aa = aa + a * wv
        wi = wi + 1
      }
      if aa != 0.0 {
        let inv = 1.0 / aa
        ar = ar * inv
        ag = ag * inv
        ab = ab * inv
        aa = aa * isum
      }
      let out_base = ((y * target_width + outx) * 4U).reinterpret_as_int()
      scratch[out_base + 0] = (ar * 255.0).to_int().to_byte()
      scratch[out_base + 1] = (ag * 255.0).to_int().to_byte()
      scratch[out_base + 2] = (ab * 255.0).to_int().to_byte()
      scratch[out_base + 3] = (aa * 255.0).to_int().to_byte()
    }
  }

  // Vertical pass: scratch -> target (target_width x target_height x 4).
  for outy in 0U..<target_height {
    let (top, bottom, isum) = resize_weights(
      height, target_height, outy, weights,
    )
    for x in 0U..<target_width {
      let mut ar = 0.0
      let mut ag = 0.0
      let mut ab = 0.0
      let mut aa = 0.0
      let mut wi = 0
      for y in top..<bottom {
        let sy = y.reinterpret_as_uint()
        let base = ((sy * target_width + x) * 4U).reinterpret_as_int()
        let r = scratch[base + 0].to_int().to_double() / 255.0
        let g = scratch[base + 1].to_int().to_double() / 255.0
        let b = scratch[base + 2].to_int().to_double() / 255.0
        let a = scratch[base + 3].to_int().to_double() / 255.0
        let wv = weights[wi]
        ar = ar + r * wv * a
        ag = ag + g * wv * a
        ab = ab + b * wv * a
        aa = aa + a * wv
        wi = wi + 1
      }
      if aa != 0.0 {
        let inv = 1.0 / aa
        ar = ar * inv
        ag = ag * inv
        ab = ab * inv
        aa = aa * isum
      }
      let out_base = ((outy * target_width + x) * 4U).reinterpret_as_int()
      target[out_base + 0] = (ar * 255.0).to_int().to_byte()
      target[out_base + 1] = (ag * 255.0).to_int().to_byte()
      target[out_base + 2] = (ab * 255.0).to_int().to_byte()
      target[out_base + 3] = (aa * 255.0).to_int().to_byte()
    }
  }
  true
}
