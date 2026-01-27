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
/// Localized names and other metadata.
///
/// Ported from `swash/src/string.rs` (swash is dual-licensed Apache-2.0 OR MIT).
const NAME : UInt = 0x6E616D65 // "name"

///|
/// Identifier for well-known localized strings in a font.
pub(all) enum StringId {
  Copyright
  Family
  SubFamily
  UniqueId
  Full
  Version
  PostScript
  Trademark
  Manufacturer
  Designer
  Description
  VendorUrl
  DesignerUrl
  License
  LicenseUrl
  TypographicFamily
  TypographicSubFamily
  CompatibleFull
  SampleText
  PostScriptCid
  WwsFamily
  WwsSubFamily
  LightBackgroundPalette
  DarkBackgroundPalette
  VariationsPostScriptNamePrefix
  Other(UInt16)
}

///|
pub fn StringId::from_raw(value : UInt16) -> StringId {
  match value.to_int() {
    0 => StringId::Copyright
    1 => StringId::Family
    2 => StringId::SubFamily
    3 => StringId::UniqueId
    4 => StringId::Full
    5 => StringId::Version
    6 => StringId::PostScript
    7 => StringId::Trademark
    8 => StringId::Manufacturer
    9 => StringId::Designer
    10 => StringId::Description
    11 => StringId::VendorUrl
    12 => StringId::DesignerUrl
    13 => StringId::License
    14 => StringId::LicenseUrl
    16 => StringId::TypographicFamily
    17 => StringId::TypographicSubFamily
    18 => StringId::CompatibleFull
    19 => StringId::SampleText
    20 => StringId::PostScriptCid
    21 => StringId::WwsFamily
    22 => StringId::WwsSubFamily
    23 => StringId::LightBackgroundPalette
    24 => StringId::DarkBackgroundPalette
    25 => StringId::VariationsPostScriptNamePrefix
    _ => StringId::Other(value)
  }
}

///|
pub fn StringId::to_raw(self : StringId) -> UInt16 {
  match self {
    Other(id) => id
    Copyright => 0
    Family => 1
    SubFamily => 2
    UniqueId => 3
    Full => 4
    Version => 5
    PostScript => 6
    Trademark => 7
    Manufacturer => 8
    Designer => 9
    Description => 10
    VendorUrl => 11
    DesignerUrl => 12
    License => 13
    LicenseUrl => 14
    TypographicFamily => 16
    TypographicSubFamily => 17
    CompatibleFull => 18
    SampleText => 19
    PostScriptCid => 20
    WwsFamily => 21
    WwsSubFamily => 22
    LightBackgroundPalette => 23
    DarkBackgroundPalette => 24
    VariationsPostScriptNamePrefix => 25
  }
}

///|
/// Encoding of a localized string.
///
/// Fonts can contain a variety of platform specific and legacy encodings.
/// Only the ones we decode are listed here.
pub(all) enum Encoding {
  Unicode
  MacRoman
  Other(UInt16, UInt16)
}

///|
fn Encoding::from_raw_parts(
  platform_id : UInt16,
  encoding_id : UInt16,
) -> Encoding {
  match (platform_id.to_int(), encoding_id.to_int()) {
    (0, _) => Encoding::Unicode
    (1, 0) => Encoding::MacRoman
    (3, 0) => Encoding::Unicode
    (3, 1) => Encoding::Unicode
    (3, 10) => Encoding::Unicode
    _ => Encoding::Other(platform_id, encoding_id)
  }
}

///|
pub fn Encoding::is_decodable(self : Encoding) -> Bool {
  match self {
    Other(_, _) => false
    _ => true
  }
}

///|
/// Iterator over a collection of localized strings.
pub struct LocalizedStrings {
  b : @internal.BeBytes
  len : Int
  storage : Int
}

///|
fn empty_view() -> BytesView {
  Bytes::from_array([])[:]
}

