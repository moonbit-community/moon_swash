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
/// Typographic features and writing systems.
///
/// Ported from `swash/src/feature/*` (swash is dual-licensed Apache-2.0 OR MIT).

///|
const MARK : Tag = 0x6D61726B // "mark"

///|
const MKMK : Tag = 0x6D6B6D6B // "mkmk"

///|
const KERN : Tag = 0x6B65726E // "kern"

///|
const DFLT : Tag = 0x44464C54 // "DFLT"

///|
priv enum Kind {
  Empty
  At(UInt, UInt)
  Aat(UInt, Bool)
}

///|
fn Kind::from_font(font : FontRef) -> Kind {
  let gsub = font.table_offset(@internal.GSUB)
  let gpos = font.table_offset(@internal.GPOS)
  if gsub != 0U || gpos != 0U {
    return Kind::At(gsub, gpos)
  }
  let morx = font.table_offset(0x6D6F7278) // "morx"
  if morx != 0U {
    let kern = font.table_offset(0x6B65726E) != 0U || // "kern"
      font.table_offset(0x6B657278) != 0U // "kerx"
    return Kind::Aat(morx, kern)
  }
  Kind::Empty
}

///|
/// Modification performed by a feature.
pub(all) enum Action {
  /// Replaces one or more glyphs such as in ligation.
  Substitution
  /// Attaches one glyph to another such as in accent mark placement.
  Attachment
  /// Adjusts the position of one or more glyphs such as in kerning.
  Adjustment
}

///|
/// Typographic rule that produces modifications to a sequence of glyphs.
struct Feature {
  tag : Tag
  name : String?
  action : Action
}

///|
fn Feature::from_tag(tag : Tag, action : Action) -> Feature {
  let name = match desc_from_at(tag) {
    Option::None => Option::None
    Option::Some((_, desc)) => Option::Some(desc)
  }
  Feature::{ tag, name, action }
}

///|
/// Returns the feature tag.
pub fn Feature::tag(self : Feature) -> Tag {
  self.tag
}

///|
/// Returns the name of the feature, if available.
pub fn Feature::name(self : Feature) -> String? {
  self.name
}

///|
/// Returns the action of the feature.
pub fn Feature::action(self : Feature) -> Action {
  self.action
}

///|
priv enum WritingSystemKind {
  At(AtWritingSystem)
  Aat(AatWritingSystem)
}

///|
priv struct AatWritingSystem {
  data : Bytes
  morx : UInt
  kern : Bool
}

///|
fn AatWritingSystem::features(self : AatWritingSystem) -> AatFeatures {
  AatFeatures::new(self.data, self.morx, self.kern)
}

///|
/// Script, language and associated typographic features available in a font.
struct WritingSystem {
  kind : WritingSystemKind
  script_tag : Tag
  lang_tag : Tag
  lang : Language?
}

///|
/// Returns the OpenType script tag for the writing system.
pub fn WritingSystem::script_tag(self : WritingSystem) -> Tag {
  self.script_tag
}

///|
/// Returns the OpenType language tag for the writing system.
pub fn WritingSystem::language_tag(self : WritingSystem) -> Tag {
  self.lang_tag
}

///|
/// Returns the script for the writing system.
pub fn WritingSystem::script(self : WritingSystem) -> Script? {
  Script::from_opentype(self.script_tag)
}

///|
/// Returns the language for the writing system.
pub fn WritingSystem::language(self : WritingSystem) -> Language? {
  self.lang
}

///|
/// Returns an iterator over the features provided by the writing system.
pub fn WritingSystem::features(self : WritingSystem) -> Features {
  Features::{
    kind: match self.kind {
      WritingSystemKind::At(ws) => FeaturesKind::At(ws.features())
      WritingSystemKind::Aat(ws) => FeaturesKind::Aat(ws.features())
    },
  }
}

///|
priv enum FeaturesKind {
  Empty
  At(AtFeatures)
  AtAll(AtAllFeatures)
  Aat(AatFeatures)
}

///|
/// Iterator over a collection of typographic features.
struct Features {
  kind : FeaturesKind
}

///|
fn action_for_aat_tag(tag : Tag) -> Action {
  if tag == KERN {
    Adjustment
  } else {
    Substitution
  }
}

///|
fn action_for_stage_tag(stage : Int, tag : Tag) -> Action {
  if stage == 0 {
    Action::Substitution
  } else if tag == MARK || tag == MKMK {
    Action::Attachment
  } else {
    Action::Adjustment
  }
}

