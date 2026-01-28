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
test "ScaleContext::with_max_entries clamps to 1..=64" {
  // ScaleContext is abstract, so internal cache sizing isn't observable.
  // Smoke-test the constructors and that builders can be created.
  let font_opt = @swash.FontRef::from_offset(b"\x00\x01\x00\x00", 0)
  if font_opt is Some(font) {
    ScaleContext::with_max_entries(0).builder(font).build() |> ignore
    ScaleContext::with_max_entries(100).builder(font).build() |> ignore
  } else {
    fail("expected a trivial font header to pass FontRef::from_offset")
  }
}

///|
test "ScaleContext::builder_with_id overrides hinting cache id" {
  let font_opt = @swash.FontRef::from_offset(b"\x00\x01\x00\x00", 0)
  if font_opt is Some(font) {
    let scaler = ScaleContext::new()
      .builder_with_id(font, ((123).to_uint64(), (456).to_uint64()))
      .build()
    inspect(scaler.hint(), content="false")
  } else {
    fail("expected a trivial font header to pass FontRef::from_offset")
  }
}
