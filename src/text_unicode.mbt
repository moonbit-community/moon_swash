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
/// Unicode character properties.
///
/// Ported from `swash/src/text/unicode.rs` (swash is dual-licensed Apache-2.0 OR MIT).
const RECORD_MASK : UInt = 0x1FFFU

///|
const BOUNDARY_SHIFT : Int = 13

///|
/// Compact reference to Unicode properties for a character.
pub struct Properties {
  bits : UInt
}

///|
fn Properties::new(cp : Int) -> Properties {
  Properties::{ bits: get_record_index(cp).reinterpret_as_uint() }
}

///|
fn Properties::record(self : Properties) -> Record {
  // Index is produced by `get_record_index` and masked to 13 bits.
  records[(self.bits & RECORD_MASK).reinterpret_as_int()]
}

///|
pub fn Properties::category(self : Properties) -> Category {
  self.record().category
}

///|
pub fn Properties::block(self : Properties) -> Block {
  self.record().block
}

///|
pub fn Properties::script(self : Properties) -> Script {
  self.record().script
}

///|
pub fn Properties::combining_class(self : Properties) -> UInt {
  self.record().combining_class
}

///|
pub fn Properties::bidi_class(self : Properties) -> BidiClass {
  self.record().bidi_class
}

///|
pub fn Properties::joining_type(self : Properties) -> JoiningType {
  self.record().joining_type
}

///|
pub fn Properties::cluster_break(self : Properties) -> ClusterBreak {
  self.record().cluster_break
}

///|
pub fn Properties::word_break(self : Properties) -> WordBreak {
  self.record().word_break
}

///|
pub fn Properties::line_break(self : Properties) -> LineBreak {
  self.record().line_break
}

///|
pub fn Properties::is_emoji(self : Properties) -> Bool {
  self.record().flags.is_emoji()
}

///|
pub fn Properties::is_extended_pictographic(self : Properties) -> Bool {
  self.record().flags.is_extended_pictographic()
}

///|
pub fn Properties::is_open_bracket(self : Properties) -> Bool {
  self.record().flags.is_open_bracket()
}

///|
pub fn Properties::is_close_bracket(self : Properties) -> Bool {
  self.record().flags.is_close_bracket()
}

///|
pub fn Properties::is_ignorable(self : Properties) -> Bool {
  self.record().flags.is_ignorable()
}

///|
pub fn Properties::is_variation_selector(self : Properties) -> Bool {
  self.record().flags.is_variation_selector()
}

///|
pub fn Properties::contributes_to_shaping(self : Properties) -> Bool {
  self.record().flags.contributes_to_shaping()
}

///|
pub fn Properties::with_boundary(
  self : Properties,
  boundary : UInt,
) -> Properties {
  Properties::{
    bits: (self.bits & RECORD_MASK) | ((boundary & 0b11U) << BOUNDARY_SHIFT),
  }
}

///|
pub fn Properties::boundary(self : Properties) -> UInt {
  self.bits >> BOUNDARY_SHIFT
}

///|
pub fn Properties::use_class(self : Properties) -> (UseClass, Bool, Bool) {
  let r = self.record()
  (r.use_class, r.flags.needs_decomp(), r.flags.is_extended_pictographic())
}

///|
pub fn Properties::myanmar_class(self : Properties) -> (MyanmarClass, Bool) {
  let r = self.record()
  (r.myanmar_class, r.flags.is_extended_pictographic())
}

///|
pub fn Properties::cluster_class(self : Properties) -> (ClusterBreak, Bool) {
  let r = self.record()
  (r.cluster_break, r.flags.is_extended_pictographic())
}

///|
pub(all) enum BracketType {
  None
  Open(Char)
  Close(Char)
}

///|
fn text_unicode_bsearch_first(
  table : ReadOnlyArray[(UInt, UInt)],
  key : UInt,
) -> Int? {
  let mut l = 0
  let mut h = table.length()
  while l < h {
    let mid = (l + h) / 2
    let (k, _) = table[mid]
    if k < key {
      l = mid + 1
    } else if k > key {
      h = mid
    } else {
      return Some(mid)
    }
  }
  None
}

///|
fn text_unicode_bsearch_second(
  table : ReadOnlyArray[(UInt, UInt)],
  key : UInt,
) -> Int? {
  let mut l = 0
  let mut h = table.length()
  while l < h {
    let mid = (l + h) / 2
    let (_, k) = table[mid]
    if k < key {
      l = mid + 1
    } else if k > key {
      h = mid
    } else {
      return Some(mid)
    }
  }
  None
}

///|
pub(open) trait Codepoint {
  properties(Self) -> Properties
  opening_bracket(Self) -> Char?
  closing_bracket(Self) -> Char?
  mirror(Self) -> Char?
  bracket_type(Self) -> BracketType
  decompose(Self) -> Decompose
  decompose_compatible(Self) -> Decompose
}

///|
pub impl Codepoint for Char with properties(self) {
  Properties::new(self.to_int())
}

///|
pub impl Codepoint for Char with opening_bracket(self) {
  let c = self.to_int().reinterpret_as_uint()
  match text_unicode_bsearch_second(brackets, c) {
    None => None
    Some(ix) => Some(brackets[ix].0.reinterpret_as_int().unsafe_to_char())
  }
}

///|
pub impl Codepoint for Char with closing_bracket(self) {
  let c = self.to_int().reinterpret_as_uint()
  match text_unicode_bsearch_first(brackets, c) {
    None => None
    Some(ix) => Some(brackets[ix].1.reinterpret_as_int().unsafe_to_char())
  }
}

///|
pub impl Codepoint for Char with mirror(self) {
  let c = self.to_int().reinterpret_as_uint()
  match text_unicode_bsearch_first(mirrors, c) {
    None => None
    Some(ix) => Some(mirrors[ix].1.reinterpret_as_int().unsafe_to_char())
  }
}

///|
pub impl Codepoint for Char with bracket_type(self) {
  match Codepoint::closing_bracket(self) {
    Some(other) => BracketType::Open(other)
    None =>
      match Codepoint::opening_bracket(self) {
        Some(other) => BracketType::Close(other)
        None => BracketType::None
      }
  }
}

///|
pub impl Codepoint for Char with decompose(self) {
  decompose(self)
}

///|
pub impl Codepoint for Char with decompose_compatible(self) {
  decompose_compat(self)
}

///|
pub fn BidiClass::needs_resolution(self : BidiClass) -> Bool {
  match self {
    RLE | LRE | RLO | LRO | RLI | LRI | FSI | R | AL | AN => true
    _ => false
  }
}
