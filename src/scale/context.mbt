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
/// Scaling context and scaler scaffolding.
///
/// Port intent: align with upstream `swash::scale::ScaleContext/ScalerBuilder/Scaler`.
/// This is currently a functional skeleton: it provides the public API shape,
/// but does not yet implement actual outline extraction, hinting, or rasterization.

///|
struct ScaleContext {
  fonts : Ref[@swash.FontCache[ScalerProxy]]
  state : Ref[State]
  hinting_cache : Ref[HintingCache]
}

///|

///|
priv struct State {
  mut _scratch0 : Array[Byte]
  mut _scratch1 : Array[Byte]
  outline : Outline
  rcx : Ref[@zeno.Scratch]
}

///|

///|
fn State::State() -> State {
  State::{
    _scratch0: [],
    _scratch1: [],
    outline: Outline::Outline(),
    rcx: Ref(@zeno.Scratch::Scratch()),
  }
}

///|
pub fn ScaleContext::ScaleContext() -> ScaleContext {
  ScaleContext::with_max_entries(8)
}

///|
/// Creates a new scaling context with the specified maximum number of cache entries.
///
/// This mirrors the upstream API. The value is clamped to 1..=64.
pub fn ScaleContext::with_max_entries(max_entries : Int) -> ScaleContext {
  let max_entries = if max_entries < 1 {
    1
  } else if max_entries > 64 {
    64
  } else {
    max_entries
  }
  ScaleContext::{
    fonts: Ref(@swash.FontCache::FontCache(max_entries)),
    state: Ref(State::State()),
    hinting_cache: Ref(HintingCache::HintingCache()),
  }
}

///|
pub fn ScaleContext::builder(
  self : ScaleContext,
  font : @swash.FontRef,
) -> ScalerBuilder {
  let (id, proxy) = self.fonts.val.get(font, None, ScalerProxy::from_font)
  ScalerBuilder::{
    state: self.state,
    hinting_cache: self.hinting_cache,
    font,
    proxy,
    id0: id.0,
    id1: id.1,
    coords: [],
    size: 0.0,
    hint: false,
  }
}

///|
/// Creates a builder for constructing a scaler with this context, specified font and a
/// custom unique identifier.
pub fn ScaleContext::builder_with_id(
  self : ScaleContext,
  font : @swash.FontRef,
  id : (UInt64, UInt64),
) -> ScalerBuilder {
  let (id2, proxy) = self.fonts.val.get(font, Some(id), ScalerProxy::from_font)
  ScalerBuilder::{
    state: self.state,
    hinting_cache: self.hinting_cache,
    font,
    proxy,
    id0: id2.0,
    id1: id2.1,
    coords: [],
    size: 0.0,
    hint: false,
  }
}

///|
/// Builder for configuring a scaler.
struct ScalerBuilder {
  state : Ref[State]
  hinting_cache : Ref[HintingCache]
  font : @swash.FontRef
  proxy : Ref[ScalerProxy]
  id0 : UInt64
  id1 : UInt64
  coords : Array[Int]
  size : Double
  hint : Bool
}

///|
pub fn ScalerBuilder::size(
  self : ScalerBuilder,
  ppem : Double,
) -> ScalerBuilder {
  ScalerBuilder::{
    state: self.state,
    hinting_cache: self.hinting_cache,
    font: self.font,
    proxy: self.proxy,
    id0: self.id0,
    id1: self.id1,
    coords: self.coords,
    size: if ppem < 0.0 {
      0.0
    } else {
      ppem
    },
    hint: self.hint,
  }
}

///|
pub fn ScalerBuilder::hint(self : ScalerBuilder, yes : Bool) -> ScalerBuilder {
  ScalerBuilder::{
    state: self.state,
    hinting_cache: self.hinting_cache,
    font: self.font,
    proxy: self.proxy,
    id0: self.id0,
    id1: self.id1,
    coords: self.coords,
    size: self.size,
    hint: yes,
  }
}

