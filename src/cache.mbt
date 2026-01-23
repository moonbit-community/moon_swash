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
test "CacheKey::new produces increasing keys" {
  let a = CacheKey::new().value()
  let b = CacheKey::new().value()
  inspect(a < b, content="true")
}
