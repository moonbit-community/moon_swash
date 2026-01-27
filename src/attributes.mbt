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
/// Basic font attributes: stretch, weight and style.
///
/// Ported from `swash/src/attributes.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
/// Variations that apply to attributes.
const WDTH : Tag = 0x77647468 // "wdth"

///|
const WGHT : Tag = 0x77676874 // "wght"

///|
const SLNT : Tag = 0x736C6E74 // "slnt"

///|
const ITAL : Tag = 0x6974616C // "ital"

///|
/// Primary attributes for font classification: stretch, weight and style.
///
/// This struct is created by the `attributes()` method on `FontRef`.
pub struct Attributes {
  value : UInt
}

///|
pub fn Attributes::new(
  stretch : Stretch,
  weight : Weight,
  style : Style,
) -> Attributes {
  let stretch_u = stretch.value.to_int().reinterpret_as_uint() & 0x1FF
  let weight_u = weight.value.to_int().reinterpret_as_uint() & 0x3FF
  let style_u = style.pack()
  Attributes::{ value: style_u | (weight_u << 9) | (stretch_u << 19) }
}

///|
/// Extracts the attributes from the specified font.
pub fn Attributes::from_font(font : FontRef) -> Attributes {
  let attrs = Attributes::from_os2(font.os2())
  let mut var_bits : UInt = 0
  for v in font.variations() {
    match v.tag() {
      WDTH => var_bits = var_bits | 1
      WGHT => var_bits = var_bits | 2
      SLNT => var_bits = var_bits | 4
      ITAL => var_bits = var_bits | 8
      _ => ()
    }
  }
  Attributes::{ value: attrs.value | (var_bits << 28) }
}

///|
fn Attributes::from_os2(os2 : @internal.Os2?) -> Attributes {
  match os2 {
    None => Attributes::default()
    Some(os2) => {
      let flags = os2.selection_flags()
      let style = if flags.italic() {
        Style::Italic
      } else if flags.oblique() {
        Style::Oblique(ObliqueAngle::default())
      } else {
        Style::Normal
      }
      let weight = Weight::{ value: os2.weight_class().to_uint16() }
      let stretch = Stretch::from_raw(os2.width_class().to_uint16())
      Attributes::new(stretch, weight, style)
    }
  }
}

///|
pub fn Attributes::stretch(self : Attributes) -> Stretch {
  Stretch::{ value: ((self.value >> 19) & 0x1FF).to_uint16() }
}

///|
pub fn Attributes::weight(self : Attributes) -> Weight {
  Weight::{ value: ((self.value >> 9) & 0x3FF).to_uint16() }
}

///|
pub fn Attributes::style(self : Attributes) -> Style {
  Style::unpack(self.value & 0x1FF)
}

///|
pub fn Attributes::parts(self : Attributes) -> (Stretch, Weight, Style) {
  (self.stretch(), self.weight(), self.style())
}

///|
pub fn Attributes::has_variations(self : Attributes) -> Bool {
  self.value >> 28 != 0
}

///|
pub fn Attributes::has_stretch_variation(self : Attributes) -> Bool {
  let var_bits = self.value >> 28
  (var_bits & 1) != 0
}

///|
pub fn Attributes::has_weight_variation(self : Attributes) -> Bool {
  let var_bits = self.value >> 28
  (var_bits & 2) != 0
}

///|
pub fn Attributes::has_oblique_variation(self : Attributes) -> Bool {
  let var_bits = self.value >> 28
  (var_bits & 4) != 0
}

///|
pub fn Attributes::has_italic_variation(self : Attributes) -> Bool {
  let var_bits = self.value >> 28
  (var_bits & 8) != 0
}

