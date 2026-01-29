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
/// AAT shaping helpers (morx/kerx/kern).
///
/// Ported from `swash-reference/src/shape/aat.rs`.

///|
fn selectors_contains(
  selectors : ArrayView[(UInt16, UInt16)],
  key : (UInt16, UInt16),
) -> Bool {
  let (ks, kv) = key
  let key_u = (ks.to_int().reinterpret_as_uint() << 16) |
    kv.to_int().reinterpret_as_uint()
  let mut l = 0
  let mut h = selectors.length()
  while l < h {
    let mid = (l + h) / 2
    let (s, v) = selectors[mid]
    let mid_u = (s.to_int().reinterpret_as_uint() << 16) |
      v.to_int().reinterpret_as_uint()
    if key_u > mid_u {
      l = mid + 1
    } else if key_u < mid_u {
      h = mid
    } else {
      return true
    }
  }
  false
}

///|
fn first_non_joining_index(buffer : Buffer) -> Int? {
  for i in 0..<buffer.glyphs.length() {
    if buffer.glyphs[i].joining_type != (6).to_byte() {
      return Some(i)
    }
  }
  None
}

///|
pub fn apply_morx(
  data : Bytes,
  morx : UInt,
  buffer : Buffer,
  selectors : ArrayView[(UInt16, UInt16)],
) -> Unit {
  let max_ops = buffer.glyphs.length() * 16
  for chain in @internal.morx_chains(data, morx).iter() {
    let mut ops = 0
    let mut flags = chain.default_flags()
    if selectors.length() != 0 {
      for feature in chain.features() {
        let key = (feature.selector, feature.setting_selector)
        if selectors_contains(selectors, key) {
          flags = (flags & feature.disable_flags) | feature.enable_flags
        }
      }
    }
    for subtable in chain.subtables().iter() {
      if (subtable.flags() & flags) == 0U {
        continue
      }
      let reverse = subtable.should_reverse(buffer.is_rtl)
      buffer.ensure_order(reverse)
      let kind = match subtable.kind() {
        None => continue
        Some(v) => v
      }
      match kind {
        @internal.MorxSubtableKind::Rearrangement(t) => {
          let mut i = 0
          let state = @internal.MorxRearrangementState::new()
          while i < buffer.glyphs.length() && ops < max_ops {
            let gid = buffer.glyphs[i].id
            match
              t.next(state, i, gid, false, fn(r) {
                r.apply(buffer.glyphs)
                Some(())
              }) {
              None => break
              Some(advance) => i = i + advance
            }
            ops = ops + 1
          }
          // END_OF_TEXT state.
          t.next(state, i, (0).to_uint16(), true, fn(r) {
            r.apply(buffer.glyphs)
            Some(())
          })
          |> ignore
        }
        @internal.MorxSubtableKind::Contextual(t) => {
          let state = @internal.MorxContextualState::new()
          for i in 0..<buffer.glyphs.length() {
            let gid = buffer.glyphs[i].id
            t.next(state, i, gid, false, fn(ix, g) {
              buffer.substitute(ix, g)
              Some(())
            })
            |> ignore
          }
          // END_OF_TEXT state.
          let len = buffer.glyphs.length()
          if len != 0 {
            let last_ix = len - 1
            let last_id = buffer.glyphs[last_ix].id
            t.next(state, last_ix, last_id, true, fn(ix, g) {
              buffer.substitute(ix, g)
              Some(())
            })
            |> ignore
          }
        }
        @internal.MorxSubtableKind::NonContextual(t) =>
          for i in 0..<buffer.glyphs.length() {
            let gid = buffer.glyphs[i].id
            match t.substitute(gid) {
              None => ()
              Some(s) => buffer.glyphs[i].id = s
            }
          }
        @internal.MorxSubtableKind::Ligature(t) => {
          let mut i = 0
          let state = @internal.MorxLigatureState::new()
          while i < buffer.glyphs.length() && ops < max_ops {
            let gid = buffer.glyphs[i].id
            if t.next(state, i, gid, false, fn(ix, g, comps) {
                buffer.substitute_ligature(ix, g, comps)
                Some(())
              })
              is None {
              break
            }
            i = i + 1
            ops = ops + 1
          }
          // END_OF_TEXT state.
          let len = buffer.glyphs.length()
          let last_ix = if len == 0 { 0 } else { len - 1 }
          t.next(state, last_ix, (0).to_uint16(), true, fn(ix, g, comps) {
            buffer.substitute_ligature(ix, g, comps)
            Some(())
          })
          |> ignore
        }
        @internal.MorxSubtableKind::Insertion(t) => {
          let mut i = 0
          let state = @internal.MorxInsertionState::new()
          while i < buffer.glyphs.length() && ops < max_ops {
            let gid = buffer.glyphs[i].id
            match
              t.next(state, i, gid, false, fn(ix, array) {
                let count = array.length()
                buffer.multiply(ix, count)
                let start = ix
                let end = start + count
                for j in start..<end {
                  buffer.glyphs[j].id = array[j - start]
                  buffer.glyphs[j].flags = (0).to_uint16()
                }
                Some(())
              }) {
              None => break
              Some(advance) => i = i + advance
            }
            ops = ops + 1
          }
          // END_OF_TEXT state.
          let len = buffer.glyphs.length()
          let last_ix = if len == 0 { 0 } else { len - 1 }
          t.next(state, last_ix, (0).to_uint16(), true, fn(ix, array) {
            let count = array.length()
            buffer.multiply(ix, count)
            let start = ix
            let end = start + count
            for j in start..<end {
              buffer.glyphs[j].id = array[j - start]
              buffer.glyphs[j].flags = (0).to_uint16()
            }
            Some(())
          })
          |> ignore
        }
      }
    }
  }
  buffer.ensure_order(false)
}

