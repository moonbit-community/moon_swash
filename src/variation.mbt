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
/// Variations and named instances (variable fonts).
///
/// Port intent: mirror the surface of `swash/src/variation.rs`.
///
/// Implementation note: this is backed by internal `fvar/avar` parsing and
/// mirrors the Rust reference implementation (including AVAR remapping).

///|
struct VariationsProxy {
  fvar : UInt
  avar : UInt
  len : Int
}

///|
pub fn VariationsProxy::from_font(font : FontRef) -> VariationsProxy {
  let fvar = font.table_offset(@internal.FVAR)
  let table = match @internal.Fvar::from_font(font) {
    None => @internal.Fvar::new(b""[:])
    Some(v) => v
  }
  let avar = font.table_offset(@internal.AVAR)
  let len = table.axis_count().reinterpret_as_int()
  VariationsProxy::{ fvar, avar, len }
}

///|
pub fn VariationsProxy::materialize(
  self : VariationsProxy,
  font : FontRef,
) -> Variations {
  let data = font.data()
  let view = if self.fvar != 0 {
    let off = self.fvar.reinterpret_as_int()
    if off >= 0 && off <= data.length() {
      data[off:]
    } else {
      b""[:]
    }
  } else {
    b""[:]
  }
  Variations::{
    font,
    fvar: @internal.Fvar::new(view),
    avar: self.avar,
    len: self.len,
    pos: 0,
  }
}

///|
struct Variations {
  font : FontRef
  fvar : @internal.Fvar
  avar : UInt
  len : Int
  mut pos : Int
}

///|
fn Variations::from_font(font : FontRef) -> Variations {
  let fvar = match @internal.Fvar::from_font(font) {
    None => @internal.Fvar::new(b""[:])
    Some(v) => v
  }
  let avar = font.table_offset(@internal.AVAR)
  let len = fvar.axis_count().reinterpret_as_int()
  Variations::{ font, fvar, avar, len, pos: 0 }
}

///|
fn Variations::get(self : Variations, index : Int) -> Variation? {
  if index < 0 || index >= self.len {
    return None
  }
  match self.fvar.get_axis(index.reinterpret_as_uint()) {
    None => None
    Some(axis) => Some(Variation::{ font: self.font, axis, avar: self.avar })
  }
}

///|
pub fn Variations::find_by_tag(self : Variations, tag : Tag) -> Variation? {
  for i in 0..<self.len {
    if self.get(i) is Some(v) && v.tag() == tag {
      return Some(v)
    }
  }
  None
}

///|
pub fn Variations::normalized_coords(
  self : Variations,
  settings : Iter[VariationSetting],
) -> Iter[NormalizedCoord] {
  let len0 = if self.len > 32 { 32 } else { self.len }
  let coords : Array[NormalizedCoord] = Array::makei(len0, _ => 0)
  for setting in settings {
    for i in 0..<len0 {
      let axis_opt = self.fvar.get_axis(i.reinterpret_as_uint())
      if axis_opt is Some(axis) && axis.tag == setting.tag {
        let avar = if self.avar != 0 {
          Some((self.font.data(), self.avar))
        } else {
          None
        }
        coords[i] = axis.normalized_coord(
          @internal.Fixed::from_f32(setting.value),
          avar,
        )
      }
    }
  }
  let mut pos = 0
  Iter::new(fn() {
    if pos >= len0 {
      return None
    }
    let i = pos
    pos = pos + 1
    Some(coords[i])
  })
}

///|
pub fn Variations::next(self : Variations) -> Variation? {
  if self.pos >= self.len {
    return None
  }
  let i = self.pos
  self.pos = self.pos + 1
  self.get(i)
}

///|
pub fn Variations::iter(self : Variations) -> Iter[Variation] {
  let it = self
  Iter::new(fn() { it.next() })
}

///|
struct Variation {
  font : FontRef
  axis : @internal.VarAxis
  avar : UInt
}

///|
pub fn Variation::index(self : Variation) -> Int {
  self.axis.index.reinterpret_as_int()
}

///|
pub fn Variation::tag(self : Variation) -> Tag {
  self.axis.tag
}

///|
pub fn Variation::name_id(self : Variation) -> StringId {
  StringId::Other(self.axis.name_id.to_uint16())
}

///|
pub fn Variation::name(
  self : Variation,
  language : String?,
) -> LocalizedString? {
  self.font.localized_strings().find_by_id(self.name_id(), language)
}

///|
pub fn Variation::is_hidden(self : Variation) -> Bool {
  self.axis.is_hidden()
}

///|
pub fn Variation::min_value(self : Variation) -> Double {
  self.axis.min.to_f32()
}

///|
pub fn Variation::max_value(self : Variation) -> Double {
  self.axis.max.to_f32()
}

///|
pub fn Variation::default_value(self : Variation) -> Double {
  self.axis.default.to_f32()
}

