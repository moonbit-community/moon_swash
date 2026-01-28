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
/// OS/2 and Windows metrics table.
pub struct Os2 {
  data : BytesView
}

///|
pub fn Os2::new(data : BytesView) -> Os2 {
  Os2::{ data, }
}

///|
pub fn[T : RawFont] Os2::from_font(font : T) -> Os2? {
  table_data(font, OS_2).map(Os2::new)
}

///|
pub fn Os2::version(self : Os2) -> UInt {
  BeBytes::from_view(self.data).read_u16(0).unwrap_or(0)
}

///|
pub fn Os2::average_char_width(self : Os2) -> Int {
  BeBytes::from_view(self.data).read_i16(2).unwrap_or(0)
}

///|
pub fn Os2::weight_class(self : Os2) -> Int {
  BeBytes::from_view(self.data).read_i16(4).unwrap_or(0)
}

///|
pub fn Os2::width_class(self : Os2) -> Int {
  BeBytes::from_view(self.data).read_i16(6).unwrap_or(0)
}

///|
pub fn Os2::strikeout_position(self : Os2) -> Int {
  BeBytes::from_view(self.data).read_i16(28).unwrap_or(0)
}

///|
pub fn Os2::strikeout_size(self : Os2) -> Int {
  BeBytes::from_view(self.data).read_i16(26).unwrap_or(0)
}

///|
pub struct Os2Flags {
  value : UInt
}

///|
pub fn Os2Flags::use_typographic_metrics(self : Os2Flags) -> Bool {
  (self.value & ((1).reinterpret_as_uint() << 7)) != 0
}

///|
pub fn Os2Flags::italic(self : Os2Flags) -> Bool {
  (self.value & ((1).reinterpret_as_uint() << 0)) != 0
}

///|
pub fn Os2Flags::oblique(self : Os2Flags) -> Bool {
  (self.value & ((1).reinterpret_as_uint() << 9)) != 0
}

///|
pub fn Os2::selection_flags(self : Os2) -> Os2Flags {
  Os2Flags::{ value: BeBytes::from_view(self.data).read_u16(62).unwrap_or(0) }
}

///|
pub fn Os2::typographic_ascender(self : Os2) -> Int {
  BeBytes::from_view(self.data).read_i16(68).unwrap_or(0)
}

///|
pub fn Os2::typographic_descender(self : Os2) -> Int {
  BeBytes::from_view(self.data).read_i16(70).unwrap_or(0)
}

///|
pub fn Os2::typographic_line_gap(self : Os2) -> Int {
  BeBytes::from_view(self.data).read_i16(72).unwrap_or(0)
}

///|
pub fn Os2::x_height(self : Os2) -> Int {
  if self.version() < 2 {
    0
  } else {
    BeBytes::from_view(self.data).read_i16(86).unwrap_or(0)
  }
}

///|
pub fn Os2::cap_height(self : Os2) -> Int {
  if self.version() < 2 {
    0
  } else {
    BeBytes::from_view(self.data).read_i16(88).unwrap_or(0)
  }
}

///|
/// PostScript table.
pub struct Post {
  data : BytesView
}

///|
pub fn Post::new(data : BytesView) -> Post {
  Post::{ data, }
}

///|
pub fn[T : RawFont] Post::from_font(font : T) -> Post? {
  table_data(font, POST).map(Post::new)
}

///|
pub fn Post::underline_position(self : Post) -> Int {
  BeBytes::from_view(self.data).read_i16(8).unwrap_or(0)
}

///|
pub fn Post::underline_size(self : Post) -> Int {
  BeBytes::from_view(self.data).read_i16(10).unwrap_or(0)
}

///|
pub fn Post::is_fixed_pitch(self : Post) -> Bool {
  BeBytes::from_view(self.data).read_u32(12).unwrap_or(0) != 0
}

///|
pub fn Post::data(self : Post) -> BytesView {
  self.data
}

///|
pub fn Post::version(self : Post) -> UInt {
  BeBytes::from_view(self.data).read_u32(0).unwrap_or(0)
}

///|
pub fn Post::italic_angle(self : Post) -> UInt {
  BeBytes::from_view(self.data).read_u32(4).unwrap_or(0)
}

///|
/// Returns true if the table can provide glyph names. Only versions 1.0 and 2.0.
pub fn Post::has_names(self : Post) -> Bool {
  let v = self.version()
  v == 0x00010000 || v == 0x00020000
}

