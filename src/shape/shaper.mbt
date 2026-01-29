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
/// Shaper context and builder scaffolding.
///
/// Port intent: align with upstream `swash-reference/src/shape/mod.rs` for
/// `Direction`, `ShapeContext`, `ShaperBuilder`, and `Shaper`.
///
/// Note: the actual shaping engines (OT/AT/AAT) are implemented in later
/// tasks; for now, `Shaper::add_cluster` only pushes mapped clusters into the
/// underlying `Buffer`.

///|
/// Text direction.
pub(all) enum Direction {
  LeftToRight
  RightToLeft
}

///|
pub impl Eq for Direction with equal(self, other) {
  match self {
    Direction::LeftToRight => other is Direction::LeftToRight
    Direction::RightToLeft => other is Direction::RightToLeft
  }
}

///|
const DEFAULT_SIZE : Int = 16

///|
priv struct State {
  buffer : Buffer
  order : Array[Int]
  glyphs : Array[GlyphData]
  store_builder : FeatureStoreBuilder
  mut disable_kern : Bool
  features : Array[@swash.FeatureSetting]
  selectors : Array[(UInt16, UInt16)]
}

///|
fn State::new() -> State {
  State::{
    buffer: Buffer::new(),
    order: [],
    glyphs: [],
    store_builder: FeatureStoreBuilder::default(),
    disable_kern: false,
    features: [],
    selectors: [],
  }
}

///|
fn State::reset(self : State) -> Unit {
  self.buffer.clear()
  self.disable_kern = false
  self.features.clear()
  self.selectors.clear()
}

///|
struct ContextState {
  font_cache : @swash.FontCache[FontEntry]
  feature_cache : FeatureCache
  coords : Array[Int]
  state : State
}

///|
fn ContextState::new(max_entries : Int) -> ContextState {
  ContextState::{
    font_cache: @swash.FontCache::new(max_entries),
    feature_cache: FeatureCache::new(max_entries),
    coords: [],
    state: State::new(),
  }
}

///|
/// Context that manages transient buffers for shaping.
///
/// This is intentionally minimal for ro7.1: caches and engines are introduced
/// in later shaping tasks.
pub struct ShapeContext {
  inner : Ref[ContextState]
}

///|
/// Creates a new shaping context.
pub fn ShapeContext::new() -> ShapeContext {
  ShapeContext::with_max_entries(DEFAULT_SIZE)
}

///|
/// Creates a new shaping context with the specified maximum number of cache entries.
pub fn ShapeContext::with_max_entries(max_entries : Int) -> ShapeContext {
  let mut max_entries0 = max_entries
  if max_entries0 < 1 {
    max_entries0 = 1
  } else if max_entries0 > 64 {
    max_entries0 = 64
  }
  ShapeContext::{ inner: Ref::new(ContextState::new(max_entries0)) }
}

///|
/// Creates a new builder for constructing a shaper with this context.
pub fn ShapeContext::builder(
  self : ShapeContext,
  font : @swash.FontRef,
) -> ShaperBuilder {
  let id0 = font.key().value()
  let id1 = (-1).to_int64().reinterpret_as_uint64()
  ShapeContext::builder_with_id(self, font, (id0, id1))
}

///|
/// Creates a new builder for constructing a shaper with this context.
pub fn ShapeContext::builder_with_id(
  self : ShapeContext,
  font : @swash.FontRef,
  id : (UInt64, UInt64),
) -> ShaperBuilder {
  let (font_id, font_entry) = self.inner.val.font_cache.get(
    font,
    Some(id),
    FontEntry::new,
  )
  self.inner.val.state.reset()
  self.inner.val.coords.clear()
  ShaperBuilder::{
    cx: self.inner,
    font,
    id0: font_id.0,
    id1: font_id.1,
    size: 0.0,
    script: @swash.Script::Latin,
    language: None,
    direction: Direction::LeftToRight,
    charmap: font_entry.val.charmap.materialize(font),
    dotted_circle: None,
    retain_ignorables: false,
    font_entry,
  }
}

