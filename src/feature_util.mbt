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
/// Feature description tables.
///
/// Ported from `swash/src/feature/util.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
/// Bitset for feature de-duplication.
pub struct SeenFeatures {
  bits : Array[UInt]
}

///|
pub fn SeenFeatures::new() -> SeenFeatures {
  SeenFeatures::{ bits: Array::makei(6, _ => 0U) }
}

///|
pub fn SeenFeatures::mark(self : SeenFeatures, feature_index : Int) -> Bool {
  if feature_index < 0 {
    return false
  }
  let word_index = feature_index / 32
  if word_index < 0 || word_index >= self.bits.length() {
    return false
  }
  let bit = (1).reinterpret_as_uint() << (feature_index % 32)
  let word = self.bits[word_index]
  if (word & bit) == 0U {
    self.bits[word_index] = word | bit
    true
  } else {
    false
  }
}

///|
let at_features : ReadOnlyArray[(Tag, String)] = [
  (0x61616C74, "Access All Alternates"),
  (0x61627666, "Above-base Forms"),
  (0x6162766D, "Above-base Mark Positioning"),
  (0x61627673, "Above-base Substitutions"),
  (0x61667263, "Alternative Fractions"),
  (0x616B686E, "Akhands"),
  (0x626C7766, "Below-base Forms"),
  (0x626C776D, "Below-base Mark Positioning"),
  (0x626C7773, "Below-base Substitutions"),
  (0x63327063, "Petite Capitals From Capitals"),
  (0x63327363, "Small Capitals From Capitals"),
  (0x63616C74, "Contextual Alternates"),
  (0x63617365, "Case-Sensitive Forms"),
  (0x63636D70, "Glyph Composition / Decomposition"),
  (0x63666172, "Conjunct Form After Ro"),
  (0x63687773, "Contextual Half-width Spacing"),
  (0x636A6374, "Conjunct Forms"),
  (0x636C6967, "Contextual Ligatures"),
  (0x63706374, "Centered CJK Punctuation"),
  (0x63707370, "Capital Spacing"),
  (0x63737768, "Contextual Swash"),
  (0x63757273, "Cursive Positioning"),
  (0x64697374, "Distances"),
  (0x646C6967, "Discretionary Ligatures"),
  (0x646E6F6D, "Denominators"),
  (0x64746C73, "Dotless Forms"),
  (0x65787074, "Expert Forms"),
  (0x66616C74, "Final Glyph on Line Alternates"),
  (0x66696E32, "Terminal Forms #2"),
  (0x66696E33, "Terminal Forms #3"),
  (0x66696E61, "Terminal Forms"),
  (0x666C6163, "Flattened accent forms"),
  (0x66726163, "Fractions"),
  (0x66776964, "Full Widths"),
  (0x68616C66, "Half Forms"),
  (0x68616C6E, "Halant Forms"),
  (0x68616C74, "Alternate Half Widths"),
  (0x68697374, "Historical Forms"),
  (0x686B6E61, "Horizontal Kana Alternates"),
  (0x686C6967, "Historical Ligatures"),
  (0x686E676C, "Hangul"),
  (0x686F6A6F, "Hojo Kanji Forms"),
  (0x68776964, "Half Widths"),
  (0x696E6974, "Initial Forms"),
  (0x69736F6C, "Isolated Forms"),
  (0x6974616C, "Italics"),
  (0x6A616C74, "Justification Alternates"),
  (0x6A703738, "JIS78 Forms"),
  (0x6A703833, "JIS83 Forms"),
  (0x6A703930, "JIS90 Forms"),
  (0x6A703034, "JIS2004 Forms"),
  (0x6B65726E, "Kerning"),
  (0x6C666264, "Left Bounds"),
  (0x6C696761, "Standard Ligatures"),
  (0x6C6A6D6F, "Leading Jamo Forms"),
  (0x6C6E756D, "Lining Figures"),
  (0x6C6F636C, "Localized Forms"),
  (0x6C747261, "Left-to-right alternates"),
  (0x6C74726D, "Left-to-right mirrored forms"),
  (0x6D61726B, "Mark Positioning"),
  (0x6D656432, "Medial Forms #2"),
  (0x6D656469, "Medial Forms"),
  (0x6D67726B, "Mathematical Greek"),
  (0x6D6B6D6B, "Mark to Mark Positioning"),
  (0x6D736574, "Mark Positioning via Substitution"),
  (0x6E616C74, "Alternate Annotation Forms"),
  (0x6E6C636B, "NLC Kanji Forms"),
  (0x6E756B74, "Nukta Forms"),
  (0x6E756D72, "Numerators"),
  (0x6F6E756D, "Oldstyle Figures"),
  (0x6F706264, "Optical Bounds"),
  (0x6F72646E, "Ordinals"),
  (0x6F726E6D, "Ornaments"),
  (0x70616C74, "Proportional Alternate Widths"),
  (0x70636170, "Petite Capitals"),
  (0x706B6E61, "Proportional Kana"),
  (0x706E756D, "Proportional Figures"),
  (0x70726566, "Pre-Base Forms"),
  (0x70726573, "Pre-base Substitutions"),
  (0x70737466, "Post-base Forms"),
  (0x70737473, "Post-base Substitutions"),
  (0x70776964, "Proportional Widths"),
  (0x71776964, "Quarter Widths"),
  (0x72616E64, "Randomize"),
  (0x72636C74, "Required Contextual Alternates"),
  (0x726B7266, "Rakar Forms"),
  (0x726C6967, "Required Ligatures"),
  (0x72706866, "Reph Forms"),
  (0x72746264, "Right Bounds"),
  (0x72746C61, "Right-to-left alternates"),
  (0x72746C6D, "Right-to-left mirrored forms"),
  (0x72756279, "Ruby Notation Forms"),
  (0x7276726E, "Required Variation Alternates"),
  (0x73616C74, "Stylistic Alternates"),
  (0x73696E66, "Scientific Inferiors"),
  (0x73697A65, "Optical size"),
  (0x736D6370, "Small Capitals"),
  (0x736D706C, "Simplified Forms"),
  (0x73733031, "Stylistic Set 1"),
  (0x73733032, "Stylistic Set 2"),
  (0x73733033, "Stylistic Set 3"),
  (0x73733034, "Stylistic Set 4"),
  (0x73733035, "Stylistic Set 5"),
  (0x73733036, "Stylistic Set 6"),
  (0x73733037, "Stylistic Set 7"),
  (0x73733038, "Stylistic Set 8"),
  (0x73733039, "Stylistic Set 9"),
  (0x73733130, "Stylistic Set 10"),
  (0x73733131, "Stylistic Set 11"),
  (0x73733132, "Stylistic Set 12"),
  (0x73733133, "Stylistic Set 13"),
  (0x73733134, "Stylistic Set 14"),
  (0x73733135, "Stylistic Set 15"),
  (0x73733136, "Stylistic Set 16"),
  (0x73733137, "Stylistic Set 17"),
  (0x73733138, "Stylistic Set 18"),
  (0x73733139, "Stylistic Set 19"),
  (0x73733230, "Stylistic Set 20"),
  (0x73737479, "Math script style alternates"),
  (0x73746368, "Stretching Glyph Decomposition"),
  (0x73756273, "Subscript"),
  (0x73757073, "Superscript"),
  (0x73777368, "Swash"),
  (0x7469746C, "Titling"),
  (0x746A6D6F, "Trailing Jamo Forms"),
  (0x746E616D, "Traditional Name Forms"),
  (0x746E756D, "Tabular Figures"),
  (0x74726164, "Traditional Forms"),
  (0x74776964, "Third Widths"),
  (0x756E6963, "Unicase"),
  (0x76616C74, "Alternate Vertical Metrics"),
  (0x76617475, "Vattu Variants"),
  (0x76636877, "Vertical Contextual Half-width Spacing"),
  (0x76657274, "Vertical Writing"),
  (0x7668616C, "Alternate Vertical Half Metrics"),
  (0x766A6D6F, "Vowel Jamo Forms"),
  (0x766B6E61, "Vertical Kana Alternates"),
  (0x766B726E, "Vertical Kerning"),
  (0x7670616C, "Proportional Alternate Vertical Metrics"),
  (0x76727432, "Vertical Alternates and Rotation"),
  (0x76727472, "Vertical Alternates for Rotation"),
  (0x7A65726F, "Slashed Zero"),
]

