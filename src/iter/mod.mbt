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
/// Iterator names for API parity with upstream swash.
///
/// Note: some upstream swash iterator types are represented as `Iter[T]` in
/// MoonBit. We still re-export the stable names here to keep downstream import
/// paths consistent.
pub type Features = @swash.Features

///|
pub type WritingSystems = @swash.WritingSystems

///|
pub type Fonts = Iter[@swash.FontRef]

///|
pub type ColorPalettes = @swash.ColorPalettes

///|
pub type BitmapStrikes = @swash.BitmapStrikes

///|
pub type Chars = Iter[Char]

///|
pub type LocalizedStrings = @swash.LocalizedStrings

///|
pub type Instances = @swash.Instances

///|
pub type Variations = @swash.Variations
