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
/// Font caching primitives.
///
/// Ported from `swash/src/cache.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
/// Uniquely generated value for identifying and caching fonts.
pub struct CacheKey {
  value : UInt64
}

///|
let key_counter : Ref[UInt64] = Ref::new((1).to_uint64())

///|
pub fn CacheKey::new() -> CacheKey {
  // swash uses AtomicUsize; we only target single-thread for now.
  let v = key_counter.val
  key_counter.val = v + 1
  CacheKey::{ value: v }
}

///|
pub fn CacheKey::value(self : CacheKey) -> UInt64 {
  self.value
}

///|
/// Simple LRU cache keyed by a custom font identifier.
///
/// Ported from `swash/src/cache.rs` (`FontCache<T>`).
pub struct FontCache[T] {
  entries : Array[Entry[T]]
  max_entries : Int
  mut epoch : UInt64
}

///|
struct Entry[T] {
  mut epoch : UInt64
  mut id0 : UInt64
  mut id1 : UInt64
  mut data : Ref[T]
}

///|
pub fn[T] FontCache::new(max_entries : Int) -> FontCache[T] {
  let max_entries = if max_entries < 1 { 1 } else { max_entries }
  FontCache::{ entries: [], max_entries, epoch: 0 }
}

///|
fn[T] FontCache::find(
  self : FontCache[T],
  id0 : UInt64,
  id1 : UInt64,
) -> (Bool, Int) {
  let mut lowest = 0
  let mut lowest_epoch = self.epoch
  for i in 0..<self.entries.length() {
    let e = self.entries.at(i)
    if e.id0 == id0 && e.id1 == id1 {
      return (true, i)
    }
    if e.epoch < lowest_epoch {
      lowest_epoch = e.epoch
      lowest = i
    }
  }
  if self.entries.length() < self.max_entries {
    (false, self.entries.length())
  } else {
    (false, lowest)
  }
}

///|
pub fn[T] FontCache::get(
  self : FontCache[T],
  font : FontRef,
  id_override : (UInt64, UInt64)?,
  f : (FontRef) -> T,
) -> ((UInt64, UInt64), Ref[T]) {
  let (id0, id1) = match id_override {
    None => (font.key().value(), (-1).to_int64().reinterpret_as_uint64())
    Some((a, b)) => (a, b)
  }
  let (found, index) = self.find(id0, id1)
  if found {
    let e = self.entries.at(index)
    e.epoch = self.epoch
    self.entries.set(index, e)
    ((e.id0, e.id1), e.data)
  } else {
    self.epoch = self.epoch + 1
    let data = Ref::new(f(font))
    if index == self.entries.length() {
      self.entries.push(Entry::{ epoch: self.epoch, id0, id1, data })
      ((id0, id1), self.entries.at(index).data)
    } else {
      let e = self.entries.at(index)
      e.epoch = self.epoch
      e.id0 = id0
      e.id1 = id1
      e.data = data
      self.entries.set(index, e)
      ((id0, id1), self.entries.at(index).data)
    }
  }
}

///|
test "CacheKey::new produces increasing keys" {
  let a = CacheKey::new().value()
  let b = CacheKey::new().value()
  inspect(a < b, content="true")
}

///|
test "FontCache caches and evicts by max_entries" {
  // Minimal TTF header tag 0x00010000 is enough for FontRef::from_offset.
  let data = Bytes::from_array([0, 1, 0, 0])
  let f0 = FontRef::from_offset(data, 0).unwrap()
  let f1 = FontRef::from_offset(data, 0).unwrap()
  let cache : FontCache[Int] = FontCache::new(1)
  let calls = Ref::new(0)
  fn mk(calls : Ref[Int], v : Int) -> (FontRef) -> Int {
    fn(font) {
      calls.val = calls.val + 1
      // ensure the font value is used to avoid unused warnings
      font.offset() |> ignore
      v
    }
  }

  let (_, r0) = cache.get(f0, None, mk(calls, 10))
  let (_, r0_again) = cache.get(f0, None, mk(calls, 99))
  inspect(r0.val, content="10")
  inspect(r0_again.val, content="10")
  inspect(calls.val, content="1")
  let (_, r1) = cache.get(f1, None, mk(calls, 20))
  inspect(r1.val, content="20")
  inspect(calls.val, content="2")

  // f0 was evicted (max_entries=1), so this will repopulate.
  let (_, r0_new) = cache.get(f0, None, mk(calls, 30))
  inspect(r0_new.val, content="30")
  inspect(calls.val, content="3")
}
