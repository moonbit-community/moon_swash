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
/// Apple Advanced Typography helpers (minimal subset).
///
/// Ported from `swash/src/internal/aat.rs` (module `morx` only; chains + features).

///|
fn aat_empty_view() -> BytesView {
  Bytes::from_array([])[:]
}

///|
fn aat_slice_from(data : Bytes, start : UInt) -> BytesView {
  let s = start.reinterpret_as_int()
  if s < 0 || s > data.length() {
    aat_empty_view()
  } else {
    data[s:]
  }
}

///|
pub struct MorxChains {
  b : BeBytes
  offset : Int
  len : UInt
  cur : UInt
}

///|
pub fn morx_chains(data : Bytes, offset : UInt) -> MorxChains {
  let view = if offset == 0U {
    aat_empty_view()
  } else {
    aat_slice_from(data, offset)
  }
  let b = BeBytes::from_view(view)
  let len = b.read_u32(4).unwrap_or(0)
  MorxChains::{ b, offset: 8, len, cur: 0U }
}

///|
pub struct MorxChain {
  b : BeBytes
  offset : Int
  feature_count : UInt
}

///|
pub fn MorxChains::iter(self : MorxChains) -> Iter[MorxChain] {
  let b = self.b
  let mut offset = self.offset
  let len = self.len
  let mut cur = self.cur
  Iter::new(fn() {
    if cur >= len {
      return None
    }
    cur = cur + 1U
    let base = offset
    let chain_len = match b.read_u32(base + 4) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    offset = offset + chain_len
    let feature_count = match b.read_u32(base + 8) {
      None => return None
      Some(v) => v
    }
    Some(MorxChain::{ b, offset: base, feature_count })
  })
}

///|
pub struct MorxFeature {
  selector : UInt16
  setting_selector : UInt16
}

///|
pub fn MorxChain::features(self : MorxChain) -> Iter[MorxFeature] {
  let b = self.b
  let base = self.offset + 16
  let len = self.feature_count.reinterpret_as_int()
  let mut cur = 0
  Iter::new(fn() {
    if cur >= len {
      return None
    }
    let i = cur
    cur = cur + 1
    let off = base + i * 12
    let selector = match b.read_u16(off) {
      None => return None
      Some(v) => v.to_uint16()
    }
    let setting_selector = match b.read_u16(off + 2) {
      None => return None
      Some(v) => v.to_uint16()
    }
    Some(MorxFeature::{ selector, setting_selector })
  })
}
