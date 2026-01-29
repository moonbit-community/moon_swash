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
/// Shaping caches (font metadata + feature store).
///
/// Ported from `swash-reference/src/shape/cache.rs`.
pub type Epoch = UInt64

///|
pub struct FontEntry {
  metrics : @swash.MetricsProxy
  charmap : @swash.CharmapProxy
  coord_count : UInt16
  metadata : EngineMetadata
}

///|
pub fn FontEntry::new(font : @swash.FontRef) -> FontEntry {
  let coords = font.variations().iter().to_array()
  FontEntry::{
    metrics: @swash.MetricsProxy::from_font(font),
    charmap: @swash.CharmapProxy::from_font(font),
    coord_count: coords.length().to_uint16(),
    metadata: EngineMetadata::from_font(font),
  }
}

///|
priv struct FeatureEntry {
  mut epoch : Epoch
  mut id0 : UInt64
  mut id1 : UInt64
  coords : Array[Int]
  mut tags : (UInt, UInt, UInt, UInt)
  store : Ref[FeatureStore]
}

///|
priv struct FeatureCache {
  entries : Array[FeatureEntry]
  mut epoch : Epoch
  max_entries : Int
}

///|
priv enum FeatureCacheEntry {
  New(Ref[FeatureStore])
  Present(Ref[FeatureStore])
}

///|
fn FeatureCache::new(max_entries : Int) -> FeatureCache {
  let max_entries = if max_entries < 1 { 1 } else { max_entries }
  FeatureCache::{ entries: [], epoch: 0, max_entries }
}

///|
fn FeatureCache::entry(
  self : FeatureCache,
  id : (UInt64, UInt64),
  coords : ArrayView[Int],
  has_feature_vars : Bool,
  tags : (UInt, UInt, UInt, UInt),
) -> FeatureCacheEntry {
  let (found, index) = self.find_entry(id, coords, has_feature_vars, tags)
  let e = self.entries.at(index)
  e.epoch = self.epoch
  self.entries.set(index, e)
  if found {
    FeatureCacheEntry::Present(e.store)
  } else {
    FeatureCacheEntry::New(e.store)
  }
}

///|
fn coords_eq(a : ArrayView[Int], b : Array[Int]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<b.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
fn FeatureCache::find_entry(
  self : FeatureCache,
  id : (UInt64, UInt64),
  coords : ArrayView[Int],
  has_feature_vars : Bool,
  tags : (UInt, UInt, UInt, UInt),
) -> (Bool, Int) {
  let mut lowest_epoch = self.epoch
  let mut lowest_index = 0
  for i in 0..<self.entries.length() {
    let e = self.entries.at(i)
    if e.id0 == id.0 && e.id1 == id.1 && e.tags == tags {
      if !has_feature_vars || coords_eq(coords, e.coords) {
        return (true, i)
      }
    }
    if e.epoch < lowest_epoch {
      lowest_epoch = e.epoch
      lowest_index = i
    }
  }
  self.epoch = self.epoch + 1
  if self.entries.length() < self.max_entries {
    lowest_index = self.entries.length()
    self.entries.push(FeatureEntry::{
      epoch: self.epoch,
      id0: id.0,
      id1: id.1,
      coords: coords.to_array(),
      tags,
      store: Ref::new(FeatureStore::default()),
    })
  } else {
    let e = self.entries.at(lowest_index)
    e.epoch = self.epoch
    e.id0 = id.0
    e.id1 = id.1
    e.coords.clear()
    for c in coords.iter() {
      e.coords.push(c)
    }
    e.store.val.clear()
    e.tags = tags
    self.entries.set(lowest_index, e)
  }
  (false, lowest_index)
}
