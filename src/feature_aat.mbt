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
/// AAT (morx) feature enumeration.
///
/// Ported from `swash/src/feature/aat.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
const AAT_KERN : Tag = 0x6B65726E // "kern"

///|
priv struct AatFeatures {
  chains : Iter[@internal.MorxChain]
  has_features : Bool
  features : Iter[@internal.MorxFeature]
  kern : Bool
  seen : SeenFeatures
}

///|
fn AatFeatures::new(
  data : Bytes,
  morx_offset : UInt,
  kern : Bool,
) -> AatFeatures {
  let chains = @internal.morx_chains(data, morx_offset).iter()
  AatFeatures::{
    chains,
    has_features: false,
    features: Iter::new(fn() { None }),
    kern,
    seen: SeenFeatures::new(),
  }
}

///|
fn AatFeatures::iter(self : AatFeatures) -> Iter[(Tag, String)] {
  let chains = self.chains
  let mut has_features = self.has_features
  let mut features = self.features
  let mut kern = self.kern
  let seen = self.seen
  Iter::new(fn() {
    while true {
      if !has_features {
        match chains.next() {
          Some(chain) => {
            features = chain.features()
            has_features = true
          }
          None =>
            if kern {
              let desc = match desc_from_at(AAT_KERN) {
                None => "Kerning"
                Some((_, d)) => d
              }
              kern = false
              return Some((AAT_KERN, desc))
            } else {
              return None
            }
        }
      }
      match features.next() {
        None => {
          has_features = false
          continue
        }
        Some(f) =>
          match desc_from_aat(f.selector, f.setting_selector) {
            None => continue
            Some((ix, tag, desc)) =>
              if seen.mark(ix) {
                return Some((tag, desc))
              } else {
                continue
              }
          }
      }
    }
    None
  })
}