///|
/// Returns a synthesis analysis based on the requested attributes with
/// respect to this set of attributes.
pub fn Attributes::synthesize(
  self : Attributes,
  requested : Attributes,
) -> Synthesis {
  if self.value << 4 == requested.value << 4 {
    return Synthesis::default()
  }
  let vars : Array[VariationSetting] = []
  if self.has_stretch_variation() {
    let stretch = self.stretch()
    let req_stretch = requested.stretch()
    if stretch != req_stretch {
      vars.push(Setting::new(WDTH, req_stretch.to_percentage()))
    }
  }
  let weight = self.weight()
  let req_weight = requested.weight()
  let mut embolden = false
  if weight != req_weight {
    if self.has_weight_variation() {
      if vars.length() < 4 {
        vars.push(Setting::new(WGHT, req_weight.value.to_int().to_double()))
      }
    } else if req_weight > weight {
      embolden = true
    }
  }
  let style = self.style()
  let req_style = requested.style()
  let mut skew : Int = 0
  if style != req_style {
    match req_style {
      Style::Normal => ()
      Style::Italic =>
        if style == Style::Normal {
          if self.has_italic_variation() {
            if vars.length() < 4 {
              vars.push(Setting::new(ITAL, 1.0))
            }
          } else if self.has_oblique_variation() {
            if vars.length() < 4 {
              vars.push(Setting::new(SLNT, 14.0))
            }
          } else {
            skew = 14
          }
        }
      Style::Oblique(angle) =>
        if style == Style::Normal {
          let degrees = angle.to_degrees()
          if self.has_oblique_variation() {
            if vars.length() < 4 {
              vars.push(Setting::new(SLNT, degrees))
            }
          } else if self.has_italic_variation() && degrees > 0.0 {
            if vars.length() < 4 {
              vars.push(Setting::new(ITAL, 1.0))
            }
          } else {
            skew = degrees.to_int()
          }
        }
    }
  }
  Synthesis::{ vars, embolden, skew }
}

///|
fn Attributes::default() -> Attributes {
  Attributes::new(Stretch::normal(), Weight::normal(), Style::Normal)
}

///|
pub impl Eq for Attributes with equal(self, other) {
  self.value << 4 == other.value << 4
}

///|
pub impl Show for Attributes with output(self, logger) {
  let (stretch, weight, style) = self.parts()
  if style == Style::Normal &&
    weight == Weight::normal() &&
    stretch == Stretch::normal() {
    logger.write_string("regular")
    return
  }
  let mut space = ""
  if stretch != Stretch::normal() {
    logger.write_string(stretch.to_string())
    space = " "
  }
  if style != Style::Normal {
    logger.write_string(space)
    logger.write_string(style.to_string())
    space = " "
  }
  if weight != Weight::normal() {
    logger.write_string(space)
    logger.write_string(weight.to_string())
  }
}

///|
/// Angle of an oblique style in degrees from -90 to 90.
pub struct ObliqueAngle {
  value : UInt16
}

///|
fn clamp_double(x : Double, lo : Double, hi : Double) -> Double {
  if x < lo {
    lo
  } else if x > hi {
    hi
  } else {
    x
  }
}

