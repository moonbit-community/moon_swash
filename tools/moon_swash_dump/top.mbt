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
/// WASI CLI that dumps a small JSON summary for diffing against upstream swash.

fn f64_round3(x : Double) -> Double {
  // Keep output stable for diffs.
  (x * 1000.0).round() / 1000.0
}

fn pick_glyph_id(clusters : Array[Array[@shape.Glyph]]) -> UInt16 {
  for gs in clusters.iter() {
    for g in gs.iter() {
      let id = g.id()
      if id != 0 {
        return id
      }
    }
  }
  (0).to_uint16()
}

fn parse_size(s : String) -> Double? {
  if s.length() == 0 {
    return None
  }
  let mut i = 0
  let mut sign = 1.0
  if s.code_unit_at(0) == 45 { // '-'
    sign = -1.0
    i = 1
  }
  let mut int_part = 0.0
  let mut frac_part = 0.0
  let mut frac_scale = 1.0
  let mut seen_dot = false
  while i < s.length() {
    let c = s.code_unit_at(i)
    if c == 46 && !seen_dot { // '.'
      seen_dot = true
      i = i + 1
      continue
    }
    if c < 48 || c > 57 {
      return None
    }
    let d = (c.to_int() - 48).to_double()
    if !seen_dot {
      int_part = int_part * 10.0 + d
    } else {
      frac_scale = frac_scale * 10.0
      frac_part = frac_part + d / frac_scale
    }
    i = i + 1
  }
  Some((int_part + frac_part) * sign)
}

fn strike_with_to_string(mode : @scale.StrikeWith) -> String {
  match mode {
    @scale.StrikeWith::ExactSize => "ExactSize"
    @scale.StrikeWith::BestFit => "BestFit"
    @scale.StrikeWith::LargestSize => "LargestSize"
    @scale.StrikeWith::Index(i) => "Index(\{i})"
  }
}

fn source_to_string(source : @scale.Source) -> String {
  match source {
    @scale.Source::Outline => "Outline"
    @scale.Source::ColorOutline(ix) => "ColorOutline(\{ix})"
    @scale.Source::Bitmap(mode) => "Bitmap(\{strike_with_to_string(mode)})"
    @scale.Source::ColorBitmap(mode) =>
      "ColorBitmap(\{strike_with_to_string(mode)})"
  }
}

fn content_to_string(content : @scale.Content) -> String {
  match content {
    @scale.Content::Mask => "Mask"
    @scale.Content::SubpixelMask => "SubpixelMask"
    @scale.Content::Color => "Color"
  }
}

fn verb_to_string(v : @zeno.Verb) -> String {
  match v {
    @zeno.Verb::MoveTo => "MoveTo"
    @zeno.Verb::LineTo => "LineTo"
    @zeno.Verb::QuadTo => "QuadTo"
    @zeno.Verb::CurveTo => "CurveTo"
    @zeno.Verb::Close => "Close"
  }
}

fn byte_stats(data : ArrayView[Byte]) -> (UInt64, UInt64) {
  let mut sum : UInt64 = 0
  let mut xor : UInt64 = 0
  for b in data {
    let u = b.to_int().to_uint64()
    sum = sum + u
    xor = xor ^ u
  }
  (sum, xor)
}

fn write_json_escaped(s : String) -> Unit {
  @stdio.stdout.write_sync("\"") catch { _ => () }
  for ch in s {
    match ch {
      '"' => @stdio.stdout.write_sync("\\\"") catch { _ => () }
      '\\' => @stdio.stdout.write_sync("\\\\") catch { _ => () }
      '\n' => @stdio.stdout.write_sync("\\n") catch { _ => () }
      '\r' => @stdio.stdout.write_sync("\\r") catch { _ => () }
      '\t' => @stdio.stdout.write_sync("\\t") catch { _ => () }
      _ => @stdio.stdout.write_sync(ch.to_string()) catch { _ => () }
    }
  }
  @stdio.stdout.write_sync("\"") catch { _ => () }
}

