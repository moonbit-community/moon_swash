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
test "Char::properties provides basic Unicode properties" {
  let p = Codepoint::properties('A')
  inspect(
    match p.script() {
      Latin => true
      _ => false
    },
    content="true",
  )
  inspect(
    match p.category() {
      UppercaseLetter => true
      _ => false
    },
    content="true",
  )
}

///|
test "compose_pair + decompose roundtrip for Å (U+00C5)" {
  let d = decompose('Å').to_array()
  inspect(d.length(), content="2")
  inspect(String::from_array(d.op_as_view()), content="A\u{030A}")
  inspect(compose_pair('A', d[1]).unwrap(), content="Å")
}

///|
test "Char::opening_bracket / mirror for parenthesis" {
  inspect(Codepoint::opening_bracket(')').unwrap(), content="(")
  inspect(Codepoint::closing_bracket('(').unwrap(), content=")")
  inspect(Codepoint::mirror('(').unwrap(), content=")")
}