///|
fn LocalizedStrings::new(data : BytesView) -> LocalizedStrings {
  let b = @internal.BeBytes::from_view(data)
  let len = b.read_u16(2).unwrap_or(0).reinterpret_as_int()
  let storage = b.read_u16(4).unwrap_or(0).reinterpret_as_int()
  LocalizedStrings::{ b, len, storage }
}

///|
pub fn FontRef::localized_strings(self : FontRef) -> LocalizedStrings {
  match self.table_data(NAME) {
    None => LocalizedStrings::new(empty_view())
    Some(v) => LocalizedStrings::new(v)
  }
}

///|
pub fn LocalizedStrings::len(self : LocalizedStrings) -> Int {
  self.len
}

///|
fn LocalizedStrings::get(
  self : LocalizedStrings,
  index : Int,
) -> LocalizedString? {
  if index < 0 || index >= self.len {
    return None
  }
  let off = 6 + index * 12
  if !self.b.ensure_range(off, 12) {
    return None
  }
  Some(LocalizedString::{ b: self.b, storage: self.storage, offset: off })
}

///|
pub fn LocalizedStrings::iter(self : LocalizedStrings) -> Iter[LocalizedString] {
  let mut pos = 0
  let len = self.len
  Iter::new(fn() {
    if pos >= len {
      return None
    }
    let i = pos
    pos = pos + 1
    self.get(i)
  })
}

///|
/// Searches for a string with the specified identifier, and if specified,
/// language.
///
/// This function searches the entire string collection without regard
/// for the current state of the iterator.
pub fn LocalizedStrings::find_by_id(
  self : LocalizedStrings,
  id : StringId,
  language : String?,
) -> LocalizedString? {
  let mut first : LocalizedString? = None
  let mut best : LocalizedString? = None
  let raw_id = id.to_raw()
  for i in 0..<self.len() {
    let rec = match self.get(i) {
      None => continue
      Some(r) => r
    }
    if rec.raw_id() != raw_id {
      continue
    }
    if first is None {
      first = Some(rec)
    }
    let encoding = rec.encoding()
    match language {
      Some(lang) =>
        if rec.language().has_prefix(lang[:]) {
          match encoding {
            Unicode => return Some(rec)
            _ => if encoding.is_decodable() { best = Some(rec) }
          }
        }
      None =>
        if rec.language() == "" {
          match encoding {
            Unicode => return Some(rec)
            _ => if encoding.is_decodable() { best = Some(rec) }
          }
        }
    }
  }
  match best {
    Some(v) => Some(v)
    None => if language is None { first } else { None }
  }
}

///|
/// Represents a single localized string in a font.
pub struct LocalizedString {
  b : @internal.BeBytes
  storage : Int
  offset : Int
}

///|
pub fn LocalizedString::id(self : LocalizedString) -> StringId {
  StringId::from_raw(self.raw_id())
}

///|
pub fn LocalizedString::language(self : LocalizedString) -> String {
  get_language(self.platform_id(), self.language_id())
}

///|
pub fn LocalizedString::is_unicode(self : LocalizedString) -> Bool {
  match self.encoding() {
    Unicode => true
    _ => false
  }
}

///|
pub fn LocalizedString::is_decodable(self : LocalizedString) -> Bool {
  self.encoding().is_decodable()
}