fn write_image_json(image : @scale.Image?) -> Unit {
  match image {
    None => {
      @stdio.stdout.write_sync("{\"ok\":false}") catch { _ => () }
    }
    Some(img) => {
      let p = img.placement()
      let data = img.data_view()
      let (sum, xor) = byte_stats(data)
      @stdio.stdout.write_sync("{\"ok\":true") catch { _ => () }
      @stdio.stdout.write_sync(",\"source\":") catch { _ => () }
      write_json_escaped(source_to_string(img.source()))
      @stdio.stdout.write_sync(",\"content\":") catch { _ => () }
      write_json_escaped(content_to_string(img.content()))
      @stdio.stdout.write_sync(",\"placement\":[") catch { _ => () }
      @stdio.stdout.write_sync(p.left.to_string()) catch { _ => () }
      @stdio.stdout.write_sync(",") catch { _ => () }
      @stdio.stdout.write_sync(p.top.to_string()) catch { _ => () }
      @stdio.stdout.write_sync(",") catch { _ => () }
      @stdio.stdout.write_sync(p.width.to_string()) catch { _ => () }
      @stdio.stdout.write_sync(",") catch { _ => () }
      @stdio.stdout.write_sync(p.height.to_string()) catch { _ => () }
      @stdio.stdout.write_sync("]") catch { _ => () }
      @stdio.stdout.write_sync(",\"data_len\":") catch { _ => () }
      @stdio.stdout.write_sync(data.length().to_string()) catch { _ => () }
      @stdio.stdout.write_sync(",\"data_sum\":") catch { _ => () }
      @stdio.stdout.write_sync(sum.to_string()) catch { _ => () }
      @stdio.stdout.write_sync(",\"data_xor\":") catch { _ => () }
      @stdio.stdout.write_sync(xor.to_string()) catch { _ => () }
      @stdio.stdout.write_sync(",\"sample\":[") catch { _ => () }
      let limit = if data.length() < 16 { data.length() } else { 16 }
      for i in 0..<limit {
        if i != 0 {
          @stdio.stdout.write_sync(",") catch { _ => () }
        }
        @stdio.stdout.write_sync(data[i].to_int().to_string()) catch { _ => () }
      }
      @stdio.stdout.write_sync("]}") catch { _ => () }
    }
  }
}