///|
/// Builder for configuring a shaper.
pub struct ShaperBuilder {
  cx : Ref[ContextState]
  font : @swash.FontRef
  id0 : UInt64
  id1 : UInt64
  size : Double
  script : @swash.Script
  language : @swash.Language?
  direction : Direction
  font_entry : Ref[FontEntry]
  charmap : @swash.Charmap
  dotted_circle : GlyphId?
  retain_ignorables : Bool
}

///|
/// Specifies the script. The default value is `Script::Latin`.
pub fn ShaperBuilder::script(
  self : ShaperBuilder,
  script : @swash.Script,
) -> ShaperBuilder {
  ShaperBuilder::{
    cx: self.cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script,
    language: self.language,
    direction: self.direction,
    font_entry: self.font_entry,
    charmap: self.charmap,
    dotted_circle: self.dotted_circle,
    retain_ignorables: self.retain_ignorables,
  }
}

///|
/// Specifies the language. The default value is `None`.
pub fn ShaperBuilder::language(
  self : ShaperBuilder,
  language : @swash.Language?,
) -> ShaperBuilder {
  ShaperBuilder::{
    cx: self.cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language,
    direction: self.direction,
    font_entry: self.font_entry,
    charmap: self.charmap,
    dotted_circle: self.dotted_circle,
    retain_ignorables: self.retain_ignorables,
  }
}

///|
/// Specifies the text direction. The default value is `Direction::LeftToRight`.
pub fn ShaperBuilder::direction(
  self : ShaperBuilder,
  direction : Direction,
) -> ShaperBuilder {
  ShaperBuilder::{
    cx: self.cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language: self.language,
    direction,
    font_entry: self.font_entry,
    charmap: self.charmap,
    dotted_circle: self.dotted_circle,
    retain_ignorables: self.retain_ignorables,
  }
}

///|
/// Specifies the font size in pixels per em. The default value is `0` which
/// will produce glyphs with offsets and advances in font units.
pub fn ShaperBuilder::size(
  self : ShaperBuilder,
  ppem : Double,
) -> ShaperBuilder {
  ShaperBuilder::{
    cx: self.cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: if ppem < 0.0 {
      0.0
    } else {
      ppem
    },
    script: self.script,
    language: self.language,
    direction: self.direction,
    font_entry: self.font_entry,
    charmap: self.charmap,
    dotted_circle: self.dotted_circle,
    retain_ignorables: self.retain_ignorables,
  }
}

///|
/// Adds feature settings to the shaper.
pub fn ShaperBuilder::features(
  self : ShaperBuilder,
  settings : Iter[@swash.FeatureSetting],
) -> ShaperBuilder {
  for s in settings {
    if s.tag == KERN {
      self.cx.val.state.disable_kern = s.value == 0
    }
    self.cx.val.state.features.push(s)
  }
  self
}

///|
/// Adds variation settings to the shaper.
pub fn ShaperBuilder::variations(
  self : ShaperBuilder,
  settings : Iter[@swash.VariationSetting],
) -> ShaperBuilder {
  if self.font_entry.val.coord_count != 0 {
    let vars = self.font.variations().iter().to_array()
    self.cx.val.coords.resize(vars.length(), 0)
    for setting in settings {
      for axis in vars.iter() {
        if axis.tag() == setting.tag {
          let value = axis.normalize(setting.value)
          let ix = axis.index()
          if ix >= 0 && ix < self.cx.val.coords.length() {
            self.cx.val.coords[ix] = value
          }
        }
      }
    }
  }
  self
}

///|
/// Specifies whether to insert dotted circles for broken clusters. The default
/// value is `false`.
pub fn ShaperBuilder::insert_dotted_circles(
  self : ShaperBuilder,
  yes : Bool,
) -> ShaperBuilder {
  let dotted_circle = if yes {
    let gid = self.charmap.map(0x25CC)
    if gid != 0 {
      Some(gid)
    } else {
      None
    }
  } else {
    None
  }
  ShaperBuilder::{
    cx: self.cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language: self.language,
    direction: self.direction,
    font_entry: self.font_entry,
    charmap: self.charmap,
    dotted_circle,
    retain_ignorables: self.retain_ignorables,
  }
}