///|
fn post_ascii_string(bytes : BytesView) -> String? {
  let chars : Array[Char] = []
  for i in 0..<bytes.length() {
    let b = match bytes.get(i) {
      None => return None
      Some(v) => v.to_int()
    }
    if b < 0 || b >= 128 {
      return None
    }
    match b.to_char() {
      None => return None
      Some(c) => chars.push(c)
    }
  }
  Some(String::from_array(chars.op_as_view()))
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
pub fn Maxp::max_points(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(6).unwrap_or(0)
}

///|
pub fn Maxp::max_contours(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(8).unwrap_or(0)
}

///|
pub fn Maxp::max_composite_points(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(10).unwrap_or(0)
}

///|
pub fn Maxp::max_composite_contours(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(12).unwrap_or(0)
}

///|
pub fn Maxp::max_zones(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(14).unwrap_or(0)
}

///|
pub fn Maxp::max_twilight_points(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(16).unwrap_or(0)
}

///|
pub fn Maxp::max_storage(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(18).unwrap_or(0)
}

///|
pub fn Maxp::max_function_definitions(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(20).unwrap_or(0)
}

///|
pub fn Maxp::max_instruction_definitions(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(22).unwrap_or(0)
}

///|
pub fn Maxp::max_stack_depth(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(24).unwrap_or(0)
}

///|
pub fn Maxp::max_instructions_size(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(26).unwrap_or(0)
}

///|
pub fn Maxp::max_component_elements(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(28).unwrap_or(0)
}

///|
pub fn Maxp::max_component_depth(self : Maxp) -> UInt {
  BeBytes::from_view(self.data).read_u16(30).unwrap_or(0)
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

///|
let default_glyph_names : ReadOnlyArray[String] = [
  ".notdef", ".null", "nonmarkingreturn", "space", "exclam", "quotedbl", "numbersign",
  "dollar", "percent", "ampersand", "quotesingle", "parenleft", "parenright", "asterisk",
  "plus", "comma", "hyphen", "period", "slash", "zero", "one", "two", "three", "four",
  "five", "six", "seven", "eight", "nine", "colon", "semicolon", "less", "equal",
  "greater", "question", "at", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
  "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
  "bracketleft", "backslash", "bracketright", "asciicircum", "underscore", "grave",
  "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
  "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "braceleft", "bar", "braceright",
  "asciitilde", "Adieresis", "Aring", "Ccedilla", "Eacute", "Ntilde", "Odieresis",
  "Udieresis", "aacute", "agrave", "acircumflex", "adieresis", "atilde", "aring",
  "ccedilla", "eacute", "egrave", "ecircumflex", "edieresis", "iacute", "igrave",
  "icircumflex", "idieresis", "ntilde", "oacute", "ograve", "ocircumflex", "odieresis",
  "otilde", "uacute", "ugrave", "ucircumflex", "udieresis", "dagger", "degree", "cent",
  "sterling", "section", "bullet", "paragraph", "germandbls", "registered", "copyright",
  "trademark", "acute", "dieresis", "notequal", "AE", "Oslash", "infinity", "plusminus",
  "lessequal", "greaterequal", "yen", "mu", "partialdiff", "summation", "product",
  "pi", "integral", "ordfeminine", "ordmasculine", "Omega", "ae", "oslash", "questiondown",
  "exclamdown", "logicalnot", "radical", "florin", "approxequal", "Delta", "guillemotleft",
  "guillemotright", "ellipsis", "nonbreakingspace", "Agrave", "Atilde", "Otilde",
  "OE", "oe", "endash", "emdash", "quotedblleft", "quotedblright", "quoteleft", "quoteright",
  "divide", "lozenge", "ydieresis", "Ydieresis", "fraction", "currency", "guilsinglleft",
  "guilsinglright", "fi", "fl", "daggerdbl", "periodcentered", "quotesinglbase",
  "quotedblbase", "perthousand", "Acircumflex", "Ecircumflex", "Aacute", "Edieresis",
  "Egrave", "Iacute", "Icircumflex", "Idieresis", "Igrave", "Oacute", "Ocircumflex",
  "apple", "Ograve", "Uacute", "Ucircumflex", "Ugrave", "dotlessi", "circumflex",
  "tilde", "macron", "breve", "dotaccent", "ring", "cedilla", "hungarumlaut", "ogonek",
  "caron", "Lslash", "lslash", "Scaron", "scaron", "Zcaron", "zcaron", "brokenbar",
  "Eth", "eth", "Yacute", "yacute", "Thorn", "thorn", "minus", "multiply", "onesuperior",
  "twosuperior", "threesuperior", "onehalf", "onequarter", "threequarters", "franc",
  "Gbreve", "gbreve", "Idotaccent", "Scedilla", "scedilla", "Cacute", "cacute", "Ccaron",
  "ccaron", "dcroat",
]

///|
/// Returns the name of the specified glyph id if available.
pub fn Post::name(self : Post, glyph_id : UInt16) -> String? {
  if !self.has_names() {
    return None
  }
  let v = self.version()
  let gid = glyph_id.to_uint().reinterpret_as_int()
  if v == 0x00010000 {
    if gid < 0 || gid >= 258 {
      return None
    }
    return Some(default_glyph_names[gid])
  } else if v == 0x00020000 {
    let b = BeBytes::from_view(self.data)
    let count = b.read_u16(32).unwrap_or(0).reinterpret_as_int()
    if gid < 0 || gid >= count {
      return None
    }
    let mut index = match b.read_u16(34 + gid * 2) {
      None => return None
      Some(v) => v.reinterpret_as_int()
    }
    if index < 258 {
      return Some(default_glyph_names[index])
    }
    index = index - 258
    let mut base = 34 + count * 2
    for _ in 0..<index {
      let len = match b.read_u8(base) {
        None => return None
        Some(v) => v.to_int()
      }
      base = base + len + 1
    }
    let len = match b.read_u8(base) {
      None => return None
      Some(v) => v.to_int()
    }
    base = base + 1
    if !b.check_range(base, len) {
      return None
    }
    let bytes = b.data()[base:base + len]
    return post_ascii_string(bytes)
  }
  None
}