fn dump_and_write_json(
  font_path : String,
  text : String,
  size : Double,
) -> Bool {
  let data = Some(@fs.read_file_sync(font_path)) catch { _ => None }
  if data is None {
    return false
  }
  let data = data.unwrap()
  let bytes = data.binary()
  let font = match @swash.FontRef::from_index(bytes, 0) {
    None => return false
    Some(f) => f
  }
  let metrics = font.metrics([][:])
  let attrs = font.attributes()
  let (stretch, weight, style) = attrs.parts()
  let mut feature_count = 0
  for _ in font.features().iter() {
    feature_count = feature_count + 1
  }
  let mut writing_system_count = 0
  for _ in font.writing_systems().iter() {
    writing_system_count = writing_system_count + 1
  }
  let color_palette_count = font.color_palettes().len()
  let alpha_strike_count = font.alpha_strikes().len()
  let color_strike_count = font.color_strikes().len()

  let charmap = @swash.Charmap::from_font(font)
  let codepoints : Array[UInt] = []
  let mapped_glyph_ids : Array[UInt16] = []
  for ch in text {
    let cp = ch.to_int().reinterpret_as_uint()
    codepoints.push(cp)
    mapped_glyph_ids.push(charmap.map(cp))
  }

  // Shape
  let shaper_cx = @shape.ShapeContext::new()
  let shaper = shaper_cx.builder(font).size(size).build()
  shaper.add_str(text)
  let coords = shaper.normalized_coords().to_array()
  let clusters : Array[Array[@shape.Glyph]] = []
  let ranges : Array[(UInt, UInt)] = []
  shaper.shape_with(fn(cluster) {
    let src = cluster.source()
    ranges.push((src.start(), src.end()))
    let gs : Array[@shape.Glyph] = []
    for g in cluster.glyphs() {
      gs.push(g)
    }
    clusters.push(gs)
  })
  let shape_metrics = shaper.metrics()

  // Scale outline for a representative glyph.
  let glyph_id = pick_glyph_id(clusters)
  let scx = @scale.ScaleContext::new()
  let scaler = scx
    .builder(font)
    .size(size)
    .hint(false)
    .normalized_coords(coords.op_as_view())
    .build()
  let has_outlines = scaler.has_outlines()
  let has_color_outlines = scaler.has_color_outlines()
  let has_bitmaps = scaler.has_bitmaps()
  let has_color_bitmaps = scaler.has_color_bitmaps()
  let glyph_metrics = font.glyph_metrics(coords.op_as_view())
  let gm_advance_width = f64_round3(glyph_metrics.advance_width(glyph_id))
  let gm_lsb = f64_round3(glyph_metrics.lsb(glyph_id))
  let gm_advance_height = f64_round3(glyph_metrics.advance_height(glyph_id))
  let gm_tsb = f64_round3(glyph_metrics.tsb(glyph_id))
  let gm_vertical_origin = f64_round3(glyph_metrics.vertical_origin(glyph_id))

  let outline = @scale.Outline::new()
  let outline_ok = if glyph_id == 0 {
    false
  } else {
    scaler.scale_outline_into(glyph_id, outline)
  }
  let (min_x, min_y, max_x, max_y) = if outline_ok {
    let b = outline.bounds()
    (
      f64_round3(b.min.x()),
      f64_round3(b.min.y()),
      f64_round3(b.max.x()),
      f64_round3(b.max.y()),
    )
  } else {
    (0.0, 0.0, 0.0, 0.0)
  }
  let outline_alpha_img = @scale.Render::new([@scale.Source::Outline])
    .format(@zeno.Format::Alpha)
    .render(scaler, glyph_id)
  let outline_subpixel_img = @scale.Render::new([@scale.Source::Outline])
    .format(@zeno.Format::Subpixel)
    .render(scaler, glyph_id)
  let color_outline_img = if has_color_outlines {
    @scale.Render::new([@scale.Source::ColorOutline((0).to_uint16())])
    .format(@zeno.Format::Alpha)
    .render(scaler, glyph_id)
  } else {
    None
  }
  let bitmap_img = if has_bitmaps {
    @scale.Render::new([@scale.Source::Bitmap(@scale.StrikeWith::BestFit)])
    .render(scaler, glyph_id)
  } else {
    None
  }
  let color_bitmap_img = if has_color_bitmaps {
    @scale.Render::new(
      [@scale.Source::ColorBitmap(@scale.StrikeWith::BestFit)],
    ).render(scaler, glyph_id)
  } else {
    None
  }

  // JSON
  @stdio.stdout.write_sync("{") catch { _ => () }

  @stdio.stdout.write_sync("\"font\":{") catch { _ => () }
  @stdio.stdout.write_sync("\"path\":") catch { _ => () }
  write_json_escaped(font_path)
  @stdio.stdout.write_sync(",\"units_per_em\":") catch { _ => () }
  @stdio.stdout.write_sync(metrics.units_per_em.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"glyph_count\":") catch { _ => () }
  @stdio.stdout.write_sync(metrics.glyph_count.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"var_count\":") catch { _ => () }
  @stdio.stdout.write_sync(font.variations().len().to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"attributes\":") catch { _ => () }
  write_json_escaped(attrs.to_string())
  @stdio.stdout.write_sync(",\"stretch\":") catch { _ => () }
  write_json_escaped(stretch.to_string())
  @stdio.stdout.write_sync(",\"weight\":") catch { _ => () }
  write_json_escaped(weight.to_string())
  @stdio.stdout.write_sync(",\"style\":") catch { _ => () }
  write_json_escaped(style.to_string())
  @stdio.stdout.write_sync(",\"feature_count\":") catch { _ => () }
  @stdio.stdout.write_sync(feature_count.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"writing_system_count\":") catch { _ => () }
  @stdio.stdout.write_sync(writing_system_count.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"color_palette_count\":") catch { _ => () }
  @stdio.stdout.write_sync(color_palette_count.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"alpha_strike_count\":") catch { _ => () }
  @stdio.stdout.write_sync(alpha_strike_count.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"color_strike_count\":") catch { _ => () }
  @stdio.stdout.write_sync(color_strike_count.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"cmap\":[") catch { _ => () }
  for i in 0..<codepoints.length() {
    if i != 0 {
      @stdio.stdout.write_sync(",") catch { _ => () }
    }
    @stdio.stdout.write_sync("[") catch { _ => () }
    @stdio.stdout.write_sync(codepoints[i].to_string()) catch { _ => () }
    @stdio.stdout.write_sync(",") catch { _ => () }
    @stdio.stdout.write_sync(mapped_glyph_ids[i].to_string()) catch { _ => () }
    @stdio.stdout.write_sync("]") catch { _ => () }
  }
  @stdio.stdout.write_sync("]") catch { _ => () }
  @stdio.stdout.write_sync("},") catch { _ => () }

  @stdio.stdout.write_sync("\"shape\":{") catch { _ => () }
  @stdio.stdout.write_sync("\"text\":") catch { _ => () }
  write_json_escaped(text)
  @stdio.stdout.write_sync(",\"size\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(size).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"coords\":[") catch { _ => () }
  for i in 0..<coords.length() {
    if i != 0 {
      @stdio.stdout.write_sync(",") catch { _ => () }
    }
    @stdio.stdout.write_sync(coords[i].to_string()) catch { _ => () }
  }
  @stdio.stdout.write_sync("],\"clusters\":[") catch { _ => () }
  for i in 0..<clusters.length() {
    if i != 0 {
      @stdio.stdout.write_sync(",") catch { _ => () }
    }
    @stdio.stdout.write_sync("{\"source\":[") catch { _ => () }
    let (s0, s1) = ranges[i]
    @stdio.stdout.write_sync(s0.to_string()) catch { _ => () }
    @stdio.stdout.write_sync(",") catch { _ => () }
    @stdio.stdout.write_sync(s1.to_string()) catch { _ => () }
    @stdio.stdout.write_sync("],\"glyphs\":[") catch { _ => () }
    let gs = clusters[i]
    for j in 0..<gs.length() {
      if j != 0 {
        @stdio.stdout.write_sync(",") catch { _ => () }
      }
      let g = gs[j]
      @stdio.stdout.write_sync("{\"id\":") catch { _ => () }
      @stdio.stdout.write_sync(g.id().to_string()) catch { _ => () }
      @stdio.stdout.write_sync(",\"x\":") catch { _ => () }
      @stdio.stdout.write_sync(f64_round3(g.x()).to_string()) catch { _ => () }
      @stdio.stdout.write_sync(",\"y\":") catch { _ => () }
      @stdio.stdout.write_sync(f64_round3(g.y()).to_string()) catch { _ => () }
      @stdio.stdout.write_sync(",\"adv\":") catch { _ => () }
      @stdio.stdout.write_sync(f64_round3(g.advance()).to_string()) catch { _ => () }
      @stdio.stdout.write_sync("}") catch { _ => () }
    }
    @stdio.stdout.write_sync("]}") catch { _ => () }
  }
  @stdio.stdout.write_sync("],\"metrics\":{") catch { _ => () }
  @stdio.stdout.write_sync("\"units_per_em\":") catch { _ => () }
  @stdio.stdout.write_sync(shape_metrics.units_per_em.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"glyph_count\":") catch { _ => () }
  @stdio.stdout.write_sync(shape_metrics.glyph_count.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"is_monospace\":") catch { _ => () }
  @stdio.stdout.write_sync(shape_metrics.is_monospace.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"has_vertical_metrics\":") catch { _ => () }
  @stdio.stdout.write_sync(shape_metrics.has_vertical_metrics.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"ascent\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.ascent).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"descent\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.descent).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"leading\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.leading).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"vertical_ascent\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.vertical_ascent).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"vertical_descent\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.vertical_descent).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"vertical_leading\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.vertical_leading).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"cap_height\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.cap_height).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"x_height\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.x_height).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"average_width\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.average_width).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"max_width\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.max_width).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"underline_offset\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.underline_offset).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"strikeout_offset\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.strikeout_offset).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"stroke_size\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(shape_metrics.stroke_size).to_string()) catch { _ => () }
  @stdio.stdout.write_sync("}},") catch { _ => () }

  @stdio.stdout.write_sync("\"scale\":{") catch { _ => () }
  @stdio.stdout.write_sync("\"size\":") catch { _ => () }
  @stdio.stdout.write_sync(f64_round3(size).to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"hint\":false,") catch { _ => () }
  @stdio.stdout.write_sync("\"glyph_id\":") catch { _ => () }
  @stdio.stdout.write_sync(glyph_id.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"has_outlines\":") catch { _ => () }
  @stdio.stdout.write_sync(has_outlines.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"has_color_outlines\":") catch { _ => () }
  @stdio.stdout.write_sync(has_color_outlines.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"has_bitmaps\":") catch { _ => () }
  @stdio.stdout.write_sync(has_bitmaps.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"has_color_bitmaps\":") catch { _ => () }
  @stdio.stdout.write_sync(has_color_bitmaps.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"glyph_metrics\":{") catch { _ => () }
  @stdio.stdout.write_sync("\"units_per_em\":") catch { _ => () }
  @stdio.stdout.write_sync(glyph_metrics.units_per_em().to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"glyph_count\":") catch { _ => () }
  @stdio.stdout.write_sync(glyph_metrics.glyph_count().to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"has_vertical_metrics\":") catch { _ => () }
  @stdio.stdout.write_sync(glyph_metrics.has_vertical_metrics().to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"has_variations\":") catch { _ => () }
  @stdio.stdout.write_sync(glyph_metrics.has_variations().to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"advance_width\":") catch { _ => () }
  @stdio.stdout.write_sync(gm_advance_width.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"lsb\":") catch { _ => () }
  @stdio.stdout.write_sync(gm_lsb.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"advance_height\":") catch { _ => () }
  @stdio.stdout.write_sync(gm_advance_height.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"tsb\":") catch { _ => () }
  @stdio.stdout.write_sync(gm_tsb.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"vertical_origin\":") catch { _ => () }
  @stdio.stdout.write_sync(gm_vertical_origin.to_string()) catch { _ => () }
  @stdio.stdout.write_sync("}") catch { _ => () }
  @stdio.stdout.write_sync(",\"outline\":{") catch { _ => () }
  @stdio.stdout.write_sync("\"ok\":") catch { _ => () }
  @stdio.stdout.write_sync(outline_ok.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"layers\":") catch { _ => () }
  @stdio.stdout.write_sync(outline.len().to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"points\":") catch { _ => () }
  @stdio.stdout.write_sync(outline.points().length().to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"verbs\":") catch { _ => () }
  @stdio.stdout.write_sync(outline.verbs().length().to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"verbs_seq\":[") catch { _ => () }
  let outline_verbs = outline.verbs()
  for i in 0..<outline_verbs.length() {
    if i != 0 {
      @stdio.stdout.write_sync(",") catch { _ => () }
    }
    write_json_escaped(verb_to_string(outline_verbs[i]))
  }
  @stdio.stdout.write_sync("]") catch { _ => () }
  @stdio.stdout.write_sync(",\"bounds\":[") catch { _ => () }
  @stdio.stdout.write_sync(min_x.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",") catch { _ => () }
  @stdio.stdout.write_sync(min_y.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",") catch { _ => () }
  @stdio.stdout.write_sync(max_x.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",") catch { _ => () }
  @stdio.stdout.write_sync(max_y.to_string()) catch { _ => () }
  @stdio.stdout.write_sync("]}") catch { _ => () }
  @stdio.stdout.write_sync(",\"render\":{") catch { _ => () }
  @stdio.stdout.write_sync("\"outline_alpha\":") catch { _ => () }
  write_image_json(outline_alpha_img)
  @stdio.stdout.write_sync(",\"outline_subpixel\":") catch { _ => () }
  write_image_json(outline_subpixel_img)
  @stdio.stdout.write_sync(",\"color_outline_alpha\":") catch { _ => () }
  write_image_json(color_outline_img)
  @stdio.stdout.write_sync(",\"bitmap_best_fit\":") catch { _ => () }
  write_image_json(bitmap_img)
  @stdio.stdout.write_sync(",\"color_bitmap_best_fit\":") catch { _ => () }
  write_image_json(color_bitmap_img)
  @stdio.stdout.write_sync("}}") catch { _ => () }

  @stdio.stdout.write_sync("}") catch { _ => () }
  true
}

