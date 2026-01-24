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
/// PNG helpers (scaffold).
///
/// Upstream swash decodes embedded PNG glyph bitmaps and relies on `yazi` for
/// zlib inflation of IDAT chunks. We keep a minimal shared building block here
/// so the rest of the bitmap pipeline can be ported incrementally.

///|
/// Returns true if the data begins with the PNG signature.
pub fn is_png(data : Bytes) -> Bool {
  data.length() >= 8 &&
  data.get(0) == Some(b'\x89') &&
  data.get(1) == Some(b'P') &&
  data.get(2) == Some(b'N') &&
  data.get(3) == Some(b'G') &&
  data.get(4) == Some(b'\r') &&
  data.get(5) == Some(b'\n') &&
  data.get(6) == Some(b'\x1A') &&
  data.get(7) == Some(b'\n')
}

///|
/// Inflates a zlib stream.
///
/// In PNG this is used for concatenated IDAT data.
pub fn inflate_zlib(data : Bytes) -> Array[Byte] raise @yazi.YaziError {
  let (out, _) = @yazi.decompress(data, @yazi.Format::Zlib)
  out
}