///|
pub fn Variation::normalize(
  self : Variation,
  value : Double,
) -> NormalizedCoord {
  let avar = if self.avar != 0 {
    Some((self.font.data(), self.avar))
  } else {
    None
  }
  self.axis.normalized_coord(@internal.Fixed::from_f32(value), avar)
}

///|
struct Instances {
  font : FontRef
  fvar : @internal.Fvar
  avar : UInt
  len : Int
  mut pos : Int
}

///|
fn Instances::from_font(font : FontRef) -> Instances {
  let fvar = match @internal.Fvar::from_font(font) {
    None => @internal.Fvar::new(b""[:])
    Some(v) => v
  }
  let avar = font.table_offset(@internal.AVAR)
  let len = fvar.instance_count().reinterpret_as_int()
  Instances::{ font, fvar, avar, len, pos: 0 }
}

///|
fn Instances::get(self : Instances, index : Int) -> Instance? {
  if index < 0 || index >= self.len {
    return None
  }
  match self.fvar.get_instance(index.reinterpret_as_uint()) {
    None => None
    Some(inner) => {
      let values : Array[Double] = []
      for v in inner.values.iter() {
        values.push(v.to_f32())
      }
      let avar = if self.avar != 0 {
        Some((self.font.data(), self.avar))
      } else {
        None
      }
      let axis_count = self.fvar.axis_count().reinterpret_as_int()
      let coords : Array[NormalizedCoord] = []
      for i in 0..<axis_count {
        let axis = self.fvar
          .get_axis(i.reinterpret_as_uint())
          .unwrap_or(@internal.VarAxis::default())
        let value = if i < inner.values.length() {
          inner.values[i]
        } else {
          @internal.Fixed::zero()
        }
        coords.push(axis.normalized_coord(value, avar))
      }
      Some(Instance::{ parent: self, inner, values, coords })
    }
  }
}

///|
pub fn Instances::find_by_name(self : Instances, name : String) -> Instance? {
  let strings = self.font.localized_strings()
  for i in 0..<self.len {
    if self.get(i) is Some(instance) {
      let id = instance.name_id()
      for s in strings.iter() {
        if s.id().to_raw() == id.to_raw() && s.to_string() == name {
          return Some(instance)
        }
      }
    }
  }
  None
}

///|
pub fn Instances::find_by_postscript_name(
  self : Instances,
  name : String,
) -> Instance? {
  let strings = self.font.localized_strings()
  for i in 0..<self.len {
    if self.get(i) is Some(instance) {
      if instance.postscript_name_id() is Some(id) {
        for s in strings.iter() {
          if s.id().to_raw() == id.to_raw() && s.to_string() == name {
            return Some(instance)
          }
        }
      }
    }
  }
  None
}

///|
pub fn Instances::next(self : Instances) -> Instance? {
  if self.pos >= self.len {
    return None
  }
  let i = self.pos
  self.pos = self.pos + 1
  self.get(i)
}

///|
pub fn Instances::iter(self : Instances) -> Iter[Instance] {
  let it = self
  Iter::new(fn() { it.next() })
}

///|
struct Instance {
  parent : Instances
  inner : @internal.VarInstance
  values : Array[Double]
  coords : Array[NormalizedCoord]
}

///|
pub fn Instance::index(self : Instance) -> Int {
  self.inner.index.reinterpret_as_int()
}

///|
pub fn Instance::name_id(self : Instance) -> StringId {
  StringId::Other(self.inner.name_id.to_uint16())
}

///|
pub fn Instance::name(self : Instance, language : String?) -> LocalizedString? {
  self.parent.font.localized_strings().find_by_id(self.name_id(), language)
}

///|
pub fn Instance::postscript_name_id(self : Instance) -> StringId? {
  match self.inner.postscript_name_id {
    None => None
    Some(id) => Some(StringId::Other(id.to_uint16()))
  }
}

///|
pub fn Instance::postscript_name(
  self : Instance,
  language : String?,
) -> LocalizedString? {
  match self.postscript_name_id() {
    None => None
    Some(id) => self.parent.font.localized_strings().find_by_id(id, language)
  }
}

///|
pub fn Instance::values(self : Instance) -> ArrayView[Double] {
  self.values.op_as_view()
}

///|
pub fn Instance::normalized_coords(
  self : Instance,
) -> ArrayView[NormalizedCoord] {
  self.coords.op_as_view()
}

///|
pub fn FontRef::variations(self : FontRef) -> Variations {
  Variations::from_font(self)
}

///|
pub fn FontRef::instances(self : FontRef) -> Instances {
  Instances::from_font(self)
}

///|
test "Variation normalize on non-variable font yields empty iterator" {
  let data = Bytes::from_array([0, 1, 0, 0])
  let font = FontRef::from_offset(data, 0).unwrap()
  inspect(font.variations().iter().next() is None, content="true")
  inspect(font.instances().iter().next() is None, content="true")
}
