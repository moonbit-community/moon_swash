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
/// Unicode normalization helpers (compose/decompose).
///
/// Ported from `swash/src/text/compose.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
pub type Decompose = Iter[Char]

///|
fn decompose_single(c : Char) -> Iter[Char] {
  let mut done = false
  Iter::new(fn() {
    if done {
      None
    } else {
      done = true
      Some(c)
    }
  })
}

///|
const LBASE : Int = 0x1100

///|
const VBASE : Int = 0x1161

///|
const TBASE : Int = 0x11A7

///|
const LCOUNT : Int = 19

///|
const VCOUNT : Int = 21

///|
const TCOUNT : Int = 28

///|
const SBASE : Int = 0xAC00

///|
const NCOUNT : Int = VCOUNT * TCOUNT

///|
const SCOUNT : Int = LCOUNT * NCOUNT

///|
fn is_hangul_syllable(c : Int) -> Bool {
  c >= SBASE && c < SBASE + SCOUNT
}

///|
fn compose_hangul(a : Int, b : Int) -> Int? {
  if b < VBASE || b >= TBASE + TCOUNT {
    return None
  }
  if !((a >= LBASE && a < LBASE + LCOUNT) || (a >= SBASE && a < SBASE + SCOUNT)) {
    return None
  }
  if a >= SBASE {
    if (a - SBASE) % TCOUNT == 0 {
      Some(a + (b - TBASE))
    } else {
      None
    }
  } else {
    let li = a - LBASE
    let vi = b - VBASE
    Some(SBASE + li * NCOUNT + vi * TCOUNT)
  }
}

///|
fn pair_index(c : Int, table : ReadOnlyArray[(UInt, UInt, UInt)]) -> Int? {
  for entry in table.iter() {
    let (start_u, len_u, base_u) = entry
    let start = start_u.reinterpret_as_int()
    if start == 0 || c < start {
      return None
    }
    let end = start + len_u.reinterpret_as_int()
    if c <= end {
      return Some(base_u.reinterpret_as_int() + (c - start))
    }
  }
  None
}

///|
pub fn compose_pair(a : Char, b : Char) -> Char? {
  let a = a.to_int()
  let b = b.to_int()
  match compose_hangul(a, b) {
    Some(cp) => Some(cp.unsafe_to_char())
    None => {
      let l = match pair_index(a, compose0) {
        None => return None
        Some(v) => v
      }
      let r = match pair_index(b, compose1) {
        None => return None
        Some(v) => v
      }
      let c = compose_index(l * COMPOSE1_COUNT + r)
      if c != 0 {
        Some(c.unsafe_to_char())
      } else {
        None
      }
    }
  }
}

///|
fn decompose_hangul(c : Int) -> Iter[Char] {
  let si = c - SBASE
  let li = si / NCOUNT
  let vi = si % NCOUNT / TCOUNT
  let ti = si % TCOUNT
  let l = (LBASE + li).unsafe_to_char()
  let v = (VBASE + vi).unsafe_to_char()
  let t = (TBASE + ti).unsafe_to_char()
  let mut cur = 0
  let len = if ti > 0 { 3 } else { 2 }
  Iter::new(fn() {
    if cur >= len {
      return None
    }
    let i = cur
    cur = cur + 1
    if i == 0 {
      Some(l)
    } else if i == 1 {
      Some(v)
    } else {
      Some(t)
    }
  })
}

///|
pub fn decompose(c : Char) -> Iter[Char] {
  let cp = c.to_int()
  if cp <= 0x7F {
    decompose_single(c)
  } else if is_hangul_syllable(cp) {
    decompose_hangul(cp)
  } else {
    let index = decompose_index(cp)
    if index == 0 {
      decompose_single(c)
    } else {
      let len = decompose_data[index].reinterpret_as_int()
      let start = index + 1
      let mut cur = 0
      Iter::new(fn() {
        if cur >= len {
          return None
        }
        let c = decompose_data[start + cur]
          .reinterpret_as_int()
          .unsafe_to_char()
        cur = cur + 1
        Some(c)
      })
    }
  }
}

///|
pub fn decompose_compat(c : Char) -> Iter[Char] {
  let cp = c.to_int()
  if cp <= 0x7F {
    decompose_single(c)
  } else if is_hangul_syllable(cp) {
    decompose_hangul(cp)
  } else {
    let index = decompose_compat_index(cp)
    if index == 0 {
      decompose_single(c)
    } else if index == 1 {
      decompose(c)
    } else {
      let len = decompose_compat_data[index].reinterpret_as_int()
      let start = index + 1
      let mut cur = 0
      Iter::new(fn() {
        if cur >= len {
          return None
        }
        let c = decompose_compat_data[start + cur]
          .reinterpret_as_int()
          .unsafe_to_char()
        cur = cur + 1
        Some(c)
      })
    }
  }
}
