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
/// Language tags (minimal subset of swash `text` module).
///
/// Ported from `swash/src/text/lang.rs` + `lang_data.rs`.

///|
/// Chinese, Japanese and Korean languages.
pub(all) enum Cjk {
  None
  Traditional
  Simplified
  Japanese
  Korean
}

///|
/// Representation of a language and its associated script and region.
pub struct Language {
  language : Array[Byte]
  script : Array[Byte]
  region : Array[Byte]
  lang_len : Int
  script_len : Int
  region_len : Int
  cjk : Cjk
  name_index : Int
  tag : Tag?
}

///|
fn text_lang_ascii_lower(u : Int) -> Byte? {
  if u < 0 || u > 255 {
    return None
  }
  let b = u.reinterpret_as_uint()
  let lo = if b >= 65 && b <= 90 { b + 32 } else { b }
  Some(lo.reinterpret_as_int().to_byte())
}

///|
fn text_lang_ascii_upper(u : Int) -> Byte? {
  if u < 0 || u > 255 {
    return None
  }
  let b = u.reinterpret_as_uint()
  let up = if b >= 97 && b <= 122 { b - 32 } else { b }
  Some(up.reinterpret_as_int().to_byte())
}

///|
fn text_lang_tag2(a : Byte, b : Byte) -> UInt {
  (a.to_int().reinterpret_as_uint() << 8) | b.to_int().reinterpret_as_uint()
}

///|
fn text_lang_tag3(a : Byte, b : Byte, c : Byte) -> UInt {
  (a.to_int().reinterpret_as_uint() << 16) |
  (b.to_int().reinterpret_as_uint() << 8) |
  c.to_int().reinterpret_as_uint()
}

///|
fn text_lang_find_dash(s : String, start : Int) -> Int {
  let n = s.length()
  let mut i = start
  while i < n {
    if s.code_unit_at(i) == '-' {
      return i
    }
    i = i + 1
  }
  n
}

///|
fn text_lang_lookup_tag(tag : Tag) -> Int? {
  let mut l = 0
  let mut h = text_lang_tags.length()
  while l < h {
    let mid = (l + h) / 2
    let k = text_lang_tags[mid]
    if k < tag {
      l = mid + 1
    } else if k > tag {
      h = mid
    } else {
      return Some(mid)
    }
  }
  None
}

///|
fn text_lang_lookup_by_tag2(key : UInt) -> Int? {
  let mut l = 0
  let mut h = text_lang_by_tag2.length()
  while l < h {
    let mid = (l + h) / 2
    let (k, v) = text_lang_by_tag2[mid]
    if k < key {
      l = mid + 1
    } else if k > key {
      h = mid
    } else {
      return Some(v)
    }
  }
  None
}

///|
fn text_lang_lookup_by_tag3(key : UInt) -> Int? {
  let mut l = 0
  let mut h = text_lang_by_tag3.length()
  while l < h {
    let mid = (l + h) / 2
    let (k, v) = text_lang_by_tag3[mid]
    if k < key {
      l = mid + 1
    } else if k > key {
      h = mid
    } else {
      return Some(v)
    }
  }
  None
}

///|
fn text_lang_bytes_prefix_to_string(bytes : Array[Byte], len : Int) -> String {
  let len = if len < 0 {
    0
  } else if len > bytes.length() {
    bytes.length()
  } else {
    len
  }
  let chars = Array::makei(len, i => bytes[i].to_int().unsafe_to_char())
  String::from_array(chars.op_as_view())
}