///|
/// Specifies whether characters defined as default ignorable should be retained
/// by the shaper. The default is `false`.
pub fn ShaperBuilder::retain_ignorables(
  self : ShaperBuilder,
  yes : Bool,
) -> ShaperBuilder {
  ShaperBuilder::{
    cx: self.cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    size: self.size,
    script: self.script,
    language: self.language,
    direction: self.direction,
    font_entry: self.font_entry,
    charmap: self.charmap,
    dotted_circle: self.dotted_circle,
    retain_ignorables: yes,
  }
}

///|
/// Builds a shaper for the current configuration.
pub fn ShaperBuilder::build(self : ShaperBuilder) -> Shaper {
  let cx = self.cx
  cx.val.state.buffer.dotted_circle = self.dotted_circle
  cx.val.state.buffer.is_rtl = self.direction == Direction::RightToLeft
  let engine = Engine::new(
    self.font_entry.val.metadata,
    self.font.data(),
    cx.val.coords.op_as_view(),
    self.script,
    self.language,
  )
  let (store, sub_mask, pos_mask) = if engine.use_ot {
    let entry = cx.val.feature_cache.entry(
      (self.id0, self.id1),
      cx.val.coords.op_as_view(),
      engine.has_feature_vars(),
      engine.tags(),
    )
    let store_ref = match entry {
      FeatureCacheEntry::Present(s) => s
      FeatureCacheEntry::New(s) => {
        engine.collect_features(cx.val.state.store_builder, s)
        s
      }
    }
    let buf = cx.val.state.buffer
    let (sub, pos) = store_ref.val.custom_masks(
      cx.val.state.features.op_as_view(),
      buf.sub_args,
      buf.pos_args,
      self.direction,
    )
    (Some(store_ref), sub, pos)
  } else {
    (None, FeatureMask::default(), FeatureMask::default())
  }
  let joined = engine.use_ot && self.script.is_joined()
  Shaper::{
    cx,
    font: self.font,
    id0: self.id0,
    id1: self.id1,
    font_entry: self.font_entry,
    charmap: self.charmap,
    size: self.size,
    script: self.script,
    language: self.language,
    direction: self.direction,
    retain_ignorables: self.retain_ignorables,
    joined,
    engine,
    store,
    sub_mask,
    pos_mask,
  }
}

///|
/// Maps character clusters to (eventually) positioned glyph clusters.
///
/// In ro7.1 this shaper only collects clusters into the underlying `Buffer`.
pub struct Shaper {
  cx : Ref[ContextState]
  font : @swash.FontRef
  id0 : UInt64
  id1 : UInt64
  font_entry : Ref[FontEntry]
  charmap : @swash.Charmap
  size : Double
  script : @swash.Script
  language : @swash.Language?
  direction : Direction
  retain_ignorables : Bool
  joined : Bool
  engine : Engine
  store : Ref[FeatureStore]?
  sub_mask : FeatureMask
  pos_mask : FeatureMask
}