///|
fn slice_or_none(s : StringView, start : Int, end : Int) -> StringView? {
  try s[start:end] catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
fn slice_from_or_none(s : StringView, start : Int) -> StringView? {
  try s[start:] catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
pub fn ObliqueAngle::from_degrees(degrees : Double) -> ObliqueAngle {
  let clamped = clamp_double(degrees, -90.0, 90.0) + 90.0
  ObliqueAngle::{ value: clamped.to_int().to_uint16() }
}

///|
pub fn ObliqueAngle::from_radians(radians : Double) -> ObliqueAngle {
  ObliqueAngle::from_degrees(radians * 180.0 / 3.141592653589793)
}

///|
pub fn ObliqueAngle::from_gradians(gradians : Double) -> ObliqueAngle {
  ObliqueAngle::from_degrees(gradians / 400.0 * 360.0)
}

///|
pub fn ObliqueAngle::from_turns(turns : Double) -> ObliqueAngle {
  ObliqueAngle::from_degrees(turns * 360.0)
}

///|
pub fn ObliqueAngle::to_degrees(self : ObliqueAngle) -> Double {
  self.value.to_int().to_double() - 90.0
}

///|
fn ObliqueAngle::default() -> ObliqueAngle {
  ObliqueAngle::from_degrees(14.0)
}

///|
/// Visual style or 'slope' of a font.
pub(all) enum Style {
  Normal
  Italic
  Oblique(ObliqueAngle)
}

///|
pub impl Eq for Style with equal(self, other) {
  match (self, other) {
    (Style::Normal, Style::Normal) => true
    (Style::Italic, Style::Italic) => true
    (Style::Oblique(a), Style::Oblique(b)) => a.value == b.value
    _ => false
  }
}

///|
pub fn Style::parse(s0 : String) -> Style? {
  let s = s0.trim()
  if s == "normal" {
    Some(Style::Normal)
  } else if s == "italic" {
    Some(Style::Italic)
  } else if s == "oblique" {
    Some(Style::Oblique(ObliqueAngle::from_degrees(14.0)))
  } else if s.has_prefix("oblique ") {
    let rest = match slice_from_or_none(s, 8) {
      None => return Some(Style::Oblique(ObliqueAngle::default()))
      Some(v) => v
    }
    if rest.has_suffix("deg") {
      let a_sv = match slice_or_none(rest, 0, rest.length() - 3) {
        None => return Some(Style::Oblique(ObliqueAngle::default()))
        Some(v) => v
      }
      try @strconv.parse_double(a_sv.trim()) catch {
        _ => Some(Style::Oblique(ObliqueAngle::default()))
      } noraise {
        a => Some(Style::Oblique(ObliqueAngle::from_degrees(a)))
      }
    } else if rest.has_suffix("grad") {
      let a_sv = match slice_or_none(rest, 0, rest.length() - 4) {
        None => return Some(Style::Oblique(ObliqueAngle::default()))
        Some(v) => v
      }
      try @strconv.parse_double(a_sv.trim()) catch {
        _ => Some(Style::Oblique(ObliqueAngle::default()))
      } noraise {
        a => Some(Style::Oblique(ObliqueAngle::from_gradians(a)))
      }
    } else if rest.has_suffix("rad") {
      let a_sv = match slice_or_none(rest, 0, rest.length() - 3) {
        None => return Some(Style::Oblique(ObliqueAngle::default()))
        Some(v) => v
      }
      try @strconv.parse_double(a_sv.trim()) catch {
        _ => Some(Style::Oblique(ObliqueAngle::default()))
      } noraise {
        a => Some(Style::Oblique(ObliqueAngle::from_radians(a)))
      }
    } else if rest.has_suffix("turn") {
      let a_sv = match slice_or_none(rest, 0, rest.length() - 4) {
        None => return Some(Style::Oblique(ObliqueAngle::default()))
        Some(v) => v
      }
      try @strconv.parse_double(a_sv.trim()) catch {
        _ => Some(Style::Oblique(ObliqueAngle::default()))
      } noraise {
        a => Some(Style::Oblique(ObliqueAngle::from_turns(a)))
      }
    } else {
      Some(Style::Oblique(ObliqueAngle::default()))
    }
  } else {
    None
  }
}

///|
pub fn Style::from_degrees(degrees : Double) -> Style {
  Style::Oblique(ObliqueAngle::from_degrees(degrees))
}

///|
pub fn Style::to_degrees(self : Style) -> Double {
  match self {
    Style::Italic => 14.0
    Style::Oblique(a) => a.to_degrees()
    _ => 0.0
  }
}

///|
fn Style::unpack(bits : UInt) -> Style {
  if (bits & 1) != 0 {
    Style::Oblique(ObliqueAngle::{ value: (bits >> 1).to_uint16() })
  } else if bits == 0b110 {
    Style::Italic
  } else {
    Style::Normal
  }
}

///|
fn Style::pack(self : Style) -> UInt {
  match self {
    Style::Normal => 0b10
    Style::Italic => 0b110
    Style::Oblique(a) => 1 | (a.value.to_int().reinterpret_as_uint() << 1)
  }
}

///|
pub fn Style::to_string(self : Style) -> String {
  match self {
    Style::Normal => "normal"
    Style::Italic => "italic"
    Style::Oblique(a) => {
      let degrees = a.to_degrees()
      if degrees == 14.0 {
        "oblique"
      } else {
        "oblique(" + degrees.to_string() + "deg)"
      }
    }
  }
}

///|
pub impl Show for Style with output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Visual weight class of a font on a scale from 1 to 1000.
pub struct Weight {
  value : UInt16
}

///|
pub fn Weight::thin() -> Weight {
  Weight::{ value: (100).to_uint16() }
}

///|
pub fn Weight::extra_light() -> Weight {
  Weight::{ value: (200).to_uint16() }
}

///|
pub fn Weight::light() -> Weight {
  Weight::{ value: (300).to_uint16() }
}

///|
pub fn Weight::normal() -> Weight {
  Weight::{ value: (400).to_uint16() }
}

///|
pub fn Weight::medium() -> Weight {
  Weight::{ value: (500).to_uint16() }
}

///|
pub fn Weight::semi_bold() -> Weight {
  Weight::{ value: (600).to_uint16() }
}

///|
pub fn Weight::bold() -> Weight {
  Weight::{ value: (700).to_uint16() }
}

///|
pub fn Weight::extra_bold() -> Weight {
  Weight::{ value: (800).to_uint16() }
}

///|
pub fn Weight::black() -> Weight {
  Weight::{ value: (900).to_uint16() }
}

///|
pub fn Weight::parse(s0 : String) -> Weight? {
  let s = s0.trim()
  if s == "normal" {
    Some(Weight::normal())
  } else if s == "bold" {
    Some(Weight::bold())
  } else {
    try @strconv.parse_int(s, base=10) catch {
      _ => None
    } noraise {
      v => Some(Weight::{ value: v.max(1).min(1000).to_uint16() })
    }
  }
}

///|
pub fn Weight::to_string(self : Weight) -> String {
  if self == Weight::thin() {
    "thin"
  } else if self == Weight::extra_light() {
    "extra-light"
  } else if self == Weight::light() {
    "light"
  } else if self == Weight::normal() {
    "normal"
  } else if self == Weight::medium() {
    "medium"
  } else if self == Weight::semi_bold() {
    "semi-bold"
  } else if self == Weight::bold() {
    "bold"
  } else if self == Weight::extra_bold() {
    "extra-bold"
  } else if self == Weight::black() {
    "black"
  } else {
    self.value.to_string()
  }
}

///|
pub impl Show for Weight with output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for Weight with equal(self, other) {
  self.value == other.value
}

///|
pub impl Compare for Weight with compare(self, other) {
  self.value.to_int() - other.value.to_int()
}

///|

///|
/// Visual width of a font-- a relative change from the normal aspect ratio.
pub struct Stretch {
  value : UInt16
}

///|
pub fn Stretch::ultra_condensed() -> Stretch {
  Stretch::{ value: (0).to_uint16() }
}

///|
pub fn Stretch::extra_condensed() -> Stretch {
  Stretch::{ value: (25).to_uint16() }
}

///|
pub fn Stretch::condensed() -> Stretch {
  Stretch::{ value: (50).to_uint16() }
}

///|
pub fn Stretch::semi_condensed() -> Stretch {
  Stretch::{ value: (75).to_uint16() }
}

///|
pub fn Stretch::normal() -> Stretch {
  Stretch::{ value: (100).to_uint16() }
}

///|
pub fn Stretch::semi_expanded() -> Stretch {
  Stretch::{ value: (125).to_uint16() }
}

///|
pub fn Stretch::expanded() -> Stretch {
  Stretch::{ value: (150).to_uint16() }
}

///|
pub fn Stretch::extra_expanded() -> Stretch {
  Stretch::{ value: (200).to_uint16() }
}

///|
pub fn Stretch::ultra_expanded() -> Stretch {
  Stretch::{ value: (300).to_uint16() }
}

///|
pub fn Stretch::from_percentage(percentage : Double) -> Stretch {
  let p = clamp_double(percentage, 50.0, 200.0)
  let value = ((p - 50.0) * 2.0).to_int().to_uint16()
  Stretch::{ value, }
}

///|
pub fn Stretch::to_percentage(self : Stretch) -> Double {
  self.value.to_int().to_double() * 0.5 + 50.0
}

///|
pub fn Stretch::is_normal(self : Stretch) -> Bool {
  self == Stretch::normal()
}

///|
pub fn Stretch::is_condensed(self : Stretch) -> Bool {
  self < Stretch::normal()
}

///|
pub fn Stretch::is_expanded(self : Stretch) -> Bool {
  self > Stretch::normal()
}

///|
pub fn Stretch::parse(s0 : String) -> Stretch? {
  let s = s0.trim()
  if s == "ultra-condensed" {
    Some(Stretch::ultra_condensed())
  } else if s == "extra-condensed" {
    Some(Stretch::extra_condensed())
  } else if s == "condensed" {
    Some(Stretch::condensed())
  } else if s == "semi-condensed" {
    Some(Stretch::semi_condensed())
  } else if s == "normal" {
    Some(Stretch::normal())
  } else if s == "semi-expanded" {
    Some(Stretch::semi_expanded())
  } else if s == "expanded" {
    Some(Stretch::expanded())
  } else if s == "extra-expanded" {
    Some(Stretch::extra_expanded())
  } else if s == "ultra-expanded" {
    Some(Stretch::ultra_expanded())
  } else if s.has_suffix("%") {
    let p_sv = match slice_or_none(s, 0, s.length() - 1) {
      None => return None
      Some(v) => v
    }
    try @strconv.parse_double(p_sv.trim()) catch {
      _ => None
    } noraise {
      p => Some(Stretch::from_percentage(p))
    }
  } else {
    None
  }
}

///|
pub fn Stretch::raw(self : Stretch) -> UInt16 {
  self.value
}

///|
fn Stretch::from_raw(raw : UInt16) -> Stretch {
  match raw {
    1 => Stretch::ultra_condensed()
    2 => Stretch::extra_condensed()
    3 => Stretch::condensed()
    4 => Stretch::semi_condensed()
    5 => Stretch::normal()
    6 => Stretch::semi_expanded()
    7 => Stretch::expanded()
    8 => Stretch::extra_expanded()
    9 => Stretch::ultra_expanded()
    _ => Stretch::normal()
  }
}

///|
pub fn Stretch::to_string(self : Stretch) -> String {
  if self == Stretch::ultra_condensed() {
    "ultra-condensed"
  } else if self == Stretch::extra_condensed() {
    "extra-condensed"
  } else if self == Stretch::condensed() {
    "condensed"
  } else if self == Stretch::semi_condensed() {
    "semi-condensed"
  } else if self == Stretch::normal() {
    "normal"
  } else if self == Stretch::semi_expanded() {
    "semi-expanded"
  } else if self == Stretch::expanded() {
    "expanded"
  } else if self == Stretch::extra_expanded() {
    "extra-expanded"
  } else if self == Stretch::ultra_expanded() {
    "ultra-expanded"
  } else {
    self.to_percentage().to_string() + "%"
  }
}

///|
pub impl Show for Stretch with output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for Stretch with equal(self, other) {
  self.value == other.value
}

///|
pub impl Compare for Stretch with compare(self, other) {
  self.value.to_int() - other.value.to_int()
}

///|

///|
/// Synthesis suggestions for mismatched font attributes.
///
/// This is generated by `Attributes::synthesize`.
pub struct Synthesis {
  vars : Array[VariationSetting]
  embolden : Bool
  skew : Int
}

///|
fn Synthesis::default() -> Synthesis {
  Synthesis::{ vars: [], embolden: false, skew: 0 }
}

///|
pub fn Synthesis::any(self : Synthesis) -> Bool {
  self.vars.length() != 0 || self.embolden || self.skew != 0
}

///|
pub fn Synthesis::variations(self : Synthesis) -> ArrayView[VariationSetting] {
  self.vars.op_as_view()
}

///|
pub fn Synthesis::embolden(self : Synthesis) -> Bool {
  self.embolden
}

///|
pub fn Synthesis::skew(self : Synthesis) -> Double? {
  if self.skew != 0 {
    Some(self.skew.to_double())
  } else {
    None
  }
}

///|
pub impl Eq for Synthesis with equal(self, other) {
  if self.embolden != other.embolden || self.skew != other.skew {
    return false
  }
  if self.vars.length() != other.vars.length() {
    return false
  }
  for i in 0..<self.vars.length() {
    let a = self.vars[i]
    let b = other.vars[i]
    if a.tag != b.tag || a.value != b.value {
      return false
    }
  }
  true
}

///|
pub fn FontRef::attributes(self : FontRef) -> Attributes {
  Attributes::from_font(self)
}
