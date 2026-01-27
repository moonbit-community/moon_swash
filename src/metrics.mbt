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
/// Font and glyph metrics.
///
/// Ported from `swash/src/metrics.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
const VERTICAL_KIND_VMTX_GLYF : UInt = 0

///|
const VERTICAL_KIND_VMTX_VORG : UInt = 1

///|
const VERTICAL_KIND_SYNTHESIZED : UInt = 2

///|
/// Proxy for rematerializing metrics.
struct MetricsProxy {
  mut units_per_em : UInt16
  mut glyph_count : UInt16
  mut is_monospace : Bool
  mut has_vertical_metrics : Bool
  mut ascent : Int
  mut descent : Int
  mut leading : Int
  mut vertical_ascent : Int
  mut vertical_descent : Int
  mut vertical_leading : Int
  mut cap_height : Int
  mut x_height : Int
  mut average_width : UInt16
  mut max_width : UInt16
  mut underline_offset : Int
  mut strikeout_offset : Int
  mut stroke_size : Int
  mut mvar : UInt
  mut hmtx : UInt
  mut hvar : UInt
  mut hmtx_count : UInt
  mut has_vvar : Bool
  mut vertical_kind : UInt
  mut vertical_loca_fmt : UInt
  mut vertical_long_count : UInt
  mut vertical_vmtx : UInt
  mut vertical_vvar : UInt
  mut vertical_glyf : UInt
  mut vertical_loca : UInt
  mut vertical_vorg : UInt
  mut vertical_synth_mvar : UInt
  mut vertical_synth_advance : Double
  mut vertical_synth_origin : Double
}

///|
pub fn MetricsProxy::from_font(font : FontRef) -> MetricsProxy {
  let m = MetricsProxy::{
    units_per_em: (1).to_uint16(),
    glyph_count: (0).to_uint16(),
    is_monospace: false,
    has_vertical_metrics: false,
    ascent: 0,
    descent: 0,
    leading: 0,
    vertical_ascent: 0,
    vertical_descent: 0,
    vertical_leading: 0,
    cap_height: 0,
    x_height: 0,
    average_width: (0).to_uint16(),
    max_width: (0).to_uint16(),
    underline_offset: 0,
    strikeout_offset: 0,
    stroke_size: 0,
    mvar: 0,
    hmtx: 0,
    hvar: 0,
    hmtx_count: 0,
    has_vvar: false,
    vertical_kind: VERTICAL_KIND_SYNTHESIZED,
    vertical_loca_fmt: 0,
    vertical_long_count: 0,
    vertical_vmtx: 0,
    vertical_vvar: 0,
    vertical_glyf: 0,
    vertical_loca: 0,
    vertical_vorg: 0,
    vertical_synth_mvar: 0,
    vertical_synth_advance: 0.0,
    vertical_synth_origin: 0.0,
  }
  m.fill(font) |> ignore
  m
}

