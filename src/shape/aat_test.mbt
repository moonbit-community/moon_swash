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
/// Minimal end-to-end tests for AAT shaping paths (black-box).

fn push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  out.push(((u >> 8) & 0xFFU).to_byte())
  out.push((u & 0xFFU).to_byte())
}

fn push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  out.push(((v >> 24) & 0xFFU).to_byte())
  out.push(((v >> 16) & 0xFFU).to_byte())
  out.push(((v >> 8) & 0xFFU).to_byte())
  out.push((v & 0xFFU).to_byte())
}

// kern table: version=1 (AAT-style header) with a single Format0 subtable
// that kerns glyph 1 followed by glyph 2 by -20 units.
fn make_kern_format0_data() -> Bytes {
  let bytes : Array[Byte] = []
  bytes.push((0).to_byte()) // pad so the table isn't at offset 0

  // kern table header (starts at offset 1)
  push_u16_be(bytes, 1) // version != 0 => AAT path
  push_u16_be(bytes, 0) // unused
  push_u32_be(bytes, 1U) // subtable count

  // subtable
  let sub_start = bytes.length()
  push_u32_be(bytes, 0U) // size (patched later)
  push_u16_be(bytes, 0) // coverage: horizontal + format 0
  push_u16_be(bytes, 0) // padding to reach offset=8 within subtable

  // format0 data at offset 8 within subtable
  push_u16_be(bytes, 1) // pair count
  // padding to reach base=offset+8 (16 bytes from subtable start)
  push_u16_be(bytes, 0)
  push_u16_be(bytes, 0)
  push_u16_be(bytes, 0)

  // pair record: u32 pair + i16 value (-20 => 0xFFEC)
  push_u32_be(bytes, (1U << 16) | 2U)
  push_u16_be(bytes, 0xFFEC)

  // Patch size u32
  let sub_size = (bytes.length() - sub_start).reinterpret_as_uint()
  bytes[sub_start] = ((sub_size >> 24) & 0xFFU).to_byte()
  bytes[sub_start + 1] = ((sub_size >> 16) & 0xFFU).to_byte()
  bytes[sub_start + 2] = ((sub_size >> 8) & 0xFFU).to_byte()
  bytes[sub_start + 3] = (sub_size & 0xFFU).to_byte()

  Bytes::from_array(bytes)
}

fn make_buffer_ab() -> Buffer {
  let buf = Buffer::new()
  let tokens : Array[@swash.Token] = []
  let mut offset = 0U
  for ch in "ab" {
    tokens.push(
      @swash.Token::new(ch, offset, 1U, @swash.CharInfo::from_char(ch), 0U),
    )
    offset = offset + 1U
  }
  let parser = @swash.Parser::new(@swash.Script::Latin, tokens.iter())
  let cluster = @swash.CharCluster::new()
  while parser.next(cluster) {
    cluster.map(fn(ch) {
      if ch == 'a' {
        (1).to_uint16()
      } else if ch == 'b' {
        (2).to_uint16()
      } else {
        (0).to_uint16()
      }
    })
    |> ignore
    buf.push(cluster) |> ignore
  }
  buf.setup_positions(false)
  buf
}

test "apply_kern format0 pair" {
  let data = make_kern_format0_data()
  let buf = make_buffer_ab()
  apply_kern(data, 1U, buf)
  let pos = buf.positions()
  inspect(pos[0].advance, content="-20")
  inspect(pos[1].advance, content="0")
}