///|
pub fn ScalerBuilder::variations(
  self : ScalerBuilder,
  settings : ArrayView[@swash.VariationSetting],
) -> ScalerBuilder {
  if self.proxy.val.coord_count == 0 {
    return self
  }
  let vars = self.font.variations().iter().to_array()
  if vars.is_empty() {
    return self
  }
  let n = vars.length()
  if self.coords.length() < n {
    for _ in self.coords.length()..<n {
      self.coords.push(0)
    }
  } else if self.coords.length() > n {
    self.coords.truncate(n)
  }
  for s in settings.iter() {
    for v in vars.iter() {
      if v.tag() == s.tag {
        let value = v.normalize(s.value)
        let ix = v.index()
        if ix >= 0 && ix < self.coords.length() {
          self.coords.set(ix, value)
        }
      }
    }
  }
  self
}

///|
pub fn ScalerBuilder::normalized_coords(
  self : ScalerBuilder,
  coords : ArrayView[Int],
) -> ScalerBuilder {
  self.coords.clear()
  for c in coords.iter() {
    self.coords.push(c)
  }
  self
}

///|
pub fn ScalerBuilder::build(self : ScalerBuilder) -> Scaler {
  let upem = self.proxy.val.metrics.units_per_em().to_int()
  let skrifa_size = if self.size != 0.0 && upem != 0 {
    @skrifa.Size::Size(self.size)
  } else {
    @skrifa.Size::unscaled()
  }
  let loc = if self.coords.is_empty() {
    @skrifa.LocationRef::default()
  } else {
    @skrifa.LocationRef::LocationRef(self.coords.op_as_view())
  }
  let skrifa_font = to_skrifa_font(self.font)
  let outlines = match skrifa_font {
    None => None
    Some(f) => Some(@skrifa_outline.OutlineGlyphCollection::from_font(f))
  }
  let outlines0 = outlines
  let hinting_instance = if self.hint && outlines is Some(oc) {
    self.hinting_cache.val.get(self.id0, self.id1, oc, skrifa_size, loc)
  } else {
    None
  }
  Scaler::{
    state: self.state,
    _hinting_cache: self.hinting_cache,
    font: self.font,
    outlines: outlines0,
    hinting_instance,
    proxy: self.proxy,
    coords: self.coords,
    size: self.size,
    skrifa_size,
    hint: self.hint,
  }
}

///|
struct Scaler {
  state : Ref[State]
  _hinting_cache : Ref[HintingCache]
  font : @swash.FontRef
  outlines : @skrifa_outline.OutlineGlyphCollection?
  hinting_instance : @skrifa_outline.HintingInstance?
  proxy : Ref[ScalerProxy]
  coords : Array[Int]
  size : Double
  skrifa_size : @skrifa.Size
  hint : Bool
}

///|
pub fn Scaler::size(self : Scaler) -> Double {
  self.size
}

///|
pub fn Scaler::hint(self : Scaler) -> Bool {
  self.hint
}

///|
test "ScaleContext caches ScalerProxy per font id (LRU eviction)" {
  let data = b"\x00\x01\x00\x00"
  let f0 = @swash.FontRef::from_offset(data, 0).unwrap()
  let f1 = @swash.FontRef::from_offset(data, 0).unwrap()
  let ctx = ScaleContext::with_max_entries(1)
  let s0 = ctx.builder(f0).build()
  let uid0 = s0.proxy.val.uid
  let s0_again = ctx.builder(f0).build()
  inspect(s0_again.proxy.val.uid == uid0, content="true")

  // Insert a different font id (different CacheKey), which should evict f0
  // because max_entries=1.
  let s1 = ctx.builder(f1).build()
  inspect(s1.proxy.val.uid != uid0, content="true")

  // f0 was evicted, so a new proxy should be constructed.
  let s0_new = ctx.builder(f0).build()
  inspect(s0_new.proxy.val.uid != uid0, content="true")
}