///|
/// Materializes font metrics for the specified font and normalized variation
/// coordinates. This proxy must have been created from the same font.
pub fn MetricsProxy::materialize_metrics(
  self : MetricsProxy,
  font : FontRef,
  coords : ArrayView[NormalizedCoord],
) -> Metrics {
  let mut ascent = self.ascent.to_double()
  let mut descent = self.descent.to_double()
  let mut leading = self.leading.to_double()
  let mut vertical_ascent = self.vertical_ascent.to_double()
  let mut vertical_descent = self.vertical_descent.to_double()
  let mut vertical_leading = self.vertical_leading.to_double()
  let mut cap_height = self.cap_height.to_double()
  let mut x_height = self.x_height.to_double()
  let average_width = self.average_width.to_int().to_double()
  let max_width = self.max_width.to_int().to_double()
  let mut underline_offset = self.underline_offset.to_double()
  let mut strikeout_offset = self.strikeout_offset.to_double()
  let mut stroke_size = self.stroke_size.to_double()
  if self.mvar != 0 && coords.length() > 0 {
    match @internal.Mvar::new(font.data(), self.mvar, coords) {
      None => ()
      Some(v) => {
        ascent = ascent + v.delta(@internal.HASC)
        descent = descent + v.delta(@internal.HDSC)
        leading = leading + v.delta(@internal.HLGP)
        if self.has_vertical_metrics {
          vertical_ascent = vertical_ascent + v.delta(@internal.VASC)
          vertical_descent = vertical_descent + v.delta(@internal.VDSC)
          vertical_leading = vertical_leading + v.delta(@internal.VLGP)
        }
        cap_height = cap_height + v.delta(@internal.CPHT)
        x_height = x_height + v.delta(@internal.XHGT)
        underline_offset = underline_offset + v.delta(@internal.UNDO)
        strikeout_offset = strikeout_offset + v.delta(@internal.STRO)
        stroke_size = stroke_size + v.delta(@internal.UNDS)
      }
    }
  }
  Metrics::{
    units_per_em: self.units_per_em,
    glyph_count: self.glyph_count,
    is_monospace: self.is_monospace,
    has_vertical_metrics: self.has_vertical_metrics,
    ascent,
    descent,
    leading,
    vertical_ascent,
    vertical_descent,
    vertical_leading,
    cap_height,
    x_height,
    average_width,
    max_width,
    underline_offset,
    strikeout_offset,
    stroke_size,
  }
}

///|
/// Materializes glyph metrics for the specified font and normalized variation
/// coordinates. This proxy must have been created from the same font.
pub fn MetricsProxy::materialize_glyph_metrics(
  self : MetricsProxy,
  font : FontRef,
  coords : ArrayView[NormalizedCoord],
) -> GlyphMetrics {
  let kind = self.vertical_kind
  let mut synth_advance = self.vertical_synth_advance
  let mut synth_origin = self.vertical_synth_origin
  if coords.length() > 0 &&
    kind == VERTICAL_KIND_SYNTHESIZED &&
    self.vertical_synth_mvar != 0 {
    match @internal.Mvar::new(font.data(), self.vertical_synth_mvar, coords) {
      None => ()
      Some(v) => {
        let ascent_delta = v.delta(@internal.HASC)
        let descent_delta = v.delta(@internal.HDSC)
        synth_advance = synth_advance + ascent_delta + descent_delta
        synth_origin = synth_origin + ascent_delta
      }
    }
  }
  GlyphMetrics::{
    data: font.data(),
    coords,
    units_per_em: self.units_per_em,
    glyph_count: self.glyph_count,
    hmtx: self.hmtx,
    hvar: self.hvar,
    hmtx_count: self.hmtx_count,
    has_vvar: self.has_vvar,
    vertical_kind: kind,
    vertical_loca_fmt: self.vertical_loca_fmt,
    vertical_long_count: self.vertical_long_count,
    vertical_vmtx: self.vertical_vmtx,
    vertical_vvar: self.vertical_vvar,
    vertical_glyf: self.vertical_glyf,
    vertical_loca: self.vertical_loca,
    vertical_vorg: self.vertical_vorg,
    vertical_synth_advance: synth_advance,
    vertical_synth_origin: synth_origin,
    scale: 1.0,
  }
}

///|
pub fn MetricsProxy::units_per_em(self : MetricsProxy) -> UInt16 {
  self.units_per_em
}

///|
pub fn MetricsProxy::glyph_count(self : MetricsProxy) -> UInt16 {
  self.glyph_count
}