///|
fn run() -> Unit {
  let args = Some(@wasi.args_get()) catch { _ => None }
  if args is None {
    @stdio.stderr.write_sync("error: failed to read args\n") catch { _ => () }
    @wasi.proc_exit(1)
  }
  let args = args.unwrap()
  if args.length() < 3 {
    @stdio.stderr.write_sync("usage: moon_swash_dump <font_path> <text> [size]\n") catch { _ => () }
    @wasi.proc_exit(2)
  }
  fn env_debug_enabled() -> Bool {
    let envs = Some(@wasi.environ_get()) catch { _ => None }
    match envs {
      None => false
      Some(envs) => {
        for kv in envs {
          let k = kv.0
          let v = kv.1
          if k == "MOON_SWASH_DUMP_DEBUG" && v == "1" {
            return true
          }
        }
        false
      }
    }
  }
  let font_path = args[1]
  let text = args[2]
  let size = if args.length() >= 4 {
    parse_size(args[3]).unwrap_or(14.0)
  } else {
    14.0
  }
  // Debug helpers: keep output stable; only emit when explicitly enabled.
  if env_debug_enabled() {
    @stdio.stderr.write_sync("debug: font_path=\{font_path}\n") catch { _ => () }
    @stdio.stderr.write_sync("debug: text=\{text}\n") catch { _ => () }
    @stdio.stderr.write_sync("debug: size=\{size}\n") catch { _ => () }
    let resolved = Some(@fs.resolve_path(font_path)) catch { _ => None }
    match resolved {
      None => @stdio.stderr.write_sync("debug: resolve_path failed\n") catch { _ => () }
      Some((fd, rel)) =>
        @stdio.stderr.write_sync("debug: resolve_path fd=\{fd.0} rel=\{rel}\n") catch { _ => () }
    }
  }
  let ok = dump_and_write_json(font_path, text, size)
  if !ok {
    @stdio.stderr.write_sync("error: failed to load font\n") catch { _ => () }
    @wasi.proc_exit(1)
  }
  @stdio.stdout.write_sync("\n") catch { _ => () }
}

fn main {
  run()
}