///|
pub fn Scaler::scale_outline_into(
  self : Scaler,
  glyph_id : @swash.GlyphId,
  outline : Outline,
) -> Bool {
  outline.clear()
  self.scale_outline_layer_into(glyph_id, None, outline)
}

///|
pub fn Scaler::scale_color_outline_into(
  self : Scaler,
  glyph_id : @swash.GlyphId,
  outline : Outline,
) -> Bool {
  outline.clear()
  if !self.has_color_outlines() {
    return false
  }
  let layers_opt = self.proxy.val.color.layers(self.font.data(), glyph_id)
  match layers_opt {
    None => false
    Some(layers) => {
      let len = layers.len().to_int()
      for i in 0..<len {
        let layer = match layers.get(i.to_uint16()) {
          None => return false
          Some(v) => v
        }
        if !self.scale_outline_layer_into(
            layer.glyph_id(),
            layer.color_index(),
            outline,
          ) {
          return false
        }
      }
      outline.set_color(true)
      true
    }
  }
}

///|
fn find_font_index_by_offset(data : Bytes, offset : Int) -> UInt? {
  match @swash.FontDataRef::from_data(data) {
    None => None
    Some(fdr) => {
      let mut i = 0
      for f in fdr.fonts() {
        if f.offset() == offset {
          return Some(i.reinterpret_as_uint())
        }
        i = i + 1
      }
      None
    }
  }
}

///|
fn to_skrifa_font(font : @swash.FontRef) -> @skrifa.FontRef? {
  if font.offset() == 0 {
    @skrifa.FontRef::from_bytes(font.data())
  } else {
    match find_font_index_by_offset(font.data(), font.offset()) {
      None => None
      Some(index) => @skrifa.FontRef::from_index(font.data(), index)
    }
  }
}

///|
struct OutlineWriter {
  outline : Outline
}

///|

///|
fn OutlineWriter::OutlineWriter(outline : Outline) -> OutlineWriter {
  OutlineWriter::{ outline, }
}

///|
pub impl @skrifa_outline.OutlinePen for OutlineWriter with move_to(self, x, y) {
  self.outline.move_to(Vector::Vector(x, y))
}

///|
pub impl @skrifa_outline.OutlinePen for OutlineWriter with line_to(self, x, y) {
  self.outline.line_to(Vector::Vector(x, y))
}

///|
pub impl @skrifa_outline.OutlinePen for OutlineWriter with quad_to(
  self,
  cx0,
  cy0,
  x,
  y,
) {
  self.outline.quad_to(Vector::Vector(cx0, cy0), Vector::Vector(x, y))
}

///|
pub impl @skrifa_outline.OutlinePen for OutlineWriter with curve_to(
  self,
  cx0,
  cy0,
  cx1,
  cy1,
  x,
  y,
) {
  self.outline.curve_to(
    Vector::Vector(cx0, cy0),
    Vector::Vector(cx1, cy1),
    Vector::Vector(x, y),
  )
}

///|
pub impl @skrifa_outline.OutlinePen for OutlineWriter with close(self) {
  self.outline.close()
}

///|

///|
pub fn Scaler::scale_outline(
  _self : Scaler,
  _glyph_id : @swash.GlyphId,
) -> Outline? {
  let self = _self
  let glyph_id = _glyph_id
  let outline = Outline::Outline()
  if self.scale_outline_into(glyph_id, outline) {
    Some(outline)
  } else {
    None
  }
}

///|
pub fn Scaler::scale_color_outline(
  self : Scaler,
  glyph_id : @swash.GlyphId,
) -> Outline? {
  let outline = Outline::Outline()
  if self.scale_color_outline_into(glyph_id, outline) {
    Some(outline)
  } else {
    None
  }
}

///|
pub fn Scaler::has_color_outlines(self : Scaler) -> Bool {
  self.proxy.val.color.colr != 0 && self.proxy.val.color.cpal != 0
}