///|
pub fn LocalizedString::chars(self : LocalizedString) -> Iter[Char] {
  let encoding = self.encoding()
  if !encoding.is_decodable() {
    return Iter::new(fn() { None })
  }
  let len_bytes = self.b
    .read_u16(self.offset + 8)
    .unwrap_or(0)
    .reinterpret_as_int()
  let base = self.b.read_u16(self.offset + 10).unwrap_or(0).reinterpret_as_int() +
    self.storage
  let rep : Char = (0xFFFD : Int).unsafe_to_char()
  match encoding {
    Unicode => {
      let mut cur = 0
      Iter::new(fn() {
        if cur >= len_bytes {
          return None
        }
        let u0 = match self.b.read_u16(base + cur) {
          None => return None
          Some(v) => v.reinterpret_as_int()
        }
        cur = cur + 2
        let mut cp = u0
        if cp >= 0xD800 && cp < 0xDC00 {
          let u1 = match self.b.read_u16(base + cur) {
            None => return Some(rep)
            Some(v) => v.reinterpret_as_int()
          }
          cur = cur + 2
          cp = ((cp & 0x3FF) << 10) + (u1 & 0x3FF) + 0x10000
        }
        match cp.to_char() {
          None => Some(rep)
          Some(c) => Some(c)
        }
      })
    }
    MacRoman => {
      let bytes = match self.bytes() {
        None => return Iter::new(fn() { None })
        Some(v) => v
      }
      let mut cur = 0
      Iter::new(fn() {
        if cur >= len_bytes {
          return None
        }
        let b = match bytes.get(cur) {
          None => return None
          Some(v) => v.to_int()
        }
        cur = cur + 1
        if b > 127 {
          let idx = b - 128
          let cp = mac_roman[idx]
          match cp.to_char() {
            None => Some(rep)
            Some(c) => Some(c)
          }
        } else {
          match b.to_char() {
            None => Some(rep)
            Some(c) => Some(c)
          }
        }
      })
    }
    Other(_, _) => Iter::new(fn() { None })
  }
}

///|
pub fn LocalizedString::to_string(self : LocalizedString) -> String {
  String::from_array(self.chars().to_array().op_as_view())
}

///|
fn LocalizedString::raw_id(self : LocalizedString) -> UInt16 {
  self.b.read_u16(self.offset + 6).unwrap_or(0xFFFF).to_uint16()
}

///|
fn LocalizedString::platform_id(self : LocalizedString) -> UInt16 {
  self.b.read_u16(self.offset).unwrap_or(0).to_uint16()
}

///|
fn LocalizedString::encoding_id(self : LocalizedString) -> UInt16 {
  self.b.read_u16(self.offset + 2).unwrap_or(0).to_uint16()
}

///|
fn LocalizedString::language_id(self : LocalizedString) -> UInt16 {
  self.b.read_u16(self.offset + 4).unwrap_or(0).to_uint16()
}

///|
fn LocalizedString::encoding(self : LocalizedString) -> Encoding {
  Encoding::from_raw_parts(self.platform_id(), self.encoding_id())
}

///|
fn LocalizedString::bytes(self : LocalizedString) -> BytesView? {
  let len = match self.b.read_u16(self.offset + 8) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let offset = match self.b.read_u16(self.offset + 10) {
    None => return None
    Some(v) => v.reinterpret_as_int()
  }
  let start = offset + self.storage
  let data = self.b.data()
  if start < 0 ||
    len < 0 ||
    start > data.length() ||
    data.length() - start < len {
    return None
  }
  Some(data[start:start + len])
}

///|
let mac_roman : ReadOnlyArray[Int] = [
  196, 197, 199, 201, 209, 214, 220, 225, 224, 226, 228, 227, 229, 231, 233, 232,
  234, 235, 237, 236, 238, 239, 241, 243, 242, 244, 246, 245, 250, 249, 251, 252,
  8224, 176, 162, 163, 167, 8226, 182, 223, 174, 169, 8482, 180, 168, 8800, 198,
  216, 8734, 177, 8804, 8805, 165, 181, 8706, 8721, 8719, 960, 8747, 170, 186, 937,
  230, 248, 191, 161, 172, 8730, 402, 8776, 8710, 171, 187, 8230, 160, 192, 195,
  213, 338, 339, 8211, 8212, 8220, 8221, 8216, 8217, 247, 9674, 255, 376, 8260, 8364,
  8249, 8250, 64257, 64258, 8225, 183, 8218, 8222, 8240, 194, 202, 193, 203, 200,
  205, 206, 207, 204, 211, 212, 63743, 210, 218, 219, 217, 305, 710, 732, 175, 728,
  729, 730, 184, 733, 731, 711,
]

