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
/// OpenType (GSUB/GPOS) writing systems and feature enumeration.
///
/// Ported from `swash/src/feature/at.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
priv struct AtScript {
  data : Bytes
  gsub : UInt
  gpos : UInt
  gsub_offset : UInt
  gpos_offset : UInt
  tag : Tag
}

///|
fn AtScript::languages(self : AtScript) -> AtLanguages {
  AtLanguages::new(
    self.data,
    self.gsub,
    self.gpos,
    self.gsub_offset,
    self.gpos_offset,
  )
}

///|
priv struct AtScripts {
  data : Bytes
  gsub : UInt
  gpos : UInt
}

///|
fn AtScripts::new(data : Bytes, gsub : UInt, gpos : UInt) -> AtScripts {
  AtScripts::{ data, gsub, gpos }
}

///|
fn AtScripts::iter(self : AtScripts) -> Iter[AtScript] {
  let data = self.data
  let gsub = self.gsub
  let gpos = self.gpos
  let mut in_gsub = true
  let mut len = @internal.script_count(data, gsub).to_int()
  let mut cur = 0
  let mut done = false
  Iter::new(fn() {
    while !done {
      if in_gsub {
        if cur < len {
          let index = cur.to_uint16()
          cur = cur + 1
          match @internal.script_at(data, gsub, index) {
            None => ()
            Some((tag, offset)) => {
              let gpos_offset = @internal.script_by_tag(data, gpos, tag).unwrap_or(
                0U,
              )
              return Some(AtScript::{
                data,
                gsub,
                gpos,
                gsub_offset: offset,
                gpos_offset,
                tag,
              })
            }
          }
        } else {
          in_gsub = false
          cur = 0
          len = @internal.script_count(data, gpos).to_int()
        }
      } else if cur < len {
        let index = cur.to_uint16()
        cur = cur + 1
        match @internal.script_at(data, gpos, index) {
          None => ()
          Some((tag, offset)) =>
            if @internal.script_by_tag(data, gsub, tag) is Some(_) {
              ()
            } else {
              return Some(AtScript::{
                data,
                gsub,
                gpos,
                gsub_offset: 0U,
                gpos_offset: offset,
                tag,
              })
            }
        }
      } else {
        done = true
      }
    }
    None
  })
}

///|
priv struct AtLangSys {
  data : Bytes
  gsub : UInt
  gpos : UInt
  gsub_offset : UInt
  gpos_offset : UInt
  tag : Tag
}

///|
priv struct AtLanguages {
  data : Bytes
  gsub : UInt
  gpos : UInt
  gsub_script : UInt
  gpos_script : UInt
}

///|
fn AtLanguages::new(
  data : Bytes,
  gsub : UInt,
  gpos : UInt,
  gsub_script : UInt,
  gpos_script : UInt,
) -> AtLanguages {
  AtLanguages::{ data, gsub, gpos, gsub_script, gpos_script }
}

///|
fn AtLanguages::iter(self : AtLanguages) -> Iter[AtLangSys] {
  let data = self.data
  let gsub = self.gsub
  let gpos = self.gpos
  let gsub_script = self.gsub_script
  let gpos_script = self.gpos_script
  let mut in_gsub = true
  let mut len = @internal.script_language_count(data, gsub_script).to_int()
  let mut cur = 0
  let mut done = false
  Iter::new(fn() {
    while !done {
      if in_gsub {
        if cur < len {
          let index = cur.to_uint16()
          cur = cur + 1
          match @internal.script_language_at(data, gsub_script, index) {
            None => ()
            Some((tag, offset)) => {
              let gsub_default = tag == @internal.DFLT
              let gpos_offset = if gsub_default {
                @internal.script_default_language(data, gpos_script).unwrap_or(
                  0U,
                )
              } else {
                match
                  @internal.script_language_by_tag(data, gpos_script, Some(tag)) {
                  None => 0U
                  Some((o, _)) => o
                }
              }
              return Some(AtLangSys::{
                data,
                gsub,
                gpos,
                gsub_offset: offset,
                gpos_offset,
                tag,
              })
            }
          }
        } else {
          in_gsub = false
          cur = 0
          len = @internal.script_language_count(data, gpos_script).to_int()
        }
      } else if cur < len {
        let index = cur.to_uint16()
        cur = cur + 1
        match @internal.script_language_at(data, gpos_script, index) {
          None => ()
          Some((tag, offset)) =>
            if @internal.script_language_by_tag(data, gsub_script, Some(tag))
              is Some(_) {
              ()
            } else {
              return Some(AtLangSys::{
                data,
                gsub,
                gpos,
                gsub_offset: 0U,
                gpos_offset: offset,
                tag,
              })
            }
        }
      } else {
        done = true
      }
    }
    None
  })
}