///|
pub fn Scaler::has_outlines(self : Scaler) -> Bool {
  match self.outlines {
    None => {
      let loca = @internal.table_offset(self.font, @internal.LOCA)
      let glyf = @internal.table_offset(self.font, @internal.GLYF)
      loca != 0 && glyf != 0
    }
    Some(outlines) => outlines.format() is Some(_)
  }
}

///|
pub fn Scaler::has_bitmaps(self : Scaler) -> Bool {
  self.proxy.val.bitmaps.has_alpha()
}

///|
pub fn Scaler::has_color_bitmaps(self : Scaler) -> Bool {
  self.proxy.val.bitmaps.has_color()
}

///|
pub fn Scaler::scale_bitmap_into(
  self : Scaler,
  glyph_id : @swash.GlyphId,
  strike : StrikeWith,
  image : Image,
) -> Bool {
  match self.scale_bitmap_impl(glyph_id, false, strike, image) {
    None => false
    Some(v) => v
  }
}

///|
pub fn Scaler::scale_bitmap(
  self : Scaler,
  glyph_id : @swash.GlyphId,
  strike : StrikeWith,
) -> Image? {
  let image = Image::Image()
  if self.scale_bitmap_into(glyph_id, strike, image) {
    Some(image)
  } else {
    None
  }
}

///|
pub fn Scaler::scale_color_bitmap_into(
  self : Scaler,
  glyph_id : @swash.GlyphId,
  strike : StrikeWith,
  image : Image,
) -> Bool {
  match self.scale_bitmap_impl(glyph_id, true, strike, image) {
    None => false
    Some(v) => v
  }
}

///|
pub fn Scaler::scale_color_bitmap(
  self : Scaler,
  glyph_id : @swash.GlyphId,
  strike : StrikeWith,
) -> Image? {
  let image = Image::Image()
  if self.scale_color_bitmap_into(glyph_id, strike, image) {
    Some(image)
  } else {
    None
  }
}

