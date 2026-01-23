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
/// Font header tables.
///
/// Ported from `swash/src/internal/head.rs` (swash is dual-licensed Apache-2.0 OR MIT).
pub const HEAD : RawTag = 0x68656164 // "head"

///|
pub const OS_2 : RawTag = 0x4F532F32 // "OS/2"

///|
pub const POST : RawTag = 0x706F7374 // "post"

///|
pub const MAXP : RawTag = 0x6D617870 // "maxp"

///|
pub const HHEA : RawTag = 0x68686561 // "hhea"

///|
pub const VHEA : RawTag = 0x76686561 // "vhea"

///|
/// Font header table.
pub struct Head {
  data : BytesView
}

///|
pub const HEAD_MAGIC : UInt = 0x5F0F3CF5

///|
pub fn Head::new(data : BytesView) -> Head {
  Head::{ data, }
}

///|
pub fn[T : RawFont] Head::from_font(font : T) -> Head? {
  table_data(font, HEAD).map(Head::new)
}

///|
pub fn Head::major_version(self : Head) -> UInt {
  BeBytes::from_view(self.data).read_u16(0).unwrap_or(0)
}

///|
pub fn Head::minor_version(self : Head) -> UInt {
  BeBytes::from_view(self.data).read_u16(2).unwrap_or(0)
}

///|
pub fn Head::revision(self : Head) -> UInt {
  BeBytes::from_view(self.data).read_u32(4).unwrap_or(0)
}

///|
pub fn Head::checksum_adjustment(self : Head) -> UInt {
  BeBytes::from_view(self.data).read_u32(8).unwrap_or(0)
}

///|
pub fn Head::magic(self : Head) -> UInt {
  BeBytes::from_view(self.data).read_u32(12).unwrap_or(0)
}

///|
pub fn Head::flags(self : Head) -> UInt {
  BeBytes::from_view(self.data).read_u16(16).unwrap_or(0)
}

///|
pub fn Head::units_per_em(self : Head) -> UInt {
  BeBytes::from_view(self.data).read_u16(18).unwrap_or(0)
}

///|
pub fn Head::created(self : Head) -> UInt64 {
  BeBytes::from_view(self.data).read_u64(20).unwrap_or(0)
}

///|
pub fn Head::modified(self : Head) -> UInt64 {
  BeBytes::from_view(self.data).read_u64(28).unwrap_or(0)
}

///|
pub fn Head::bounds(self : Head) -> ((Int, Int), (Int, Int)) {
  let b = BeBytes::from_view(self.data)
  let x_min = b.read_i16(36).unwrap_or(0)
  let y_min = b.read_i16(38).unwrap_or(0)
  let x_max = b.read_i16(40).unwrap_or(0)
  let y_max = b.read_i16(42).unwrap_or(0)
  ((x_min, y_min), (x_max, y_max))
}

///|
pub fn Head::mac_style(self : Head) -> UInt {
  BeBytes::from_view(self.data).read_u16(44).unwrap_or(0)
}

///|
pub fn Head::lowest_recommended_ppem(self : Head) -> UInt {
  BeBytes::from_view(self.data).read_u16(46).unwrap_or(0)
}

///|
pub fn Head::direction_hint(self : Head) -> UInt {
  BeBytes::from_view(self.data).read_u16(48).unwrap_or(0)
}

///|
pub fn Head::index_to_location_format(self : Head) -> UInt {
  BeBytes::from_view(self.data).read_u16(50).unwrap_or(0)
}

///|
pub fn Head::glyph_data_format(self : Head) -> Int {
  BeBytes::from_view(self.data).read_i16(52).unwrap_or(0)
}

///|
/// Maximum profile table.
pub struct Maxp {
  data : BytesView
}

///|
pub fn Maxp::new(data : BytesView) -> Maxp {
  Maxp::{ data, }
}

///|
pub fn[T : RawFont] Maxp::from_font(font : T) -> Maxp? {
  table_data(font, MAXP).map(Maxp::new)
}

///|
pub fn Maxp::version(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u32(0).unwrap_or(0)
}

///|
pub fn Maxp::glyph_count(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(4).unwrap_or(0)
}

///|
pub fn Maxp::is_truetype(self : Maxp) -> Bool {
  self.version() == 0x00010000
}

///|
/// Horizontal header table.
pub struct Hhea {
  data : BytesView
}

///|
pub fn Hhea::new(data : BytesView) -> Hhea {
  Hhea::{ data, }
}

///|
pub fn[T : RawFont] Hhea::from_font(font : T) -> Hhea? {
  table_data(font, HHEA).map(Hhea::new)
}

///|
pub fn Hhea::ascender(self : Hhea) -> Int {
  BeBytes::from_view(self.data).read_i16(4).unwrap_or(0)
}

///|
pub fn Hhea::descender(self : Hhea) -> Int {
  BeBytes::from_view(self.data).read_i16(6).unwrap_or(0)
}

///|
pub fn Hhea::line_gap(self : Hhea) -> Int {
  BeBytes::from_view(self.data).read_i16(8).unwrap_or(0)
}

///|
pub fn Hhea::max_advance(self : Hhea) -> UInt {
  BeBytes::from_view(self.data).read_u16(10).unwrap_or(0)
}

///|
pub fn Hhea::num_long_metrics(self : Hhea) -> UInt {
  BeBytes::from_view(self.data).read_u16(34).unwrap_or(0)
}

///|
/// Vertical header table.
pub struct Vhea {
  data : BytesView
}

///|
pub fn Vhea::new(data : BytesView) -> Vhea {
  Vhea::{ data, }
}

///|
pub fn[T : RawFont] Vhea::from_font(font : T) -> Vhea? {
  table_data(font, VHEA).map(Vhea::new)
}

///|
pub fn Vhea::ascender(self : Vhea) -> Int {
  BeBytes::from_view(self.data).read_i16(4).unwrap_or(0)
}

///|
pub fn Vhea::descender(self : Vhea) -> Int {
  BeBytes::from_view(self.data).read_i16(6).unwrap_or(0)
}

///|
pub fn Vhea::line_gap(self : Vhea) -> Int {
  BeBytes::from_view(self.data).read_i16(8).unwrap_or(0)
}

///|
pub fn Vhea::max_advance(self : Vhea) -> UInt {
  BeBytes::from_view(self.data).read_u16(10).unwrap_or(0)
}

///|
pub fn Vhea::num_long_metrics(self : Vhea) -> UInt {
  BeBytes::from_view(self.data).read_u16(34).unwrap_or(0)
}
