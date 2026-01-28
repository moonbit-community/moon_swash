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
/// Apple Advanced Typography (AAT) tables.
///
/// Ported from `swash-reference/src/internal/aat.rs`.

///|
pub const MORX : UInt = 0x6D6F7278 // "morx"

///|
pub const LTAG : UInt = 0x6C746167 // "ltag"

///|
pub const KERX : UInt = 0x6B657278 // "kerx"

///|
pub const ANKR : UInt = 0x616E6B72 // "ankr"

///|
pub const KERN : UInt = 0x6B65726E // "kern"

// Maximum number of times we allow consecutive DONT_ADVANCE states.

///|
const MAX_CYCLES : Int = 16

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
fn aat_subview(view : BytesView, start : Int) -> BytesView {
  if start < 0 || start > view.length() {
    aat_empty_view()
  } else {
    view.sub(start~)
  }
}