///|
/// Returns a feature description for the specified tag.
pub fn desc_from_at(tag : Tag) -> (Int, String)? {
  let mut l = 0
  let mut h = at_features.length()
  while l < h {
    let mid = (l + h) / 2
    let (k, v) = at_features[mid]
    if k < tag {
      l = mid + 1
    } else if k > tag {
      h = mid
    } else {
      return Some((mid, v))
    }
  }
  None
}

///|
let aat_to_at : ReadOnlyArray[(UInt, UInt)] = [
  (0x0100, 0x0056),
  (0x0102, 0x0035),
  (0x0104, 0x0017),
  (0x0112, 0x000F),
  (0x0114, 0x0025),
  (0x0114, 0x0027),
  (0x030E, 0x0081),
  (0x0400, 0x0085),
  (0x0400, 0x008B),
  (0x0600, 0x007E),
  (0x0601, 0x004C),
  (0x0A01, 0x0079),
  (0x0A02, 0x0078),
  (0x0A03, 0x0047),
  (0x0A04, 0x005E),
  (0x0B01, 0x0004),
  (0x0B02, 0x0020),
  (0x0E04, 0x008D),
  (0x0F0A, 0x003E),
  (0x1304, 0x007B),
  (0x1400, 0x007F),
  (0x1401, 0x0061),
  (0x1402, 0x002F),
  (0x1403, 0x0030),
  (0x1404, 0x0031),
  (0x140A, 0x001A),
  (0x140B, 0x0032),
  (0x140C, 0x0029),
  (0x140D, 0x0042),
  (0x140E, 0x007D),
  (0x1500, 0x0045),
  (0x1501, 0x0037),
  (0x1600, 0x0051),
  (0x1600, 0x004B),
  (0x1601, 0x0021),
  (0x1602, 0x002A),
  (0x1603, 0x0080),
  (0x1604, 0x0052),
  (0x1605, 0x0049),
  (0x1605, 0x0082),
  (0x1605, 0x008A),
  (0x1606, 0x0024),
  (0x1606, 0x0086),
  (0x1701, 0x0028),
  (0x1C02, 0x005B),
  (0x2002, 0x002D),
  (0x2100, 0x000A),
  (0x2102, 0x0011),
  (0x2200, 0x0026),
  (0x2202, 0x0088),
  (0x2302, 0x0062),
  (0x2304, 0x0063),
  (0x2306, 0x0064),
  (0x2308, 0x0065),
  (0x230A, 0x0066),
  (0x230C, 0x0067),
  (0x230E, 0x0068),
  (0x2310, 0x0069),
  (0x2312, 0x006A),
  (0x2314, 0x006B),
  (0x2316, 0x006C),
  (0x2318, 0x006D),
  (0x231A, 0x006E),
  (0x231C, 0x006F),
  (0x231E, 0x0070),
  (0x2320, 0x0071),
  (0x2322, 0x0072),
  (0x2324, 0x0073),
  (0x2326, 0x0074),
  (0x2328, 0x0075),
  (0x2400, 0x0009),
  (0x2402, 0x007A),
  (0x2404, 0x0012),
  (0x2501, 0x0060),
  (0x2502, 0x004A),
  (0x2601, 0x0015),
  (0x2602, 0x0014),
]

///|
/// Returns a feature tag and description from an AAT feature and selector.
pub fn desc_from_aat(
  feature : UInt16,
  selector : UInt16,
) -> (Int, Tag, String)? {
  let key = (
      (feature.to_int().reinterpret_as_uint() << 8) |
      selector.to_int().reinterpret_as_uint()
    ) &
    0xFFFFU
  let mut l = 0
  let mut h = aat_to_at.length()
  while l < h {
    let mid = (l + h) / 2
    let (k, v) = aat_to_at[mid]
    if k < key {
      l = mid + 1
    } else if k > key {
      h = mid
    } else {
      let index = v.reinterpret_as_int()
      if index < 0 || index >= at_features.length() {
        return None
      }
      let (tag, desc) = at_features[index]
      return Some((mid, tag, desc))
    }
  }
  None
}
