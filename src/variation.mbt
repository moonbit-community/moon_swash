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
/// Implementation note: we currently leverage `moon_skrifa`'s `AxisCollection`
/// / `NamedInstanceCollection` to compute normalized coordinates (including
/// AVAR remapping). Name resolution will be wired once `string.mbt` is ported.
fn find_font_index_by_offset(data : Bytes, offset : Int) -> UInt? {
  match FontDataRef::new(data) {
    None => None
    Some(fdr) => {
      let mut i = 0
      for f in fdr.fonts() {
        if f.offset() == offset {
          return Some(i.reinterpret_as_uint())
        }
        i = i + 1
      }
      None
    }
  }
}

///|
fn to_skrifa_font(font : FontRef) -> @skrifa.FontRef? {
  if font.offset() == 0 {
    @skrifa.FontRef::new(font.data())
  } else {
    match find_font_index_by_offset(font.data(), font.offset()) {
      None => None
      Some(index) => @skrifa.FontRef::from_index(font.data(), index)
    }
  }
}

///|
struct Variation {
  axes : Ref[@skrifa.AxisCollection]
  axis : @skrifa.Axis
}

///|
pub fn Variation::index(self : Variation) -> Int {
  self.axis.index()
}

///|
pub fn Variation::tag(self : Variation) -> Tag {
  self.axis.tag().to_uint()
}

///|
pub fn Variation::is_hidden(self : Variation) -> Bool {
  self.axis.is_hidden()
}

///|
pub fn Variation::min_value(self : Variation) -> Double {
  self.axis.min_value()
}

///|
pub fn Variation::max_value(self : Variation) -> Double {
  self.axis.max_value()
}

///|
pub fn Variation::default_value(self : Variation) -> Double {
  self.axis.default_value()
}

///|
pub fn Variation::normalize(
  self : Variation,
  value : Double,
) -> NormalizedCoord {
  let axes = self.axes.val
  let settings : Array[@skrifa.VariationSetting] = [
    @skrifa.Setting::new(self.axis.tag(), value),
  ]
  let loc = axes.location(settings.op_as_view())
  loc.coords().get(self.axis.index()).unwrap_or(0)
}

///|
struct Instance {
  index : Int
  inner : @skrifa.NamedInstance
}

///|
pub fn Instance::index(self : Instance) -> Int {
  self.index
}

///|
pub fn Instance::values(self : Instance) -> ArrayView[Double] {
  self.inner.user_coords()
}

///|
pub fn Instance::normalized_coords(
  self : Instance,
) -> ArrayView[NormalizedCoord] {
  self.inner.location().coords()
}

///|
pub fn FontRef::variations(self : FontRef) -> Iter[Variation] {
  match to_skrifa_font(self) {
    None => Iter::new(fn() { None })
    Some(f) => {
      let axes = @skrifa.AxisCollection::new(f)
      let axes_ref = Ref::new(axes)
      let mut pos = 0
      let len = axes_ref.val.len()
      Iter::new(fn() {
        if pos >= len {
          return None
        }
        let i = pos
        pos = pos + 1
        match axes_ref.val.get(i) {
          None => None
          Some(axis) => Some(Variation::{ axes: axes_ref, axis })
        }
      })
    }
  }
}

///|
pub fn FontRef::instances(self : FontRef) -> Iter[Instance] {
  match to_skrifa_font(self) {
    None => Iter::new(fn() { None })
    Some(f) => {
      let coll = @skrifa.NamedInstanceCollection::new(f)
      let coll_ref = Ref::new(coll)
      let mut pos = 0
      let len = coll_ref.val.len()
      Iter::new(fn() {
        if pos >= len {
          return None
        }
        let i = pos
        pos = pos + 1
        match coll_ref.val.get(i) {
          None => None
          Some(inner) => Some(Instance::{ index: i, inner })
        }
      })
    }
  }
}

///|
test "Variation normalize on non-variable font yields empty iterator" {
  let data = Bytes::from_array([0, 1, 0, 0])
  let font = FontRef::from_offset(data, 0).unwrap()
  inspect(font.variations().next() is None, content="true")
  inspect(font.instances().next() is None, content="true")
}
