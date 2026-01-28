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
struct TestSelector {
  font_a : @swash.FontRef
  font_b : @swash.FontRef
}

///|
pub impl Selector for TestSelector with select_font(self, cluster) {
  let chars = cluster.chars()
  guard chars.length() != 0 else { None }
  let ch0 = chars[0].ch()
  if ch0 >= 'A' && ch0 <= 'Z' {
    Some(
      SelectedFont::new(self.font_b).with_id_override(
        ((3).to_uint64(), (4).to_uint64()),
      ),
    )
  } else {
    Some(
      SelectedFont::new(self.font_a).with_id_override(
        ((1).to_uint64(), (2).to_uint64()),
      ),
    )
  }
}

///|
test "shape.partition selects and partitions fonts by cluster" {
  let data = Bytes::makei(4, i => if i == 1 { b'\x01' } else { b'\x00' })
  let font_a = @swash.FontRef::from_offset(data, 0).unwrap()
  let font_b = @swash.FontRef::from_offset(data, 0).unwrap()
  let selector = TestSelector::{ font_a, font_b }
  let opts = SimpleShapeOptions::default()
  let tokens : Array[@swash.Token] = [
    @swash.Token::new('a', 0U, 1U, @swash.CharInfo::default(), 0U),
    @swash.Token::new('B', 1U, 1U, @swash.CharInfo::default(), 0U),
    @swash.Token::new('c', 2U, 1U, @swash.CharInfo::default(), 0U),
  ]
  let ids : Array[UInt64] = []
  let cx = ShapeContext::new()
  shape(cx, selector, opts, tokens.iter(), (font, _shaper) => ids.push(
    font.id_override().unwrap().0,
  ))
  inspect(ids.length(), content="3")
  inspect(ids[0], content="1")
  inspect(ids[1], content="3")
  inspect(ids[2], content="1")
}
