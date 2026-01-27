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
/// Setting combining a tag and a value for features and variations.
///
/// Ported from `swash/src/setting.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
pub struct Setting[T] {
  tag : Tag
  value : T
}

///|
pub fn[T] Setting::new(tag : Tag, value : T) -> Setting[T] {
  Setting::{ tag, value }
}

///|
/// Feature setting (`Setting<u16>` in swash).
pub type FeatureSetting = Setting[UInt16]

///|
/// Variation setting (`Setting<f32>` in swash; we use `Double`).
pub type VariationSetting = Setting[Double]

///|
fn is_ascii_whitespace(code : Int) -> Bool {
  code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D || code == 0x0C
}

// Parses a single quoted tag token: `"kern"` or `'kern'`.
// Returns (tag, next_pos) where next_pos points after the closing quote.

///|
fn parse_tag_token(s : String, pos0 : Int) -> (Tag, Int)? {
  let len = s.length()
  if pos0 >= len {
    return None
  }
  let quote_u16 = s.code_unit_at(pos0)
  let quote = quote_u16.to_int()
  if quote != 0x22 && quote != 0x27 { // '"' or '\''
    return None
  }
  let mut pos = pos0 + 1
  let mut n = 0
  let mut b0 : UInt = 0
  let mut b1 : UInt = 0
  let mut b2 : UInt = 0
  let mut b3 : UInt = 0
  while pos < len {
    let c = s.code_unit_at(pos).to_int()
    if c == quote {
      if n != 4 {
        return None
      }
      let tag = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
      return Some((tag, pos + 1))
    }
    if c < 0 || c > 0x7F {
      return None
    }
    let u = c.reinterpret_as_uint()
    if n == 0 {
      b0 = u
    } else if n == 1 {
      b1 = u
    } else if n == 2 {
      b2 = u
    } else if n == 3 {
      b3 = u
    } else {
      // Longer than 4 ASCII bytes.
      return None
    }
    n = n + 1
    pos = pos + 1
  }
  None
}

// Returns a trimmed (start,end) slice inside [start0,end0].

///|
fn trim_range(s : String, start0 : Int, end0 : Int) -> (Int, Int) {
  let mut start = start0
  let mut end = end0
  while start < end && is_ascii_whitespace(s.code_unit_at(start).to_int()) {
    start = start + 1
  }
  while end > start && is_ascii_whitespace(s.code_unit_at(end - 1).to_int()) {
    end = end - 1
  }
  (start, end)
}

///|
fn parse_list_tokens(source : String) -> Iter[(Tag, StringView)] {
  let len = source.length()
  let mut pos = 0
  let mut stopped = false
  Iter::new(fn() {
    if stopped {
      return None
    }
    // Skip leading whitespace and commas.
    while pos < len {
      let c = source.code_unit_at(pos).to_int()
      if !is_ascii_whitespace(c) && c != 0x2C { // ','
        break
      }
      pos = pos + 1
    }
    if pos >= len {
      stopped = true
      return None
    }
    match parse_tag_token(source, pos) {
      None => {
        stopped = true
        None
      }
      Some((tag, after_tag)) => {
        pos = after_tag
        // Skip whitespace before the value.
        while pos < len &&
              is_ascii_whitespace(source.code_unit_at(pos).to_int()) {
          pos = pos + 1
        }
        let start0 = pos
        // Read until comma or end.
        while pos < len && source.code_unit_at(pos).to_int() != 0x2C {
          pos = pos + 1
        }
        let end0 = pos
        // Consume trailing comma if present.
        if pos < len && source.code_unit_at(pos).to_int() == 0x2C {
          pos = pos + 1
        }
        let (start, end) = trim_range(source, start0, end0)
        // Always safe: start/end are derived from bounds checks above.
        let value = try! source[start:end]
        Some((tag, value))
      }
    }
  })
}

///|
pub fn Setting::parse_feature(s : String) -> FeatureSetting? {
  Setting::parse_feature_list(s).next()
}

///|
pub fn Setting::parse_feature_list(s : String) -> Iter[FeatureSetting] {
  let tokens = parse_list_tokens(s)
  Iter::new(fn() {
    match tokens.next() {
      None => None
      Some((tag, value_sv)) => {
        let value_s = value_sv.to_string()
        let (ok, value) = match value_s {
          "" | "on" => (true, 1)
          "off" => (true, 0)
          _ =>
            try @strconv.parse_int(value_sv, base=10) catch {
              _ => (false, 0)
            } noraise {
              v => if v < 0 || v > 0xFFFF { (false, 0) } else { (true, v) }
            }
        }
        if ok {
          Some(Setting::new(tag, value.to_uint16()))
        } else {
          None
        }
      }
    }
  })
}

///|
pub fn Setting::parse_variation(s : String) -> VariationSetting? {
  Setting::parse_variation_list(s).next()
}

///|
pub fn Setting::parse_variation_list(s : String) -> Iter[VariationSetting] {
  let tokens = parse_list_tokens(s)
  Iter::new(fn() {
    match tokens.next() {
      None => None
      Some((tag, value_sv)) =>
        try @strconv.parse_double(value_sv) catch {
          _ => None
        } noraise {
          v => Some(Setting::new(tag, v))
        }
    }
  })
}

///|
test "Setting[u16]::parse supports on/off/numeric" {
  let s0 = Setting::parse_feature("\"kern\" on").unwrap()
  inspect(s0.tag == tag_from_str_lossy("kern"), content="true")
  inspect(s0.value.to_int(), content="1")
  let s1 = Setting::parse_feature("\"kern\" off").unwrap()
  inspect(s1.value.to_int(), content="0")
  let s2 = Setting::parse_feature("\"kern\" 2").unwrap()
  inspect(s2.value.to_int(), content="2")
}

///|
test "Setting[Double]::parse supports decimals and exponents" {
  let s0 = Setting::parse_variation("\"wght\" 700").unwrap()
  inspect(s0.tag == tag_from_str_lossy("wght"), content="true")
  inspect(s0.value.to_int(), content="700")
  let s1 = Setting::parse_variation("\"slnt\" -1.25e1").unwrap()
  inspect(s1.value.to_int(), content="-12")
}