///|
/// Adds a character cluster to the shaper.
pub fn Shaper::add_cluster(self : Shaper, cluster : CharCluster) -> Unit {
  let buf = self.cx.val.state.buffer
  match self.engine.mode {
    EngineMode::Simple => buf.push(cluster) |> ignore
    EngineMode::Myanmar => {
      let e = self.engine
      let sref = match self.store {
        None => return
        Some(v) => v
      }
      let s = sref.val
      let chars = cluster.mapped_chars()
      reorder_myanmar(chars, self.cx.val.state.order)
      let range = buf.push_order(cluster, self.cx.val.state.order.op_as_view())
      e.set_classes(buf, Some(range))
      let start = range.start
      e.gsub(s, s.groups.default, buf, Some(range)) |> ignore
      let end = buf.len()
      e.gsub(
        s,
        feature_bit_to_mask(s.groups.reph),
        buf,
        Some(IndexRange::new(start, end)),
      )
      |> ignore
      let end = buf.len()
      e.gsub(
        s,
        feature_bit_to_mask(s.groups.pref),
        buf,
        Some(IndexRange::new(start, end)),
      )
      |> ignore
      let end = buf.len()
      e.gsub(s, s.groups.stage1, buf, Some(IndexRange::new(start, end)))
      |> ignore
      let end = buf.len()
      e.gsub(s, s.groups.stage2, buf, Some(IndexRange::new(start, end)))
      |> ignore
    }
    EngineMode::Complex => {
      let e = self.engine
      let sref = match self.store {
        None => return
        Some(v) => v
      }
      let s = sref.val
      let range = buf.push(cluster)
      e.set_classes(buf, Some(range))
      let start = range.start
      // Default group.
      e.gsub(s, s.groups.default, buf, Some(range)) |> ignore
      for i in range.start..<range.end {
        let g = buf.glyphs[i]
        if g.char_class is ShapeClass::Halant && (g.flags & SUBSTITUTED) != 0 {
          // Don't prevent reordering across a virama that has been substituted.
          g.char_class = ShapeClass::Other
          buf.glyphs.set(i, g)
        }
      }
      // Reph identification.
      let total = buf.len() - start
      let len = if total < 3 { total } else { 3 }
      let end = start + len
      buf.clear_flags(SUBSTITUTED, Some(IndexRange::new(start, end)))
      e.gsub(
        s,
        feature_bit_to_mask(s.groups.reph),
        buf,
        Some(IndexRange::new(start, end)),
      )
      |> ignore
      for i in start..<end {
        let g = buf.glyphs[i]
        if (g.flags & SUBSTITUTED) != 0 {
          g.char_class = ShapeClass::Reph
          buf.glyphs.set(i, g)
          break
        }
      }
      // Pref identification.
      let end = buf.len()
      buf.clear_flags(SUBSTITUTED, Some(IndexRange::new(start, end)))
      e.gsub(
        s,
        feature_bit_to_mask(s.groups.pref),
        buf,
        Some(IndexRange::new(start, end)),
      )
      |> ignore
      for i in start..<end {
        let g = buf.glyphs[i]
        if (g.flags & SUBSTITUTED) != 0 {
          g.char_class = ShapeClass::Pref
          buf.glyphs.set(i, g)
          break
        }
      }
      // Orthographic group.
      let end = buf.len()
      e.gsub(s, s.groups.stage1, buf, Some(IndexRange::new(start, end)))
      |> ignore
      // Reordering.
      let total = buf.len() - start
      let len = if total < 64 { total } else { 64 }
      let end = start + len
      let slice : Array[GlyphData] = []
      for i in start..<end {
        slice.push(buf.glyphs[i])
      }
      reorder_complex(slice, self.cx.val.state.glyphs, self.cx.val.state.order)
      for i in 0..<slice.length() {
        buf.glyphs.set(start + i, slice[i])
      }
    }
  }
}

///|
/// Adds a string to the shaper.
pub fn Shaper::add_str(self : Shaper, s : String) -> Unit {
  let tokens : Array[@swash.Token] = []
  let mut offset = 0U
  for ch in s {
    tokens.push(
      @swash.Token::new(ch, offset, 1U, @swash.CharInfo::from_char(ch), 0U),
    )
    offset = offset + 1U
  }
  let parser = @swash.Parser::new(self.script, tokens.iter())
  let cluster = @swash.CharCluster::new()
  while parser.next(cluster) {
    cluster.map(fn(ch) { self.charmap.map(ch.to_int().reinterpret_as_uint()) })
    |> ignore
    self.add_cluster(cluster)
  }
}

///|
/// Returns the current normalized variation coordinates in use by the shaper.
pub fn Shaper::normalized_coords(self : Shaper) -> ArrayView[Int] {
  self.engine.coords
}