///|
pub fn Features::from_font(font : FontRef) -> Features {
  match Kind::from_font(font) {
    Kind::At(gsub, gpos) =>
      Features::{
        kind: FeaturesKind::AtAll(AtAllFeatures::new(font.data(), gsub, gpos)),
      }
    Kind::Aat(morx, kern) =>
      Features::{
        kind: FeaturesKind::Aat(AatFeatures::new(font.data(), morx, kern)),
      }
    Kind::Empty => Features::{ kind: FeaturesKind::Empty }
  }
}

///|
pub fn Features::iter(self : Features) -> Iter[Feature] {
  match self.kind {
    FeaturesKind::Empty => Iter::new(fn() { None })
    FeaturesKind::At(af) => {
      let it = af.iter()
      Iter::new(fn() {
        match it.next() {
          None => None
          Some(f) => {
            let stage = f.stage.to_int()
            let action = action_for_stage_tag(stage, f.tag)
            Some(Feature::from_tag(f.tag, action))
          }
        }
      })
    }
    FeaturesKind::AtAll(af) => {
      let it = af.iter()
      Iter::new(fn() {
        match it.next() {
          None => None
          Some((stage, tag)) => {
            let action = action_for_stage_tag(stage, tag)
            Some(Feature::from_tag(tag, action))
          }
        }
      })
    }
    FeaturesKind::Aat(af) => {
      let it = af.iter()
      Iter::new(fn() {
        match it.next() {
          None => None
          Some((tag, desc)) =>
            Some(Feature::{
              tag,
              name: Option::Some(desc),
              action: action_for_aat_tag(tag),
            })
        }
      })
    }
  }
}

///|
pub fn FontRef::features(self : FontRef) -> Features {
  Features::from_font(self)
}

///|
priv enum WritingSystemsKind {
  Empty
  At(AtWritingSystems)
  Aat(AatWritingSystems)
}

///|
priv struct AatWritingSystems {
  data : Bytes
  morx : UInt
  kern : Bool
}

///|
fn AatWritingSystems::iter(self : AatWritingSystems) -> Iter[AatWritingSystem] {
  let data = self.data
  let morx = self.morx
  let kern = self.kern
  let mut done = false
  Iter::new(fn() {
    if done {
      None
    } else {
      done = true
      Some(AatWritingSystem::{ data, morx, kern })
    }
  })
}

///|
/// Iterator over a collection of writing systems.
struct WritingSystems {
  kind : WritingSystemsKind
}

///|
pub fn WritingSystems::from_font(font : FontRef) -> WritingSystems {
  match Kind::from_font(font) {
    Kind::At(gsub, gpos) => {
      let scripts = AtScripts::new(font.data(), gsub, gpos)
      WritingSystems::{
        kind: WritingSystemsKind::At(AtWritingSystems::new(scripts)),
      }
    }
    Kind::Aat(morx, kern) =>
      WritingSystems::{
        kind: WritingSystemsKind::Aat(AatWritingSystems::{
          data: font.data(),
          morx,
          kern,
        }),
      }
    Kind::Empty => WritingSystems::{ kind: WritingSystemsKind::Empty }
  }
}

///|
pub fn WritingSystems::iter(self : WritingSystems) -> Iter[WritingSystem] {
  match self.kind {
    WritingSystemsKind::Empty => Iter::new(fn() { None })
    WritingSystemsKind::At(ws) => {
      let it = ws.iter()
      Iter::new(fn() {
        match it.next() {
          None => None
          Some(v) => {
            let script_tag = v.script_tag()
            let lang_tag = v.language_tag()
            Some(WritingSystem::{
              kind: WritingSystemKind::At(v),
              script_tag,
              lang_tag,
              lang: Language::from_opentype(lang_tag),
            })
          }
        }
      })
    }
    WritingSystemsKind::Aat(ws) => {
      let it = ws.iter()
      Iter::new(fn() {
        match it.next() {
          None => None
          Some(v) =>
            Some(WritingSystem::{
              kind: WritingSystemKind::Aat(v),
              script_tag: DFLT,
              lang_tag: DFLT,
              lang: Option::None,
            })
        }
      })
    }
  }
}

///|
pub fn FontRef::writing_systems(self : FontRef) -> WritingSystems {
  WritingSystems::from_font(self)
}