///|
fn MetricsProxy::fill(self : MetricsProxy, font : FontRef) -> Unit? {
  let head = match font.head() {
    None => return None
    Some(t) => t
  }
  self.units_per_em = head.units_per_em().to_uint16()
  self.glyph_count = match font.maxp() {
    None => return None
    Some(t) => t.glyph_count().to_uint16()
  }
  let mut have_line_metrics = false
  match font.os2() {
    None => ()
    Some(os2) => {
      let flags = os2.selection_flags()
      self.average_width = os2.average_char_width().to_uint16()
      self.strikeout_offset = os2.strikeout_position()
      self.stroke_size = os2.strikeout_size()
      self.x_height = os2.x_height()
      self.cap_height = os2.cap_height()
      if flags.use_typographic_metrics() {
        self.ascent = os2.typographic_ascender()
        self.descent = -os2.typographic_descender()
        self.leading = os2.typographic_line_gap()
        have_line_metrics = self.ascent != 0
      }
    }
  }
  let hhea = font.hhea()
  match hhea {
    None => ()
    Some(hhea) => {
      self.max_width = hhea.max_advance().to_uint16()
      if !have_line_metrics {
        self.ascent = hhea.ascender()
        self.descent = -hhea.descender()
        self.leading = hhea.line_gap()
      }
    }
  }
  let vhea = font.vhea()
  match vhea {
    Some(vhea) => {
      self.has_vertical_metrics = true
      self.vertical_ascent = vhea.ascender()
      self.vertical_descent = -vhea.descender()
      self.vertical_leading = vhea.line_gap()
    }
    None => {
      let half = self.units_per_em.to_int() / 2
      self.vertical_ascent = half
      self.vertical_descent = half
    }
  }
  match font.post() {
    None => ()
    Some(post) => {
      self.underline_offset = post.underline_position()
      self.stroke_size = post.underline_size()
      self.is_monospace = post.is_fixed_pitch()
    }
  }
  self.mvar = font.table_offset(@internal.MVAR)
  self.hmtx_count = match hhea {
    None => (1).reinterpret_as_uint()
    Some(t) => t.num_long_metrics()
  }
  self.hmtx = font.table_offset(@internal.HMTX)
  self.hvar = font.table_offset(@internal.HVAR)
  let mut vmtx : UInt = 0
  if vhea is Some(_) {
    vmtx = font.table_offset(@internal.VMTX)
  }
  if vmtx != 0 {
    let long_count = match vhea {
      None => (0).reinterpret_as_uint()
      Some(t) => t.num_long_metrics()
    }
    let vvar = font.table_offset(@internal.VVAR)
    self.has_vvar = vvar != 0
    let vorg = font.table_offset(@internal.VORG)
    if vorg != 0 {
      self.vertical_kind = VERTICAL_KIND_VMTX_VORG
      self.vertical_long_count = long_count
      self.vertical_vmtx = vmtx
      self.vertical_vvar = vvar
      self.vertical_vorg = vorg
    } else {
      let glyf = font.table_offset(@internal.GLYF)
      let loca = font.table_offset(@internal.LOCA)
      let loca_fmt = font
        .head()
        .map(t => t.index_to_location_format())
        .unwrap_or((0xFF).reinterpret_as_uint())
      if glyf != 0 && loca != 0 && loca_fmt != (0xFF).reinterpret_as_uint() {
        self.vertical_kind = VERTICAL_KIND_VMTX_GLYF
        self.vertical_loca_fmt = loca_fmt
        self.vertical_long_count = long_count
        self.vertical_vmtx = vmtx
        self.vertical_vvar = vvar
        self.vertical_glyf = glyf
        self.vertical_loca = loca
      }
    }
  } else {
    self.vertical_kind = VERTICAL_KIND_SYNTHESIZED
    self.vertical_synth_mvar = self.mvar
    self.vertical_synth_advance = self.ascent.to_double() +
      self.descent.to_double()
    self.vertical_synth_origin = self.ascent.to_double()
  }
  Some(())
}

///|
/// Global font metrics.
pub struct Metrics {
  units_per_em : UInt16
  glyph_count : UInt16
  is_monospace : Bool
  has_vertical_metrics : Bool
  ascent : Double
  descent : Double
  leading : Double
  vertical_ascent : Double
  vertical_descent : Double
  vertical_leading : Double
  cap_height : Double
  x_height : Double
  average_width : Double
  max_width : Double
  underline_offset : Double
  strikeout_offset : Double
  stroke_size : Double
}