///|
fn Scaler::scale_bitmap_impl(
  self : Scaler,
  glyph_id : @swash.GlyphId,
  color : Bool,
  strike : StrikeWith,
  image : Image,
) -> Bool? {
  image.clear()
  let size = self.size
  let skrifa_font = match to_skrifa_font(self.font) {
    None => return None
    Some(f) => f
  }
  let strikes = if color {
    match
      @skrifa.BitmapStrikes::with_format(
        skrifa_font,
        @skrifa.BitmapFormat::Sbix,
      ) {
      None =>
        @skrifa.BitmapStrikes::with_format(
          skrifa_font,
          @skrifa.BitmapFormat::Cbdt,
        )
      Some(s) => Some(s)
    }
  } else {
    @skrifa.BitmapStrikes::with_format(skrifa_font, @skrifa.BitmapFormat::Ebdt)
  }
  let strikes = match strikes {
    None => return None
    Some(s) => s
  }
  let ppem = size.to_int()
  let gid = @skrifa.GlyphId::GlyphId(glyph_id)

  // Select a strike and glyph, mirroring upstream swash strike selection.
  let mut glyph : @skrifa.BitmapGlyph? = None
  let mut strike_ppem = 0
  match strike {
    StrikeWith::ExactSize => {
      if size == 0.0 {
        return None
      }
      for i in 0..<strikes.len() {
        match strikes.get(i) {
          None => ()
          Some(s) =>
            if s.ppem_y() == ppem {
              match s.get(gid) {
                None => ()
                Some(g) => {
                  glyph = Some(g)
                  strike_ppem = s.ppem_y()
                  break
                }
              }
            }
        }
      }
    }
    StrikeWith::BestFit => {
      if size == 0.0 {
        return None
      }
      let mut best : @skrifa.BitmapGlyph? = None
      let mut best_size = 0
      for i in 0..<strikes.len() {
        match strikes.get(i) {
          None => ()
          Some(s) =>
            match s.get(gid) {
              None => ()
              Some(g) => {
                best = Some(g)
                let s_ppem = s.ppem_y()
                if s_ppem > best_size {
                  best = Some(g)
                  best_size = s_ppem
                }
                if s_ppem >= ppem {
                  glyph = Some(g)
                  strike_ppem = s_ppem
                  break
                }
              }
            }
        }
      }
      if glyph is None {
        glyph = best
        strike_ppem = best_size
      }
    }
    StrikeWith::LargestSize => {
      let mut best : @skrifa.BitmapGlyph? = None
      let mut best_size = 0
      for i in 0..<strikes.len() {
        match strikes.get(i) {
          None => ()
          Some(s) =>
            match s.get(gid) {
              None => ()
              Some(g) => {
                let s_ppem = s.ppem_y()
                if best is None || s_ppem > best_size {
                  best = Some(g)
                  best_size = s_ppem
                }
              }
            }
        }
      }
      glyph = best
      strike_ppem = best_size
    }
    StrikeWith::Index(index) => {
      let i = index.reinterpret_as_int()
      if i < 0 || i >= strikes.len() {
        return None
      }
      match strikes.get(i) {
        None => return None
        Some(s) =>
          match s.get(gid) {
            None => return None
            Some(g) => {
              glyph = Some(g)
              strike_ppem = s.ppem_y()
            }
          }
      }
    }
  }
  let glyph = match glyph {
    None => return None
    Some(g) => g
  }
  if strike_ppem == 0 {
    return None
  }

  // Decode into `image.data`, optionally scaling if requested.
  let w = match glyph.width() {
    None => return None
    Some(w) => w
  }
  let h = match glyph.height() {
    None => return None
    Some(h) => h
  }
  if w <= 0 || h <= 0 {
    image.placement = Placement::{ left: 0, top: 0, width: 0U, height: 0U }
    image.source = if color {
      Source::ColorBitmap(strike)
    } else {
      Source::Bitmap(strike)
    }
    image.content = if color { Content::Color } else { Content::Mask }
    return Some(true)
  }
  let scale = if size == 0.0 { 1.0 } else { size / strike_ppem.to_double() }
  let scaled_w = if size != 0.0 && scale != 1.0 {
    (w.to_double() * scale).to_int().reinterpret_as_uint()
  } else {
    w.reinterpret_as_uint()
  }
  let scaled_h = if size != 0.0 && scale != 1.0 {
    (h.to_double() * scale).to_int().reinterpret_as_uint()
  } else {
    h.reinterpret_as_uint()
  }
  self.state.val._scratch0.clear()
  self.state.val._scratch1.clear()
  let origin_x = glyph.origin_x()
  let origin_y = glyph.origin_y()
  match (color, glyph.format()) {
    (true, @skrifa.BitmapImageFormat::Png) => {
      let raw : Array[Byte] = []
      for b in glyph.data() {
        raw.push(b)
      }
      let raw_bytes = Bytes::from_array(raw.op_as_view())
      if size != 0.0 && scale != 1.0 {
        // Decode into scratch then resize into image buffer.
        let src_len = (w.reinterpret_as_uint() * h.reinterpret_as_uint() * 4U).reinterpret_as_int()
        self.state.val._scratch0 = Array::makei(src_len, _ => b'\x00')
        match
          decode_png(
            raw_bytes,
            self.state.val._scratch1,
            self.state.val._scratch0,
          ) {
          None => return None
          Some(_) => ()
        }
        let dst_len = (scaled_w * scaled_h * 4U).reinterpret_as_int()
        image.data = Array::makei(dst_len, _ => b'\x00')
        if !resize_mitchell_rgba(
            self.state.val._scratch0,
            w.reinterpret_as_uint(),
            h.reinterpret_as_uint(),
            image.data,
            scaled_w,
            scaled_h,
            self.state.val._scratch1,
          ) {
          return None
        }
      } else {
        // Decode directly into the destination buffer (do not alias state scratch).
        let dst_len = (w.reinterpret_as_uint() * h.reinterpret_as_uint() * 4U).reinterpret_as_int()
        image.data = Array::makei(dst_len, _ => b'\x00')
        match decode_png(raw_bytes, self.state.val._scratch1, image.data) {
          None => return None
          Some(_) => ()
        }
      }
      image.placement = Placement::{
        left: if size != 0.0 && scale != 1.0 {
          (origin_x.to_double() * scale).to_int()
        } else {
          origin_x
        },
        top: if size != 0.0 && scale != 1.0 {
          (origin_y.to_double() * scale).to_int()
        } else {
          origin_y
        },
        width: scaled_w,
        height: scaled_h,
      }
      image.source = Source::ColorBitmap(strike)
      image.content = Content::Color
      Some(true)
    }
    (false, _) => {
      // Decode EBDT bitmap glyph data as a 1-bit mask.
      if size != 0.0 && scale != 1.0 {
        let src_len = (w.reinterpret_as_uint() * h.reinterpret_as_uint()).reinterpret_as_int()
        self.state.val._scratch0 = Array::makei(src_len, _ => b'\x00')
        if !decode_ebdt_1bpp(
            glyph.data(),
            w.reinterpret_as_uint(),
            h.reinterpret_as_uint(),
            self.state.val._scratch0,
          ) {
          return None
        }
        let dst_len = (scaled_w * scaled_h).reinterpret_as_int()
        image.data = Array::makei(dst_len, _ => b'\x00')
        if !resize_mitchell_alpha(
            self.state.val._scratch0,
            w.reinterpret_as_uint(),
            h.reinterpret_as_uint(),
            image.data,
            scaled_w,
            scaled_h,
            self.state.val._scratch1,
          ) {
          return None
        }
      } else {
        let dst_len = (w.reinterpret_as_uint() * h.reinterpret_as_uint()).reinterpret_as_int()
        image.data = Array::makei(dst_len, _ => b'\x00')
        if !decode_ebdt_1bpp(
            glyph.data(),
            w.reinterpret_as_uint(),
            h.reinterpret_as_uint(),
            image.data,
          ) {
          return None
        }
      }
      image.placement = Placement::{
        left: if size != 0.0 && scale != 1.0 {
          (origin_x.to_double() * scale).to_int()
        } else {
          origin_x
        },
        top: if size != 0.0 && scale != 1.0 {
          (origin_y.to_double() * scale).to_int()
        } else {
          origin_y
        },
        width: scaled_w,
        height: scaled_h,
      }
      image.source = Source::Bitmap(strike)
      image.content = Content::Mask
      Some(true)
    }
    _ => None
  }
}

