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
/// Per-font scaling proxy cached by `ScaleContext`.
///
/// Ported from `swash-reference/src/scale/proxy.rs`.
let scaler_proxy_counter : Ref[UInt64] = Ref::new((0).to_uint64())

///|
fn next_scaler_proxy_uid() -> UInt64 {
  let v = scaler_proxy_counter.val + 1
  scaler_proxy_counter.val = v
  v
}

///|
struct ScalerProxy {
  metrics : @swash.MetricsProxy
  color : ColorProxy
  bitmaps : @swash.BitmapStrikesProxy
  coord_count : UInt16
  // Internal creation id to make cache behavior observable in unit tests.
  uid : UInt64
}

///|
pub fn ScalerProxy::from_font(font : @swash.FontRef) -> ScalerProxy {
  let n = font.variations().len()
  let coord_count = if n <= 0 {
    (0).to_uint16()
  } else if n >= 0x10000 {
    (0xFFFF).to_uint16()
  } else {
    n.to_uint16()
  }
  ScalerProxy::{
    metrics: @swash.MetricsProxy::from_font(font),
    color: ColorProxy::from_font(font),
    bitmaps: @swash.BitmapStrikesProxy::from_font(font),
    coord_count,
    uid: next_scaler_proxy_uid(),
  }
}
