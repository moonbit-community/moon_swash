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
fn tokens_from_string(s : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let mut offset = 0U
  for ch in s {
    tokens.push(Token::new(ch, offset, 1U, CharInfo::from_char(ch), 0U))
    offset = offset + 1U
  }
  tokens
}

///|
test "text cluster: CRLF clusters as newline" {
  let tokens = tokens_from_string("\r\n")
  let parser = Parser::new(Script::Latin, tokens.iter())
  let cluster = CharCluster::new()
  inspect(parser.next(cluster), content="true")
  inspect(cluster.chars().length(), content="2")
  inspect(
    match cluster.info().whitespace() {
      Whitespace::Newline => true
      _ => false
    },
    content="true",
  )
  inspect(
    match cluster.chars()[0].shape_class() {
      ShapeClass::Control => true
      _ => false
    },
    content="true",
  )
  inspect(
    match cluster.chars()[1].shape_class() {
      ShapeClass::Control => true
      _ => false
    },
    content="true",
  )
  inspect(cluster.range().start(), content="0")
  inspect(cluster.range().end(), content="2")
  inspect(parser.next(cluster), content="false")
}

///|
test "text cluster: emoji VS16 excluded from shaping chars but included in range" {
  // U+263A WHITE SMILING FACE + U+FE0F VARIATION SELECTOR-16
  let tokens = tokens_from_string("\u{263A}\u{FE0F}")
  let parser = Parser::new(Script::Latin, tokens.iter())
  let cluster = CharCluster::new()
  inspect(parser.next(cluster), content="true")
  inspect(cluster.chars().length(), content="1")
  inspect(cluster.range().start(), content="0")
  inspect(cluster.range().end(), content="2")
  inspect(
    match cluster.info().emoji() {
      Emoji::Color => true
      _ => false
    },
    content="true",
  )
  inspect(parser.next(cluster), content="false")
}

///|
test "text cluster: force-normalize prefers composed mapping" {
  let tokens = tokens_from_string("A\u{030A}")
  let parser = Parser::new(Script::Latin, tokens.iter())
  let cluster = CharCluster::new()
  inspect(parser.next(cluster), content="true")
  inspect(
    match
      cluster.map(fn(ch) {
        if ch == 'Å' {
          (1).to_uint16()
        } else {
          (0).to_uint16()
        }
      }) {
      Status::Complete => true
      _ => false
    },
    content="true",
  )
  inspect(cluster.mapped_chars().length(), content="1")
  inspect(cluster.mapped_chars()[0].ch(), content="Å")
}

///|
test "text cluster: Myanmar kinzi prefix is classified" {
  // 1004 + 103A + 1039 + 1000
  let tokens = tokens_from_string("\u{1004}\u{103A}\u{1039}\u{1000}")
  let parser = Parser::new(Script::Myanmar, tokens.iter())
  let cluster = CharCluster::new()
  inspect(parser.next(cluster), content="true")
  inspect(cluster.chars().length(), content="4")
  for i in 0..<3 {
    inspect(
      match cluster.chars()[i].shape_class() {
        ShapeClass::Kinzi => true
        _ => false
      },
      content="true",
    )
  }
  inspect(
    match cluster.chars()[3].shape_class() {
      ShapeClass::Base => true
      _ => false
    },
    content="true",
  )
}