///|
fn Metrics::from_font(
  font : FontRef,
  coords : ArrayView[NormalizedCoord],
) -> Metrics {
  let proxy = MetricsProxy::from_font(font)
  proxy.materialize_metrics(font, coords)
}

///|
/// Creates a new set of metrics scaled for the specified pixels per em unit.
pub fn Metrics::scale(self : Metrics, ppem : Double) -> Metrics {
  self.linear_scale(
    if self.units_per_em != 0 {
      ppem / self.units_per_em.to_int().to_double()
    } else {
      1.0
    },
  )
}

///|
/// Creates a new set of metrics scaled by the specified factor.
pub fn Metrics::linear_scale(self : Metrics, s : Double) -> Metrics {
  Metrics::{
    units_per_em: self.units_per_em,
    glyph_count: self.glyph_count,
    is_monospace: self.is_monospace,
    has_vertical_metrics: self.has_vertical_metrics,
    ascent: self.ascent * s,
    descent: self.descent * s,
    leading: self.leading * s,
    vertical_ascent: self.vertical_ascent * s,
    vertical_descent: self.vertical_descent * s,
    vertical_leading: self.vertical_leading * s,
    cap_height: self.cap_height * s,
    x_height: self.x_height * s,
    average_width: self.average_width * s,
    max_width: self.max_width * s,
    underline_offset: self.underline_offset * s,
    strikeout_offset: self.strikeout_offset * s,
    stroke_size: self.stroke_size * s,
  }
}

///|
/// Glyph advances, side bearings and vertical origins.
struct GlyphMetrics {
  data : Bytes
  coords : ArrayView[NormalizedCoord]
  units_per_em : UInt16
  glyph_count : UInt16
  hmtx : UInt
  hvar : UInt
  hmtx_count : UInt
  has_vvar : Bool
  vertical_kind : UInt
  vertical_loca_fmt : UInt
  vertical_long_count : UInt
  vertical_vmtx : UInt
  vertical_vvar : UInt
  vertical_glyf : UInt
  vertical_loca : UInt
  vertical_vorg : UInt
  vertical_synth_advance : Double
  vertical_synth_origin : Double
  mut scale : Double
}

///|
fn GlyphMetrics::from_font(
  font : FontRef,
  coords : ArrayView[NormalizedCoord],
) -> GlyphMetrics {
  let proxy = MetricsProxy::from_font(font)
  proxy.materialize_glyph_metrics(font, coords)
}

///|
pub fn GlyphMetrics::units_per_em(self : GlyphMetrics) -> UInt16 {
  self.units_per_em
}

///|
pub fn GlyphMetrics::glyph_count(self : GlyphMetrics) -> UInt16 {
  self.glyph_count
}

///|
/// Returns true if the font provides canonical vertical glyph metrics.
pub fn GlyphMetrics::has_vertical_metrics(self : GlyphMetrics) -> Bool {
  self.vertical_kind != VERTICAL_KIND_SYNTHESIZED
}

///|
/// Returns true if variations are supported.
pub fn GlyphMetrics::has_variations(self : GlyphMetrics) -> Bool {
  self.hvar != 0 || self.has_vvar
}

///|
/// Creates a new set of metrics scaled for the specified pixels per em unit.
pub fn GlyphMetrics::scale(self : GlyphMetrics, ppem : Double) -> GlyphMetrics {
  self.linear_scale(
    if self.units_per_em != 0 {
      ppem / self.units_per_em.to_int().to_double()
    } else {
      1.0
    },
  )
}

///|
/// Creates a new set of metrics scaled by the specified factor.
pub fn GlyphMetrics::linear_scale(
  self : GlyphMetrics,
  scale : Double,
) -> GlyphMetrics {
  let copy = self
  copy.scale = scale
  copy
}