///|
/// Returns the current font metrics in use by the shaper.
pub fn Shaper::metrics(self : Shaper) -> @swash.Metrics {
  let scale = if self.size != 0.0 { self.size } else { 1.0 }
  self.font_entry.val.metrics
  .materialize_metrics(self.font, self.engine.coords)
  .scale(scale)
}

///|
/// Shapes the text and invokes the specified closure with each resulting glyph cluster.
pub fn Shaper::shape_with(self : Shaper, f : (GlyphCluster) -> Unit) -> Unit {
  self.finish()
  let buf = self.cx.val.state.buffer
  buf.shaped_glyphs.clear()
  let empty_glyphs : Array[Glyph] = []
  let empty_ranges : Array[SourceRange] = []
  let empty_glyphs_view = empty_glyphs.op_as_view()
  let empty_ranges_view = empty_ranges.op_as_view()
  let sentinel_g = GlyphData::default()
  let sentinel_p = PositionData::default()
  sentinel_g.cluster = buf.ranges.length().reinterpret_as_uint()
  let mut last_cluster = 0U
  let len = buf.glyphs.length()
  for i in 0..<(len + 1) {
    let g = if i < len { buf.glyphs[i] } else { sentinel_g }
    let p = if i < len { buf.positions[i] } else { sentinel_p }
    if g.cluster != last_cluster {
      let last_ix = last_cluster.reinterpret_as_int()
      let cur_ix = g.cluster.reinterpret_as_int()
      // Simple and common case: no ligatures and no empty clusters.
      if last_ix > cur_ix || cur_ix - last_ix == 1 {
        let index = last_cluster.reinterpret_as_int()
        let info = buf.infos[index]
        let cluster = GlyphCluster::{
          source: buf.ranges[index],
          info: info.0,
          glyphs: buf.shaped_glyphs.op_as_view(),
          components: empty_ranges_view,
          data: info.2,
        }
        f(cluster)
        buf.shaped_glyphs.clear()
      } else {
        // Collect the range for the non-empty cluster.
        let end = g.cluster.reinterpret_as_int()
        let start = last_cluster.reinterpret_as_int()
        let mut group_end = start + 1
        while group_end < end && buf.infos[group_end].1 {
          group_end = group_end + 1
        }
        if buf.shaped_glyphs.length() != 0 {
          // We have some glyphs. Emit the cluster.
          let source0 = buf.ranges[start]
          let source = @swash.SourceRange::new(
            source0.start(),
            buf.ranges[group_end - 1].end(),
          )
          let components = empty_ranges_view
          let comps : Array[SourceRange] = []
          let components = if group_end > start + 1 {
            for j in start..<group_end {
              comps.push(buf.ranges[j])
            }
            comps.op_as_view()
          } else {
            components
          }
          let info = buf.infos[start]
          let cluster = GlyphCluster::{
            source,
            info: info.0,
            glyphs: buf.shaped_glyphs.op_as_view(),
            components,
            data: info.2,
          }
          f(cluster)
          buf.shaped_glyphs.clear()
        }
        if end > group_end {
          // We have a trailing sequence of empty clusters. Emit them one by one.
          for j in group_end..<end {
            let info = buf.infos[j]
            let cluster = GlyphCluster::{
              source: buf.ranges[j],
              info: info.0,
              glyphs: empty_glyphs_view,
              components: empty_ranges_view,
              data: info.2,
            }
            f(cluster)
          }
        }
      }
    }
    last_cluster = g.cluster
    if self.retain_ignorables || (g.flags & IGNORABLE) == 0 {
      buf.shaped_glyphs.push(Glyph::new(g, p))
    }
  }
}

