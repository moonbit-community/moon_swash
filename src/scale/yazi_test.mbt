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
/// Sanity checks for `Milky2018/moon_yazi`.
///
/// Upstream swash uses `yazi` for zlib decompression when decoding embedded PNG
/// glyph bitmaps. We don't have the full PNG pipeline ported yet, but we
/// validate that zlib roundtrips work so scale/bitmap code can build on this.
test "moon_yazi zlib roundtrip" {
  let payload = Bytes::from_array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  let compressed = try! @yazi.compress(
    payload,
    @yazi.Format::Zlib,
    @yazi.CompressionLevel::Default,
  )
  let (decompressed, _) = try! @yazi.decompress(
    Bytes::from_array(compressed),
    @yazi.Format::Zlib,
  )
  inspect(decompressed.length(), content="10")
  inspect(decompressed[0].to_int(), content="1")
  inspect(decompressed[9].to_int(), content="10")
}