///|
/// Returns the horizontal advance for the specified glyph.
pub fn GlyphMetrics::advance_width(
  self : GlyphMetrics,
  glyph_id : GlyphId,
) -> Double {
  let mut v = @internal.advance(
      self.data,
      self.hmtx,
      self.hmtx_count,
      glyph_id.to_uint(),
    )
    .reinterpret_as_int()
    .to_double()
  if self.hvar != 0 {
    v = v +
      @internal.advance_delta(
        self.data,
        self.hvar,
        glyph_id.to_uint(),
        self.coords,
      )
  }
  v * self.scale
}

///|
/// Returns the left side bearing for the specified glyph.
pub fn GlyphMetrics::lsb(self : GlyphMetrics, glyph_id : GlyphId) -> Double {
  let mut v = @internal.sb(
    self.data,
    self.hmtx,
    self.hmtx_count,
    glyph_id.to_uint(),
  ).to_double()
  if self.hvar != 0 {
    v = v +
      @internal.sb_delta(self.data, self.hvar, glyph_id.to_uint(), self.coords)
  }
  v * self.scale
}

///|
/// Returns the vertical advance for the specified glyph.
pub fn GlyphMetrics::advance_height(
  self : GlyphMetrics,
  glyph_id : GlyphId,
) -> Double {
  let mut v = self.vertical_synth_advance
  if self.vertical_kind == VERTICAL_KIND_VMTX_GLYF ||
    self.vertical_kind == VERTICAL_KIND_VMTX_VORG {
    v = @internal.advance(
        self.data,
        self.vertical_vmtx,
        self.vertical_long_count,
        glyph_id.to_uint(),
      )
      .reinterpret_as_int()
      .to_double()
    if self.vertical_vvar != 0 {
      v = v +
        @internal.advance_delta(
          self.data,
          self.vertical_vvar,
          glyph_id.to_uint(),
          self.coords,
        )
    }
  }
  v * self.scale
}

///|
/// Returns the top side bearing for the specified glyph.
pub fn GlyphMetrics::tsb(self : GlyphMetrics, glyph_id : GlyphId) -> Double {
  let mut v = 0.0
  if self.vertical_kind == VERTICAL_KIND_VMTX_GLYF ||
    self.vertical_kind == VERTICAL_KIND_VMTX_VORG {
    v = @internal.sb(
      self.data,
      self.vertical_vmtx,
      self.vertical_long_count,
      glyph_id.to_uint(),
    ).to_double()
    if self.vertical_vvar != 0 {
      v = v +
        @internal.sb_delta(
          self.data,
          self.vertical_vvar,
          glyph_id.to_uint(),
          self.coords,
        )
    }
  }
  v * self.scale
}

///|
/// Returns the vertical origin for the specified glyph id.
pub fn GlyphMetrics::vertical_origin(
  self : GlyphMetrics,
  glyph_id : GlyphId,
) -> Double {
  let mut v = self.vertical_synth_origin
  if self.vertical_kind == VERTICAL_KIND_VMTX_GLYF {
    v = match
      @internal.ymax(
        self.data,
        self.vertical_loca_fmt,
        self.vertical_loca,
        self.vertical_glyf,
        glyph_id.to_uint(),
      ) {
      None => self.units_per_em.to_int().to_double()
      Some(max_y) => max_y.to_double() + self.tsb(glyph_id)
    }
  } else if self.vertical_kind == VERTICAL_KIND_VMTX_VORG {
    v = match
      @internal.origin(self.data, self.vertical_vorg, glyph_id.to_uint()) {
      None => self.units_per_em.to_int().to_double()
      Some(o) => o.to_double()
    }
  }
  v * self.scale
}

///|
/// Returns metrics for the font and the specified normalized variation
/// coordinates.
pub fn FontRef::metrics(
  self : FontRef,
  coords : ArrayView[NormalizedCoord],
) -> Metrics {
  Metrics::from_font(self, coords)
}

///|
/// Returns glyph metrics for the font and the specified normalized variation
/// coordinates.
pub fn FontRef::glyph_metrics(
  self : FontRef,
  coords : ArrayView[NormalizedCoord],
) -> GlyphMetrics {
  GlyphMetrics::from_font(self, coords)
}
