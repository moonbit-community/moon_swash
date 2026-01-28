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
/// Hinting instance cache.
///
/// Ported from upstream `swash/src/scale/hinting_cache.rs` (Apache-2.0 OR MIT).

///|
const MAX_CACHED_HINT_INSTANCES : Int = 8

///|
fn hinting_options() -> @skrifa_outline.HintingOptions {
  @skrifa_outline.HintingMode::Smooth(
    Some(@skrifa_outline.LcdLayout::Horizontal),
    true,
  ).into()
}

///|
priv struct HintingEntry {
  id0 : UInt64
  id1 : UInt64
  size : @skrifa.Size
  coords : Array[Int]
  instance : @skrifa_outline.HintingInstance
  serial : UInt64
}

///|
fn size_eq(a : @skrifa.Size, b : @skrifa.Size) -> Bool {
  match (a.ppem(), b.ppem()) {
    (None, None) => true
    (Some(x), Some(y)) => x == y
    _ => false
  }
}

///|
fn coords_eq(a : ArrayView[Int], b : ArrayView[Int]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
fn effective_coords(loc : @skrifa.LocationRef) -> Array[Int] {
  let out : Array[Int] = []
  for c in loc.effective_coords().iter() {
    out.push(c)
  }
  out
}

///|
priv struct HintingCache {
  glyf_entries : Array[HintingEntry]
  cff_entries : Array[HintingEntry]
  mut serial : UInt64
}

///|
fn HintingCache::new() -> HintingCache {
  HintingCache::{ glyf_entries: [], cff_entries: [], serial: 0 }
}

///|
fn find_hinting_entry(
  entries : Array[HintingEntry],
  id0 : UInt64,
  id1 : UInt64,
  size : @skrifa.Size,
  coords : ArrayView[Int],
) -> (Int, Bool)? {
  let mut found_serial : UInt64 = 0xFFFFFFFFFFFFFFFF
  let mut found_index = 0
  for i in 0..<entries.length() {
    let e = entries[i]
    if e.id0 == id0 &&
      e.id1 == id1 &&
      size_eq(e.size, size) &&
      coords_eq(e.coords.op_as_view(), coords) {
      return Some((i, true))
    }
    if e.serial < found_serial {
      found_serial = e.serial
      found_index = i
    }
  }
  if entries.length() < MAX_CACHED_HINT_INSTANCES {
    Some((entries.length(), true))
  } else {
    Some((found_index, false))
  }
}

///|
fn HintingCache::get(
  self : HintingCache,
  id0 : UInt64,
  id1 : UInt64,
  outlines : @skrifa_outline.OutlineGlyphCollection,
  size : @skrifa.Size,
  loc : @skrifa.LocationRef,
) -> @skrifa_outline.HintingInstance? {
  let fmt = match outlines.format() {
    None => return None
    Some(f) => f
  }
  let entries = match fmt {
    @skrifa_outline.OutlineGlyphFormat::Glyf => self.glyf_entries
    _ => self.cff_entries
  }
  let coords = effective_coords(loc)
  match find_hinting_entry(entries, id0, id1, size, coords.op_as_view()) {
    None => None
    Some((ix, is_current)) => {
      self.serial = self.serial + 1
      if ix == entries.length() {
        match
          @skrifa_outline.HintingInstance::new(
            outlines,
            size,
            loc,
            hinting_options(),
          ) {
          Err(_) => None
          Ok(h) => {
            entries.push(HintingEntry::{
              id0,
              id1,
              size,
              coords,
              instance: h,
              serial: self.serial,
            })
            Some(entries[ix].instance)
          }
        }
      } else {
        let e = entries[ix]
        entries[ix] = HintingEntry::{
          id0: e.id0,
          id1: e.id1,
          size: e.size,
          coords: e.coords,
          instance: e.instance,
          serial: self.serial,
        }
        if is_current {
          Some(entries[ix].instance)
        } else {
          // Reuse the existing instance memory by reconfiguring it in-place.
          let e2 = entries[ix]
          let inst = e2.instance
          match inst.reconfigure(outlines, size, loc, hinting_options()) {
            Err(_) => None
            Ok(_) => {
              entries[ix] = HintingEntry::{
                id0,
                id1,
                size,
                coords,
                instance: inst,
                serial: self.serial,
              }
              Some(entries[ix].instance)
            }
          }
        }
      }
    }
  }
}