///|
let languages : ReadOnlyArray[(UInt, String)] = [
  (0x10000, "en"),
  (0x10001, "fr"),
  (0x10002, "de"),
  (0x10003, "it"),
  (0x10004, "nl"),
  (0x10005, "sv"),
  (0x10006, "es"),
  (0x10007, "da"),
  (0x10008, "pt"),
  (0x10009, "no"),
  (0x1000A, "he"),
  (0x1000B, "ja"),
  (0x1000C, "ar"),
  (0x1000D, "fi"),
  (0x1000E, "el"),
  (0x1000F, "is"),
  (0x10010, "mt"),
  (0x10011, "tr"),
  (0x10012, "hr"),
  (0x10013, "zh-tw"),
  (0x10014, "ur"),
  (0x10015, "hi"),
  (0x10016, "th"),
  (0x10017, "ko"),
  (0x10018, "lt"),
  (0x10019, "pl"),
  (0x1001A, "hu"),
  (0x1001B, "et"),
  (0x1001C, "lv"),
  (0x1001E, "fo"),
  (0x1001F, "fa"),
  (0x10020, "ru"),
  (0x10021, "zh-cn"),
  (0x10022, "nl"),
  (0x10023, "ga"),
  (0x10024, "sq"),
  (0x10025, "ro"),
  (0x10026, "cs"),
  (0x10027, "sk"),
  (0x10028, "sl"),
  (0x10029, "yi"),
  (0x1002A, "sr"),
  (0x1002B, "mk"),
  (0x1002C, "bg"),
  (0x1002D, "uk"),
  (0x1002E, "be"),
  (0x1002F, "uz"),
  (0x10030, "kk"),
  (0x10031, "az"),
  (0x10031, "az"),
  (0x10032, "ar"),
  (0x10033, "hy"),
  (0x10034, "ka"),
  (0x10035, "mo"),
  (0x10036, "ky"),
  (0x10037, "tg"),
  (0x10038, "tk"),
  (0x10039, "mn"),
  (0x10039, "mn"),
  (0x1003A, "mn"),
  (0x1003B, "ps"),
  (0x1003C, "ku"),
  (0x1003D, "ks"),
  (0x1003E, "sd"),
  (0x1003F, "bo"),
  (0x10040, "ne"),
  (0x10041, "sa"),
  (0x10042, "mr"),
  (0x10043, "bn"),
  (0x10044, "as"),
  (0x10045, "gu"),
  (0x10046, "pa"),
  (0x10047, "or"),
  (0x10048, "ml"),
  (0x10049, "kn"),
  (0x1004A, "ta"),
  (0x1004B, "te"),
  (0x1004C, "si"),
  (0x1004D, "my"),
  (0x1004E, "km"),
  (0x1004F, "lo"),
  (0x10050, "vi"),
  (0x10051, "id"),
  (0x10052, "tl"),
  (0x10053, "ms"),
  (0x10054, "ms"),
  (0x10055, "am"),
  (0x10056, "ti"),
  (0x10057, "om"),
  (0x10058, "so"),
  (0x10059, "sw"),
  (0x1005A, "rw"),
  (0x1005B, "rn"),
  (0x1005C, "ny"),
  (0x1005D, "mg"),
  (0x1005E, "eo"),
  (0x10080, "cy"),
  (0x10081, "eu"),
  (0x10082, "ca"),
  (0x10083, "la"),
  (0x10084, "qu"),
  (0x10085, "gn"),
  (0x10086, "ay"),
  (0x10087, "tt"),
  (0x10088, "ug"),
  (0x10089, "dz"),
  (0x1008A, "jw"),
  (0x1008B, "su"),
  (0x1008C, "gl"),
  (0x1008D, "af"),
  (0x1008E, "br"),
  (0x1008F, "iu"),
  (0x10090, "gd"),
  (0x10091, "gv"),
  (0x10092, "ga"),
  (0x10093, "to"),
  (0x10094, "el"),
  (0x10095, "ik"),
  (0x10096, "az"),
  (0x30001, "ar"),
  (0x30004, "zh"),
  (0x30009, "en"),
  (0x30401, "ar"),
  (0x30402, "bg"),
  (0x30403, "ca"),
  (0x30404, "zh-tw"),
  (0x30405, "cs"),
  (0x30406, "da"),
  (0x30407, "de"),
  (0x30408, "el"),
  (0x30409, "en"),
  (0x3040A, "es"),
  (0x3040B, "fi"),
  (0x3040C, "fr"),
  (0x3040D, "he"),
  (0x3040E, "hu"),
  (0x3040F, "is"),
  (0x30410, "it"),
  (0x30411, "ja"),
  (0x30412, "ko"),
  (0x30413, "nl"),
  (0x30414, "no"),
  (0x30415, "pl"),
  (0x30416, "pt"),
  (0x30417, "rm"),
  (0x30418, "ro"),
  (0x30419, "ru"),
  (0x3041A, "hr"),
  (0x3041B, "sk"),
  (0x3041C, "sq"),
  (0x3041D, "sv"),
  (0x3041E, "th"),
  (0x3041F, "tr"),
  (0x30420, "ur"),
  (0x30421, "id"),
  (0x30422, "uk"),
  (0x30423, "be"),
  (0x30424, "sl"),
  (0x30425, "et"),
  (0x30426, "lv"),
  (0x30427, "lt"),
  (0x30428, "tg"),
  (0x30429, "fa"),
  (0x3042A, "vi"),
  (0x3042B, "hy"),
  (0x3042C, "az"),
  (0x3042D, "eu"),
  (0x3042E, "wen"),
  (0x3042F, "mk"),
  (0x30430, "st"),
  (0x30431, "ts"),
  (0x30432, "tn"),
  (0x30433, "ven"),
  (0x30434, "xh"),
  (0x30435, "zu"),
  (0x30436, "af"),
  (0x30437, "ka"),
  (0x30438, "fo"),
  (0x30439, "hi"),
  (0x3043A, "mt"),
  (0x3043B, "se"),
  (0x3043C, "ga"),
  (0x3043D, "yi"),
  (0x3043E, "ms"),
  (0x3043F, "kk"),
  (0x30440, "ky"),
  (0x30441, "sw"),
  (0x30442, "tk"),
  (0x30443, "uz"),
  (0x30444, "tt"),
  (0x30445, "bn"),
  (0x30446, "pa"),
  (0x30447, "gu"),
  (0x30448, "or"),
  (0x30449, "ta"),
  (0x3044A, "te"),
  (0x3044B, "kn"),
  (0x3044C, "ml"),
  (0x3044D, "as"),
  (0x3044E, "mr"),
  (0x3044F, "sa"),
  (0x30450, "mn"),
  (0x30451, "bo"),
  (0x30452, "cy"),
  (0x30453, "km"),
  (0x30454, "lo"),
  (0x30455, "my"),
  (0x30456, "gl"),
  (0x30457, "kok"),
  (0x30458, "mni"),
  (0x30459, "sd"),
  (0x3045A, "syr"),
  (0x3045B, "si"),
  (0x3045C, "chr"),
  (0x3045D, "iu"),
  (0x3045E, "am"),
  (0x30460, "ks"),
  (0x30461, "ne"),
  (0x30462, "fy"),
  (0x30463, "ps"),
  (0x30464, "phi"),
  (0x30465, "div"),
  (0x30468, "ha"),
  (0x3046A, "yo"),
  (0x30470, "ibo"),
  (0x30471, "kau"),
  (0x30472, "om"),
  (0x30473, "ti"),
  (0x30474, "gn"),
  (0x30475, "haw"),
  (0x30476, "la"),
  (0x30477, "so"),
  (0x30479, "pap"),
  (0x30481, "mi"),
  (0x30801, "ar"),
  (0x30804, "zh-cn"),
  (0x30807, "de"),
  (0x30809, "en"),
  (0x3080A, "es"),
  (0x3080C, "fr"),
  (0x30810, "it"),
  (0x30812, "ko"),
  (0x30813, "nl"),
  (0x30814, "nn"),
  (0x30816, "pt"),
  (0x30818, "mo"),
  (0x30819, "ru"),
  (0x3081A, "sr"),
  (0x3081D, "sv"),
  (0x30820, "ur"),
  (0x30827, "lt"),
  (0x3082C, "az"),
  (0x3083C, "gd"),
  (0x3083E, "ms"),
  (0x30843, "uz"),
  (0x30845, "bn"),
  (0x30846, "ar"),
  (0x30850, "mn"),
  (0x30851, "bo"),
  (0x30851, "dz"),
  (0x30860, "ks"),
  (0x30861, "ne"),
  (0x30873, "ti"),
  (0x30C01, "ar"),
  (0x30C04, "zh-hk"),
  (0x30C07, "de"),
  (0x30C09, "en"),
  (0x30C0A, "es"),
  (0x30C0C, "fr"),
  (0x30C1A, "sr"),
  (0x31001, "ar"),
  (0x31004, "zh-sg"),
  (0x31007, "de"),
  (0x31009, "en"),
  (0x3100A, "es"),
  (0x3100C, "fr"),
  (0x31401, "ar"),
  (0x31404, "zh-mo"),
  (0x31407, "de"),
  (0x31409, "en"),
  (0x3140A, "es"),
  (0x3140C, "fr"),
  (0x3141A, "bs"),
  (0x31801, "ar"),
  (0x31809, "en"),
  (0x3180A, "es"),
  (0x3180C, "fr"),
  (0x31C01, "ar"),
  (0x31C09, "en"),
  (0x31C0A, "es"),
  (0x31C0C, "fr"),
  (0x32001, "ar"),
  (0x32009, "en"),
  (0x3200A, "es"),
  (0x3200C, "fr"),
  (0x32401, "ar"),
  (0x32409, "en"),
  (0x3240A, "es"),
  (0x3240C, "fr"),
  (0x32801, "ar"),
  (0x32809, "en"),
  (0x3280A, "es"),
  (0x3280C, "fr"),
  (0x32C01, "ar"),
  (0x32C09, "en"),
  (0x32C0A, "es"),
  (0x32C0C, "fr"),
  (0x33001, "ar"),
  (0x33009, "en"),
  (0x3300A, "es"),
  (0x3300C, "fr"),
  (0x33401, "ar"),
  (0x33409, "en"),
  (0x3340A, "es"),
  (0x3340C, "fr"),
  (0x33801, "ar"),
  (0x3380A, "es"),
  (0x3380C, "fr"),
  (0x33C01, "ar"),
  (0x33C09, "en"),
  (0x33C0A, "es"),
  (0x33C0C, "fr"),
  (0x34001, "ar"),
  (0x34009, "en"),
  (0x3400A, "es"),
  (0x34409, "en"),
  (0x3440A, "es"),
  (0x34809, "en"),
  (0x3480A, "es"),
  (0x34C0A, "es"),
  (0x3500A, "es"),
  (0x3540A, "es"),
  (0x3E40A, "es"),
  (0x3E40C, "fr"),
]

///|
fn language_lookup(key : UInt) -> String? {
  let mut l = 0
  let mut h = languages.length()
  while l < h {
    let mid = (l + h) / 2
    let (k, v) = languages[mid]
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
fn get_language(platform_id : UInt16, language_id : UInt16) -> String {
  match platform_id.to_int() {
    0 => ""
    1 | 3 => {
      let key = (platform_id.to_int().reinterpret_as_uint() << 16) |
        language_id.to_int().reinterpret_as_uint()
      match language_lookup(key) {
        None => "zz"
        Some(v) => v
      }
    }
    _ => "zz"
  }
}

///|
test "get_language maps known IDs" {
  inspect(get_language(1, 0), content="en")
  inspect(get_language(3, 9), content="en")
  inspect(get_language(0, 0), content="")
}