///|
/// Parses a language tag.
pub fn Language::parse(tag : String) -> Language? {
  let language = [b'\x00', b'\x00', b'\x00']
  let region = [b'\x00', b'\x00']
  let script = [b'\x00', b'\x00', b'\x00', b'\x00']
  let mut lang_len = 0
  let mut region_len = 0
  let mut script_len = 0
  let mut cjk = Cjk::None
  let mut name_index = -1
  let mut tag_opt : Tag? = None
  let n = tag.length()
  let p0_end = text_lang_find_dash(tag, 0)
  let p1_start = if p0_end < n { p0_end + 1 } else { n }
  let p1_end = if p1_start < n { text_lang_find_dash(tag, p1_start) } else { n }
  let p2_start = if p1_end < n { p1_end + 1 } else { n }
  let p2_end = if p2_start < n { text_lang_find_dash(tag, p2_start) } else { n }

  // Part 0: language (2 or 3).
  let mut has_region = false
  let mut zh = false
  let mut lang_index = -1
  let p0_len = p0_end
  if p0_len == 2 {
    let a_opt = text_lang_ascii_lower(tag.code_unit_at(0).to_int())
    let b_opt = text_lang_ascii_lower(tag.code_unit_at(1).to_int())
    let (a, b) = match (a_opt, b_opt) {
      (Some(a), Some(b)) => (a, b)
      _ => return None
    }
    if a == b'z' && b == b'h' {
      zh = true
    } else if a == b'j' && b == b'a' {
      cjk = Cjk::Japanese
    } else if a == b'k' && b == b'o' {
      cjk = Cjk::Korean
    }
    language[0] = a
    language[1] = b
    lang_len = 2
    let key = text_lang_tag2(a, b)
    match text_lang_lookup_by_tag2(key) {
      None => ()
      Some(ix) => lang_index = ix
    }
  } else if p0_len == 3 {
    let (a, b, c) = match
      (
        text_lang_ascii_lower(tag.code_unit_at(0).to_int()),
        text_lang_ascii_lower(tag.code_unit_at(1).to_int()),
        text_lang_ascii_lower(tag.code_unit_at(2).to_int()),
      ) {
      (Some(a), Some(b), Some(c)) => (a, b, c)
      _ => return None
    }
    zh = a == b'z' && b == b'h' && c == b'o'
    language[0] = a
    language[1] = b
    language[2] = c
    lang_len = 3
    let key = text_lang_tag3(a, b, c)
    match text_lang_lookup_by_tag3(key) {
      None => ()
      Some(ix) => lang_index = ix
    }
  } else {
    return None
  }

  // Part 1: region(2) or script(4).
  let p1_len = p1_end - p1_start
  if p1_start < n {
    if p1_len == 2 {
      let (a, b) = match
        (
          text_lang_ascii_upper(tag.code_unit_at(p1_start).to_int()),
          text_lang_ascii_upper(tag.code_unit_at(p1_start + 1).to_int()),
        ) {
        (Some(a), Some(b)) => (a, b)
        _ => return None
      }
      region[0] = a
      region[1] = b
      region_len = 2
      has_region = true
    } else if p1_len == 4 {
      let (a0, a1, a2, a3) = match
        (
          text_lang_ascii_upper(tag.code_unit_at(p1_start).to_int()),
          text_lang_ascii_lower(tag.code_unit_at(p1_start + 1).to_int()),
          text_lang_ascii_lower(tag.code_unit_at(p1_start + 2).to_int()),
          text_lang_ascii_lower(tag.code_unit_at(p1_start + 3).to_int()),
        ) {
        (Some(a0), Some(a1), Some(a2), Some(a3)) => (a0, a1, a2, a3)
        _ => return None
      }
      script[0] = a0
      script[1] = a1
      script[2] = a2
      script[3] = a3
      script_len = 4
    } else {
      // Ignore other subtags.
      ()
    }
  }

  // Part 2: region(2) if part 1 was script.
  let p2_len = p2_end - p2_start
  if p2_start < n && !has_region && p2_len == 2 {
    let (a, b) = match
      (
        text_lang_ascii_upper(tag.code_unit_at(p2_start).to_int()),
        text_lang_ascii_upper(tag.code_unit_at(p2_start + 1).to_int()),
      ) {
      (Some(a), Some(b)) => (a, b)
      _ => return None
    }
    region[0] = a
    region[1] = b
    region_len = 2
    has_region = true
  }

  // Resolve OpenType tag / name index.
  if lang_index >= 0 && lang_index < text_lang_tags.length() {
    name_index = lang_index
    tag_opt = Some(text_lang_tags[lang_index])
  } else if zh {
    let sc_opt = if script_len == 4 {
      Some(text_lang_bytes_prefix_to_string(script, 4))
    } else {
      None
    }
    let (tag, zh_cjk) = match sc_opt {
      Some(sc) =>
        if sc == "Hans" {
          (TEXT_LANG_ZHS_TAG, Cjk::Simplified)
        } else if sc == "Hant" {
          (TEXT_LANG_ZHT_TAG, Cjk::Traditional)
        } else {
          (TEXT_LANG_ZHT_TAG, Cjk::Traditional)
        }
      None => (TEXT_LANG_ZHT_TAG, Cjk::Traditional)
    }
    tag_opt = Some(tag)
    cjk = zh_cjk
    name_index = text_lang_lookup_tag(tag).unwrap_or(-1)
  }
  Some(Language::{
    language,
    script,
    region,
    lang_len,
    script_len,
    region_len,
    cjk,
    name_index,
    tag: tag_opt,
  })
}

///|
/// Returns the language associated with the specified OpenType language tag.
pub fn Language::from_opentype(tag : Tag) -> Language? {
  if tag == TEXT_LANG_ZHT_TAG {
    return Language::parse("zh-Hant")
  } else if tag == TEXT_LANG_ZHS_TAG {
    return Language::parse("zh-Hans")
  }
  let name_index = match text_lang_lookup_tag(tag) {
    None => return None
    Some(ix) => ix
  }
  let (_, bcp47) = text_lang_entries[name_index]
  Language::parse(bcp47)
}

///|
/// Returns the language component.
pub fn Language::language(self : Language) -> String {
  text_lang_bytes_prefix_to_string(self.language, self.lang_len)
}

///|
/// Returns the script component.
pub fn Language::script(self : Language) -> String? {
  if self.script_len == 4 {
    Some(text_lang_bytes_prefix_to_string(self.script, 4))
  } else {
    None
  }
}

///|
/// Returns the region component.
pub fn Language::region(self : Language) -> String? {
  if self.region_len == 2 {
    Some(text_lang_bytes_prefix_to_string(self.region, 2))
  } else {
    None
  }
}

///|
/// Returns the CJK language.
pub fn Language::cjk(self : Language) -> Cjk {
  self.cjk
}

///|
/// Returns the name of the language.
pub fn Language::name(self : Language) -> String? {
  if self.name_index < 0 || self.name_index >= text_lang_entries.length() {
    None
  } else {
    let (name, _) = text_lang_entries[self.name_index]
    Some(name)
  }
}

///|
/// Returns the associated OpenType language tag.
pub fn Language::to_opentype(self : Language) -> Tag? {
  self.tag
}

///|
pub fn Language::to_string(self : Language) -> String {
  let mut s = self.language()
  match self.script() {
    None => ()
    Some(sc) => s = s + "-" + sc
  }
  match self.region() {
    None => ()
    Some(rg) => s = s + "-" + rg
  }
  match self.name() {
    None => ()
    Some(nm) => s = s + " (" + nm + ")"
  }
  s
}

///|
pub impl Show for Language with output(self, logger) {
  logger.write_string(self.to_string())
}
