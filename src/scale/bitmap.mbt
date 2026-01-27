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