///|
fn Scaler::scale_outline_layer_into(
  self : Scaler,
  glyph_id : @swash.GlyphId,
  color_index : UInt16?,
  outline : Outline,
) -> Bool {
  match self.outlines {
    None => false
    Some(outlines) => {
      let gid = @skrifa.GlyphId::GlyphId(glyph_id)
      match outlines.get(gid) {
        None => false
        Some(glyph) => {
          outline.begin_layer(color_index)
          let loc = @skrifa.LocationRef::LocationRef(self.coords.op_as_view())
          let settings = match self.hinting_instance {
            None =>
              @skrifa_outline.DrawSettings::unhinted(self.skrifa_size, loc)
            Some(h) => @skrifa_outline.DrawSettings::hinted(h, false)
          }
          let pen = OutlineWriter::OutlineWriter(outline)
          match glyph.draw(settings, pen) {
            Ok(_) => {
              outline.maybe_close()
              outline.finish()
              true
            }
            Err(_) => false
          }
        }
      }
    }
  }
}

///|
test "ScaleContext builder scaffolding" {
  // Minimal TTF header tag 0x00010000 is enough for FontRef::from_offset.
  let data = Bytes::from_array([0, 1, 0, 0])
  let font = @swash.FontRef::from_offset(data, 0).unwrap()
  let cx = ScaleContext::ScaleContext()
  let scaler = cx.builder(font).size(14.0).hint(true).build()
  inspect(scaler.size().to_int(), content="14")
  inspect(scaler.hint(), content="true")
}
