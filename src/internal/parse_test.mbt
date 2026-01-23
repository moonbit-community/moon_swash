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
test "BeBytes.read_u16/read_u32 big-endian" {
  let bytes = b"\x01\x02\x03\x04\x05"
  let reader = BeBytes::new(bytes)
  inspect(reader.read_u16(0), content="Some(258)")
  inspect(reader.read_u16(1), content="Some(515)")
  inspect(reader.read_u32(0), content="Some(16909060)")
  inspect(reader.read_u32(1), content="Some(33752069)")
  inspect(reader.read_u32(2), content="None")
}

///|
test "Stream.read_u* advances offset" {
  let bytes = b"\x00\x01\x00\x02\x00\x00\x00\x03"
  let stream_opt = Stream::with_offset(bytes, 0)
  if stream_opt is Some(stream) {
    inspect(stream.offset(), content="0")
    inspect(stream.read_u16(), content="Some(1)")
    inspect(stream.offset(), content="2")
    inspect(stream.read_u16(), content="Some(2)")
    inspect(stream.offset(), content="4")
    inspect(stream.read_u32(), content="Some(3)")
    inspect(stream.offset(), content="8")
    inspect(stream.read_u8(), content="None")
  } else {
    fail("expected Some(stream)")
  }
}
