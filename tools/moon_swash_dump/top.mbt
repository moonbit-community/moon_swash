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
/// WASI CLI that dumps a small JSON summary for diffing against swash-reference.

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
  let font = match @swash.FontRef::from_offset(bytes, 0) {
    None => return false
    Some(f) => f
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

  let outline = @scale.Outline::new()
  let outline_ok = if glyph_id == 0 {
    false
  } else {
    scaler.scale_outline_into(glyph_id, outline)
  }
  let (min_x, min_y, max_x, max_y) = if outline_ok {
    let b = @zeno.Bounds::from_points(outline.points())
    (
      f64_round3(b.min.x()),
      f64_round3(b.min.y()),
      f64_round3(b.max.x()),
      f64_round3(b.max.y()),
    )
  } else {
    (0.0, 0.0, 0.0, 0.0)
  }

  // JSON
  @stdio.stdout.write_sync("{") catch { _ => () }

  @stdio.stdout.write_sync("\"font\":{") catch { _ => () }
  @stdio.stdout.write_sync("\"path\":") catch { _ => () }
  write_json_escaped(font_path)
  let metrics = font.metrics([][:])
  @stdio.stdout.write_sync(",\"units_per_em\":") catch { _ => () }
  @stdio.stdout.write_sync(metrics.units_per_em.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"glyph_count\":") catch { _ => () }
  @stdio.stdout.write_sync(metrics.glyph_count.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"var_count\":") catch { _ => () }
  @stdio.stdout.write_sync(font.variations().len().to_string()) catch { _ => () }
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
  @stdio.stdout.write_sync("]},") catch { _ => () }

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
  @stdio.stdout.write_sync(",\"outline\":{") catch { _ => () }
  @stdio.stdout.write_sync("\"ok\":") catch { _ => () }
  @stdio.stdout.write_sync(outline_ok.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"layers\":") catch { _ => () }
  @stdio.stdout.write_sync(outline.len().to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"points\":") catch { _ => () }
  @stdio.stdout.write_sync(outline.points().length().to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"verbs\":") catch { _ => () }
  @stdio.stdout.write_sync(outline.verbs().length().to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",\"bounds\":[") catch { _ => () }
  @stdio.stdout.write_sync(min_x.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",") catch { _ => () }
  @stdio.stdout.write_sync(min_y.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",") catch { _ => () }
  @stdio.stdout.write_sync(max_x.to_string()) catch { _ => () }
  @stdio.stdout.write_sync(",") catch { _ => () }
  @stdio.stdout.write_sync(max_y.to_string()) catch { _ => () }
  @stdio.stdout.write_sync("]}}") catch { _ => () }

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