///|
priv struct AtWritingSystem {
  lang : AtLangSys
  script_tag : Tag
}

///|
fn AtWritingSystem::script_tag(self : AtWritingSystem) -> Tag {
  self.script_tag
}

///|
fn AtWritingSystem::language_tag(self : AtWritingSystem) -> Tag {
  self.lang.tag
}

///|
fn AtWritingSystem::features(self : AtWritingSystem) -> AtFeatures {
  AtFeatures::new(self.lang)
}

///|
priv struct AtWritingSystems {
  scripts : AtScripts
}

///|
fn AtWritingSystems::new(scripts : AtScripts) -> AtWritingSystems {
  AtWritingSystems::{ scripts, }
}

///|
fn AtWritingSystems::iter(self : AtWritingSystems) -> Iter[AtWritingSystem] {
  let scripts = self.scripts.iter()
  let mut has_langs = false
  let mut langs = Iter::new(fn() { None })
  let mut script_tag : Tag = 0U
  Iter::new(fn() {
    while true {
      if !has_langs {
        match scripts.next() {
          None => return None
          Some(s) => {
            script_tag = s.tag
            langs = s.languages().iter()
            has_langs = true
          }
        }
      }
      match langs.next() {
        None => has_langs = false
        Some(lang) => return Some(AtWritingSystem::{ lang, script_tag })
      }
    }
    None
  })
}

///|
priv struct AtFeature {
  stage : Byte
  tag : Tag
}

///|
priv struct AtFeatures {
  lang : AtLangSys
}

///|
fn AtFeatures::new(lang : AtLangSys) -> AtFeatures {
  AtFeatures::{ lang, }
}

///|
fn AtFeatures::iter(self : AtFeatures) -> Iter[AtFeature] {
  let data = self.lang.data
  let gsub = self.lang.gsub
  let gpos = self.lang.gpos
  let gsub_language = self.lang.gsub_offset
  let gpos_language = self.lang.gpos_offset
  let mut stage : Int = 0
  let mut len = @internal.language_feature_count(data, gsub_language).to_int()
  let mut cur = 0
  let mut done = false
  Iter::new(fn() {
    while !done {
      let (table, language) = if stage == 0 {
        (gsub, gsub_language)
      } else {
        (gpos, gpos_language)
      }
      if cur < len {
        let index = cur.to_uint16()
        cur = cur + 1
        match @internal.language_feature_at(data, language, index) {
          None => ()
          Some(feature_index) =>
            match @internal.feature_at(data, table, feature_index) {
              None => ()
              Some((tag, _)) =>
                return Some(AtFeature::{ stage: stage.to_byte(), tag })
            }
        }
      } else if stage == 0 {
        stage = 1
        len = @internal.language_feature_count(data, gpos_language).to_int()
        cur = 0
      } else {
        done = true
      }
    }
    None
  })
}

///|
priv struct AtAllFeatures {
  data : Bytes
  seen : SeenFeatures
  table : UInt
  next_table : UInt
  stage : Int
  len : Int
  cur : Int
}

///|
fn AtAllFeatures::new(data : Bytes, gsub : UInt, gpos : UInt) -> AtAllFeatures {
  AtAllFeatures::{
    data,
    seen: SeenFeatures::new(),
    table: gsub,
    next_table: gpos,
    stage: 0,
    len: @internal.feature_count(data, gsub).to_int(),
    cur: 0,
  }
}

///|
fn AtAllFeatures::iter(self : AtAllFeatures) -> Iter[(Int, Tag)] {
  let data = self.data
  let seen = self.seen
  let mut table = self.table
  let mut next_table = self.next_table
  let mut stage = self.stage
  let mut len = self.len
  let mut cur = self.cur
  Iter::new(fn() {
    while true {
      if cur >= len {
        if next_table == 0U {
          return None
        }
        table = next_table
        next_table = 0U
        stage = 1
        cur = 0
        len = @internal.feature_count(data, table).to_int()
        if len == 0 {
          return None
        }
      }
      let index = cur.to_uint16()
      cur = cur + 1
      match @internal.feature_at(data, table, index) {
        None => continue
        Some((tag, _)) =>
          match desc_from_at(tag) {
            None => continue
            Some((ix, _)) =>
              if seen.mark(ix) {
                return Some((stage, tag))
              } else {
                continue
              }
          }
      }
    }
    None
  })
}
