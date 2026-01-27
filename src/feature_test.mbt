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
fn feature_test_push_u16_be(out : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((u >> 8) & mask).to_byte())
  out.push((u & mask).to_byte())
}

///|
fn feature_test_push_u32_be(out : Array[Byte], v : UInt) -> Unit {
  let mask = 255 |> Int::reinterpret_as_uint
  out.push(((v >> 24) & mask).to_byte())
  out.push(((v >> 16) & mask).to_byte())
  out.push(((v >> 8) & mask).to_byte())
  out.push((v & mask).to_byte())
}

///|
fn feature_test_u32(x : Int) -> UInt {
  x.reinterpret_as_uint()
}

///|
fn feature_test_build_sfnt(tables : Array[(UInt, Bytes)]) -> Bytes {
  // Caller must provide tags in sorted order for internal table_range binary search.
  let num_tables = tables.length()
  let header_len = 12 + num_tables * 16
  let out : Array[Byte] = Array::new()
  feature_test_push_u32_be(out, feature_test_u32(0x00010000))
  feature_test_push_u16_be(out, num_tables)
  feature_test_push_u16_be(out, 0)
  feature_test_push_u16_be(out, 0)
  feature_test_push_u16_be(out, 0)
  let mut offset = header_len
  for t in tables {
    let (tag, data) = t
    feature_test_push_u32_be(out, tag)
    feature_test_push_u32_be(out, feature_test_u32(0))
    feature_test_push_u32_be(out, feature_test_u32(offset))
    feature_test_push_u32_be(out, feature_test_u32(data.length()))
    offset = offset + data.length()
  }
  for t in tables {
    let (_, data) = t
    for b in data.iter() {
      out.push(b)
    }
  }
  Bytes::from_array(out.op_as_view())
}

///|
fn feature_test_build_gsubgpos(script_tag : UInt, feature_tag : UInt) -> Bytes {
  // Minimal GSUB/GPOS table containing:
  // - ScriptList with 1 script and 2 language systems (DFLT + ENG)
  // - FeatureList with 1 feature
  //
  // Offsets are relative to start of the table.
  let header_len = 10
  let script_list_offset = header_len
  // ScriptList: count(2) + record(6) + ScriptTable(26)
  let script_table_offset = 8
  let script_table_len = 26
  let script_list_len = 2 + 6 + script_table_len
  let feature_list_offset = script_list_offset + script_list_len
  let out : Array[Byte] = Array::new()
  // Header
  feature_test_push_u16_be(out, 1) // major
  feature_test_push_u16_be(out, 0) // minor
  feature_test_push_u16_be(out, script_list_offset)
  feature_test_push_u16_be(out, feature_list_offset)
  feature_test_push_u16_be(out, 0) // lookupListOffset (unused here)
  // ScriptList
  feature_test_push_u16_be(out, 1) // scriptCount
  feature_test_push_u32_be(out, script_tag)
  feature_test_push_u16_be(out, script_table_offset) // scriptOffset
  // ScriptTable (default + 1 lang record)
  feature_test_push_u16_be(out, 10) // defaultLangSysOffset
  feature_test_push_u16_be(out, 1) // langSysCount
  feature_test_push_u32_be(out, 0x454E4720) // "ENG "
  feature_test_push_u16_be(out, 18) // langSysOffset
  // Default LangSys @10 (8 bytes)
  feature_test_push_u16_be(out, 0) // lookupOrder
  feature_test_push_u16_be(out, 0xFFFF) // reqFeatureIndex
  feature_test_push_u16_be(out, 1) // featureIndexCount
  feature_test_push_u16_be(out, 0) // featureIndices[0]
  // ENG LangSys @18 (8 bytes)
  feature_test_push_u16_be(out, 0)
  feature_test_push_u16_be(out, 0xFFFF)
  feature_test_push_u16_be(out, 1)
  feature_test_push_u16_be(out, 0)
  // FeatureList
  feature_test_push_u16_be(out, 1) // featureCount
  feature_test_push_u32_be(out, feature_tag)
  feature_test_push_u16_be(out, 8) // featureOffset (FeatureTable starts after records)
  // FeatureTable (minimal)
  feature_test_push_u16_be(out, 0) // featureParams
  feature_test_push_u16_be(out, 0) // lookupIndexCount
  // Ensure lengths match expectations (no-op; sizes computed above)
  Bytes::from_array(out.op_as_view())
}

///|
test "FontRef::writing_systems enumerates GSUB/GPOS writing systems and features" {
  let gsub = feature_test_build_gsubgpos(0x6C61746E, 0x6C696761) // "latn", "liga"
  let gpos = feature_test_build_gsubgpos(0x6C61746E, 0x6B65726E) // "latn", "kern"
  // NOTE: table records must be sorted by tag (GPOS < GSUB).
  let sfnt = feature_test_build_sfnt(
    Array::from_fixed_array([(0x47504F53, gpos), (0x47535542, gsub)]),
  )
  let font = FontRef::from_offset(sfnt, 0).unwrap()
  let wss = font.writing_systems().iter().to_array()
  // DFLT + ENG
  inspect(wss.length(), content="2")
  // Find the ENG writing system and verify language mapping.
  let mut found_eng = false
  for ws in wss.iter() {
    if ws.language_tag() == 0x454E4720 { // "ENG "
      found_eng = true
      let lang = ws.language().unwrap()
      inspect(lang.language(), content="en")
      // Features should include stage0 liga + stage1 kern.
      let feats = ws.features().iter().to_array()
      inspect(feats.length(), content="2")
      inspect(
        feats[0].tag().to_string(),
        content=tag_from_str_lossy("liga").to_string(),
      )
      inspect(
        match feats[0].action() {
          Substitution => true
          _ => false
        },
        content="true",
      )
      inspect(
        feats[1].tag().to_string(),
        content=tag_from_str_lossy("kern").to_string(),
      )
      inspect(
        match feats[1].action() {
          Adjustment => true
          _ => false
        },
        content="true",
      )
    }
  }
  inspect(found_eng, content="true")
}

///|
test "FontRef::features returns known features (unique across GSUB/GPOS)" {
  let gsub = feature_test_build_gsubgpos(0x6C61746E, 0x6C696761) // "latn", "liga"
  let gpos = feature_test_build_gsubgpos(0x6C61746E, 0x6B65726E) // "latn", "kern"
  let sfnt = feature_test_build_sfnt(
    Array::from_fixed_array([(0x47504F53, gpos), (0x47535542, gsub)]),
  )
  let font = FontRef::from_offset(sfnt, 0).unwrap()
  let feats = font.features().iter().to_array()
  inspect(feats.length(), content="2")
}
