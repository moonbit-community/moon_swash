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
fn tokens_from_string(s : String) -> Array[@swash.Token] {
  let tokens : Array[@swash.Token] = []
  let mut offset = 0U
  for ch in s {
    tokens.push(
      @swash.Token::new(ch, offset, 1U, @swash.CharInfo::from_char(ch), 0U),
    )
    offset = offset + 1U
  }
  tokens
}

///|
test "shape buffer: push cluster records range and glyphs" {
  let tokens = tokens_from_string("ab")
  let parser = @swash.Parser::new(@swash.Script::Latin, tokens.iter())
  let cluster = @swash.CharCluster::new()
  let buf = Buffer::new()
  inspect(parser.next(cluster), content="true")
  cluster.map(fn(_ch) { (1).to_uint16() }) |> ignore
  let r = buf.push(cluster)
  inspect(r.start(), content="0")
  inspect(r.end(), content="1")
  inspect(buf.len(), content="1")
  inspect(buf.glyphs()[0].id(), content="1")
  inspect(buf.ranges().length(), content="1")
  inspect(parser.next(cluster), content="true")
  cluster.map(fn(_ch) { (1).to_uint16() }) |> ignore
  let r2 = buf.push(cluster)
  inspect(r2.start(), content="1")
  inspect(r2.end(), content="2")
  inspect(buf.len(), content="2")
  inspect(buf.glyphs()[1].id(), content="1")
  inspect(buf.ranges().length(), content="2")
}