///|
pub fn apply_kerx(
  data : Bytes,
  kerx : UInt,
  ankr : UInt,
  buffer : Buffer,
  disable_kern : Bool,
) -> Unit {
  for subtable in @internal.kerx_subtables(data, kerx, ankr).iter() {
    let reverse = subtable.should_reverse(buffer.is_rtl)
    buffer.ensure_order(reverse)
    match subtable.kind() {
      None => continue
      Some(kind) => {
        if subtable.is_vertical() || subtable.is_cross_stream() {
          continue
        }
        match kind {
          @internal.KerxSubtableKind::Format0(t) => {
            if disable_kern {
              continue
            }
            let len = buffer.len()
            let left_index_opt = first_non_joining_index(buffer)
            let mut left_index = match left_index_opt {
              None => continue
              Some(v) => v
            }
            let mut left = buffer.glyphs[left_index].id
            for i in (left_index + 1)..<len {
              if buffer.glyphs[i].joining_type == (6).to_byte() {
                continue
              }
              let right = buffer.glyphs[i].id
              match t.get(left, right) {
                None => ()
                Some(k) =>
                  if k != 0 {
                    buffer.positions[left_index].advance = buffer.positions[left_index].advance +
                      k.to_double()
                  }
              }
              left_index = i
              left = right
            }
          }
          @internal.KerxSubtableKind::Format1(t) => {
            if disable_kern {
              continue
            }
            let mut i = 0
            let len = buffer.glyphs.length()
            let state = @internal.KerxContextualState::new()
            while i < len {
              match
                t.next(state, i, buffer.glyphs[i].id, fn(ix, k) {
                  buffer.positions[ix].advance = buffer.positions[ix].advance +
                    k.to_double()
                  Some(())
                }) {
                None => break
                Some(advance) => i = i + advance
              }
            }
          }
          @internal.KerxSubtableKind::Format2(t) => {
            if disable_kern {
              continue
            }
            let len = buffer.len()
            let left_index_opt = first_non_joining_index(buffer)
            let mut left_index = match left_index_opt {
              None => continue
              Some(v) => v
            }
            let mut left = buffer.glyphs[left_index].id
            for i in (left_index + 1)..<len {
              if buffer.glyphs[i].joining_type == (6).to_byte() {
                continue
              }
              let right = buffer.glyphs[i].id
              match t.get(left, right) {
                None => ()
                Some(k) =>
                  if k != 0 {
                    buffer.positions[left_index].advance = buffer.positions[left_index].advance +
                      k.to_double()
                  }
              }
              left_index = i
              left = right
            }
          }
          @internal.KerxSubtableKind::Format4(t) => {
            let mut i = 0
            let len = buffer.glyphs.length()
            let state = @internal.KerxFormat4State::new()
            while i < len {
              match
                t.next(state, i, buffer.glyphs[i].id, fn(ix, base, x, y) {
                  buffer.position_mark(ix, base, x, y)
                  Some(())
                }) {
                None => break
                Some(advance) => i = i + advance
              }
            }
          }
        }
      }
    }
  }
  buffer.ensure_order(false)
}

