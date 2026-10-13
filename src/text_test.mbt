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
test "Language parse basic tags" {
  let en = @moon_swash.Language::parse("en").unwrap()
  inspect(en.language(), content="en")
  inspect(en.script() is None, content="true")
  inspect(en.region() is None, content="true")
  let zh = @moon_swash.Language::parse("zh-Hans").unwrap()
  inspect(zh.language(), content="zh")
  inspect(zh.script().unwrap(), content="Hans")
  let zhs = @moon_swash.tag_from_str_lossy("ZHS ")
  inspect(zh.to_opentype().unwrap().to_string(), content=zhs.to_string())
  let ja = @moon_swash.Language::parse("ja").unwrap()
  inspect(
    match ja.cjk() {
      Japanese => true
      _ => false
    },
    content="true",
  )
}

///|
test "Language from_opentype handles ZHT/ZHS" {
  let zht = @moon_swash.tag_from_str_lossy("ZHT ")
  let zhs = @moon_swash.tag_from_str_lossy("ZHS ")
  let zht0 = @moon_swash.Language::from_opentype(zht).unwrap()
  inspect(zht0.script().unwrap(), content="Hant")
  let zhs0 = @moon_swash.Language::from_opentype(zhs).unwrap()
  inspect(zhs0.script().unwrap(), content="Hans")
}

///|
test "Script from_opentype maps common scripts" {
  let latn = @moon_swash.tag_from_str_lossy("latn")
  let s0 = @moon_swash.Script::from_opentype(latn).unwrap()
  inspect(
    match s0 {
      Latin => true
      _ => false
    },
    content="true",
  )
  inspect(s0.to_opentype().to_string(), content=latn.to_string())
}
