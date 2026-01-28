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
/// AAT lookup table helpers.
///
/// Ported from `swash-reference/src/internal/aat.rs` (`lookup<T>`).

///|
pub fn aat_lookup_u16(b : BeBytes, offset : Int, id : UInt16) -> UInt16? {
  let element_size = 2
  let fmt = match b.read_u16(offset) {
    None => return None
    Some(v) => v.to_uint16()
  }
  match fmt {
    0 => {
      let off = offset + 2 + id.to_int() * element_size
      b.read_u16(off).map(x => x.to_uint16())
    }
    2 => {
      let reclen = 6 // max(4 + element_size, 6)
      let nrecs = b.read_u16(offset + 4).unwrap_or(0).reinterpret_as_int()
      let base = offset + 12
      let mut l = 0
      let mut h = nrecs
      while l < h {
        let i = (l + h) / 2
        let rec = base + i * reclen
        let last = match b.read_u16(rec) {
          None => return None
          Some(v) => v.to_uint16()
        }
        if id > last {
          l = i + 1
        } else {
          let first = match b.read_u16(rec + 2) {
            None => return None
            Some(v) => v.to_uint16()
          }
          if id < first {
            h = i
          } else {
            return b.read_u16(rec + 4).map(x => x.to_uint16())
          }
        }
      }
      None
    }
    4 => {
      let reclen = 6
      let nrecs = b.read_u16(offset + 4).unwrap_or(0).reinterpret_as_int()
      let base = offset + 12
      let mut l = 0
      let mut h = nrecs
      while l < h {
        let i = (l + h) / 2
        let rec = base + i * reclen
        let first = match b.read_u16(rec + 2) {
          None => return None
          Some(v) => v.to_uint16()
        }
        let last = match b.read_u16(rec) {
          None => return None
          Some(v) => v.to_uint16()
        }
        if id > last {
          l = i + 1
        } else if id < first {
          h = i
        } else {
          let index = id.to_int() - first.to_int()
          let value_off = match b.read_u16(rec + 4) {
            None => return None
            Some(v) => v.reinterpret_as_int()
          }
          let off = offset + value_off + index * element_size
          return b.read_u16(off).map(x => x.to_uint16())
        }
      }
      None
    }
    6 => {
      let reclen = 4 // max(2 + element_size, 4)
      let nrecs = b.read_u16(offset + 4).unwrap_or(0).reinterpret_as_int()
      let base = offset + 12
      let mut l = 0
      let mut h = nrecs
      while l < h {
        let i = (l + h) / 2
        let rec = base + i * reclen
        let glyph = match b.read_u16(rec) {
          None => return None
          Some(v) => v.to_uint16()
        }
        if id > glyph {
          l = i + 1
        } else if id < glyph {
          h = i
        } else {
          return b.read_u16(rec + 2).map(x => x.to_uint16())
        }
      }
      None
    }
    8 => {
      let first = match b.read_u16(offset + 2) {
        None => return None
        Some(v) => v.to_uint16()
      }
      let count = match b.read_u16(offset + 4) {
        None => return None
        Some(v) => v.to_uint16()
      }
      if id < first {
        return None
      }
      let index = id.to_int() - first.to_int()
      if index < 0 || index >= count.to_int() {
        return None
      }
      b.read_u16(offset + 6 + index * element_size).map(x => x.to_uint16())
    }
    10 => {
      let first = match b.read_u16(offset + 4) {
        None => return None
        Some(v) => v.to_uint16()
      }
      let count = match b.read_u16(offset + 6) {
        None => return None
        Some(v) => v.to_uint16()
      }
      if id < first {
        return None
      }
      let index = id.to_int() - first.to_int()
      if index < 0 || index >= count.to_int() {
        return None
      }
      b.read_u16(offset + 8 + index * element_size).map(x => x.to_uint16())
    }
    _ => None
  }
}

///|
fn aat_read_u16_array(b : BeBytes, offset : Int, len : Int) -> Array[UInt16]? {
  if len < 0 {
    return None
  }
  if !b.check_range(offset, len * 2) {
    return None
  }
  let out : Array[UInt16] = []
  out.reserve_capacity(len)
  for i in 0..<len {
    match b.read_u16(offset + i * 2) {
      None => return None
      Some(v) => out.push(v.to_uint16())
    }
  }
  Some(out)
}