///|
pub fn apply_kern(data : Bytes, kern : UInt, buffer : Buffer) -> Unit {
  for subtable in @internal.kern_subtables(data, kern).iter() {
    let kind = match subtable.kind() {
      None => continue
      Some(v) => v
    }
    if !subtable.is_horizontal() {
      continue
    }
    buffer.ensure_order(buffer.is_rtl)
    let cross_stream = subtable.cross_stream()
    match kind {
      @internal.KernSubtableKind::Format0(t) => {
        buffer.ensure_order(false)
        let len = buffer.len()
        let left_index_opt = first_non_joining_index(buffer)
        let mut left_index = match left_index_opt {
          None => continue
          Some(v) => v
        }
        let mut left = buffer.glyphs[left_index].id
        for i in (left_index + 1)..<len {
          if buffer.glyphs[i].joining_type == (6).to_byte() {
            continue
          }
          let right = buffer.glyphs[i].id
          match t.get(left, right) {
            None => ()
            Some(k) =>
              if k != 0 {
                buffer.positions[left_index].advance = buffer.positions[left_index].advance +
                  k.to_double()
              }
          }
          left_index = i
          left = right
        }
      }
      @internal.KernSubtableKind::Format1(t) => {
        let mut i = 0
        let len = buffer.glyphs.length()
        let state = @internal.KernFormat1State::new()
        while i < len {
          match
            t.next(state, i, buffer.glyphs[i].id, fn(ix, k) {
              let g = buffer.glyphs[ix]
              if g.joining_type == (6).to_byte() {
                if cross_stream {
                  if buffer.positions[ix].y == 0.0 {
                    buffer.positions[ix].y = k.to_double()
                  }
                } else {
                  match find_base(buffer, buffer.is_rtl, ix) {
                    None => ()
                    Some(base) => {
                      let diff = if base >= ix { base - ix } else { ix - base }
                      if diff < 255 {
                        if buffer.positions[ix].base == (0).to_byte() {
                          buffer.position_mark(ix, base, k.to_double(), 0.0)
                        }
                      }
                    }
                  }
                }
              }
              Some(())
            }) {
            None => break
            Some(advance) => i = i + advance
          }
        }
      }
    }
  }
  buffer.ensure_order(false)
}

///|
fn find_base(buffer : Buffer, reverse : Bool, index : Int) -> Int? {
  let cluster = buffer.glyphs[index].cluster
  if reverse {
    for i in (index + 1)..<buffer.len() {
      let g = buffer.glyphs[i]
      if g.cluster != cluster {
        return None
      }
      if g.char_class is ShapeClass::Base {
        return Some(i)
      }
    }
  } else if index > 0 {
    let mut i = index - 1
    while i >= 0 {
      let g = buffer.glyphs[i]
      if g.cluster != cluster {
        return None
      }
      if g.char_class is ShapeClass::Base {
        return Some(i)
      }
      if i == 0 {
        break
      }
      i = i - 1
    }
  }
  None
}
