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
test "analyze marks word boundary at start" {
  let chars : ReadOnlyArray[Char] = ['a']
  let a = analyze(chars.iter())
  let (_, boundary) = a.next().unwrap()
  inspect(
    match boundary {
      Boundary::Word => true
      _ => false
    },
    content="true",
  )
}

///|
test "analyze tracks bidi resolution need" {
  let chars : ReadOnlyArray[Char] = ['\u{0627}']
  let a = analyze(chars.iter())
  a.next().unwrap() |> ignore
  inspect(a.needs_bidi_resolution(), content="true")
}

///|
test "analyze: ZWJ x emoji has no word boundary" {
  let chars : ReadOnlyArray[Char] = ['\u{200D}', '\u{1F600}']
  let a = analyze(chars.iter())
  a.next().unwrap() |> ignore
  let (_, boundary) = a.next().unwrap()
  inspect(
    match boundary {
      Boundary::Word => false
      _ => true
    },
    content="true",
  )
}