///|
fn Shaper::finish(self : Shaper) -> Unit {
  if self.cx.val.state.buffer.glyphs.length() == 0 {
    return
  }
  let e = self.engine
  let buf = self.cx.val.state.buffer
  match e.mode {
    EngineMode::Simple =>
      match e.sub_mode {
        SubMode::Gsub => {
          let sref = match self.store {
            None => return
            Some(v) => v
          }
          let s = sref.val
          e.set_classes(buf, None)
          if self.joined {
            buf.set_join_masks()
          }
          e.gsub(s, self.sub_mask, buf, None) |> ignore
        }
        SubMode::Morx => {
          e.collect_selectors(
            self.cx.val.state.features.op_as_view(),
            self.cx.val.state.selectors,
          )
          e.morx(buf, self.cx.val.state.selectors.op_as_view())
        }
        _ => ()
      }
    EngineMode::Myanmar => {
      let sref = match self.store {
        None => return
        Some(v) => v
      }
      let s = sref.val
      e.gsub(s, self.sub_mask.or(s.groups.stage2), buf, None) |> ignore
    }
    EngineMode::Complex => {
      let sref = match self.store {
        None => return
        Some(v) => v
      }
      let s = sref.val
      if self.joined {
        buf.set_join_masks()
        e.gsub(s, s.groups.stage2.or(self.sub_mask), buf, None) |> ignore
      } else {
        e.gsub(s, self.sub_mask, buf, None) |> ignore
      }
    }
  }
  buf.setup_positions(e.sub_mode == SubMode::Morx)
  match e.pos_mode {
    PosMode::Gpos => {
      let sref = match self.store {
        None => return
        Some(v) => v
      }
      let s = sref.val
      e.gpos(s, self.pos_mask, buf, None) |> ignore
    }
    PosMode::Kerx => e.kerx(buf, self.cx.val.state.disable_kern)
    PosMode::Kern =>
      if !self.cx.val.state.disable_kern {
        e.kern(buf)
      } else {
        ()
      }
    _ => ()
  }
  let glyph_metrics = self.font_entry.val.metrics.materialize_glyph_metrics(
    self.font,
    self.engine.coords,
  )
  let len = buf.glyphs.length()
  for i in 0..<len {
    let g = buf.glyphs[i]
    if (g.flags & MARK_ATTACH) == 0 {
      buf.positions[i].advance = buf.positions[i].advance +
        glyph_metrics.advance_width(g.id)
    }
    g.flags = g.flags | buf.positions[i].flags
    buf.glyphs.set(i, g)
  }
  if buf.has_cursive {
    if self.direction == Direction::RightToLeft {
      let mut i = len - 1
      while i >= 0 {
        let g = buf.glyphs[i]
        if (g.flags & CURSIVE_ATTACH) != 0 {
          let base_offset = buf.positions[i].base.to_int()
          if base_offset != 0 && i + base_offset < len {
            let base = buf.positions[i + base_offset]
            buf.positions[i].x = buf.positions[i].x + base.x
            buf.positions[i].y = buf.positions[i].y + base.y
          }
        }
        if i == 0 {
          break
        }
        i = i - 1
      }
    } else {
      for i in 0..<len {
        let g = buf.glyphs[i]
        if (g.flags & CURSIVE_ATTACH) != 0 {
          let base_offset = buf.positions[i].base.to_int()
          if base_offset != 0 && i + base_offset < len {
            let base = buf.positions[i + base_offset]
            buf.positions[i].x = buf.positions[i].x + base.x
            buf.positions[i].y = buf.positions[i].y + base.y
          }
        }
      }
    }
  }
  if buf.has_marks {
    for i in 0..<len {
      let g = buf.glyphs[i]
      if (g.flags & MARK_ATTACH) != 0 {
        let base_offset = buf.positions[i].base.to_int()
        if base_offset != 0 && i - base_offset >= 0 {
          let base = buf.positions[i - base_offset]
          let x = base.x - base.advance
          let y = base.y
          buf.positions[i].x = buf.positions[i].x + x
          buf.positions[i].y = buf.positions[i].y + y
        }
      }
    }
  }
  let upem = glyph_metrics.units_per_em()
  if self.size != 0.0 && upem != 0 {
    let s = self.size / upem.to_int().to_double()
    for i in 0..<buf.positions.length() {
      buf.positions[i].x = buf.positions[i].x * s
      buf.positions[i].y = buf.positions[i].y * s
      buf.positions[i].advance = buf.positions[i].advance * s
    }
  }
}
