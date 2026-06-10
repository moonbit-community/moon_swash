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
/// WASI CLI that shapes text and dumps an SVG composed from glyph outlines.
struct PlacedGlyph {
  advance : Double
  id : UInt16
  x_offset : Double
  y : Double
}

///|
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

///|
fn parse_script(s0 : String) -> (@swash.Script, String) {
  if s0 == "arabic" || s0 == "Arabic" || s0 == "arab" || s0 == "Arab" {
    (@swash.Script::Arabic, "Arabic")
  } else if s0 == "hebrew" || s0 == "Hebrew" || s0 == "hebr" || s0 == "Hebr" {
    (@swash.Script::Hebrew, "Hebrew")
  } else {
    (@swash.Script::Latin, "Latin")
  }
}

///|
fn parse_direction(s0 : String) -> (@shape.Direction, String) {
  if s0 == "rtl" || s0 == "RTL" || s0 == "right-to-left" || s0 == "RightToLeft" {
    (@shape.Direction::RightToLeft, "RightToLeft")
  } else {
    (@shape.Direction::LeftToRight, "LeftToRight")
  }
}

///|
fn f64_round3(x : Double) -> Double {
  (x * 1000.0).round() / 1000.0
}

///|
fn fmt_num(x : Double) -> String {
  f64_round3(x).to_string()
}

///|
fn parse_text_arg(text_arg : String) -> String? {
  if text_arg.length() >= 6 && text_arg[0:6] == "@file:" {
    let path = text_arg[6:text_arg.length()]
    Some(@miniio.read_text_file(path)) catch { _ => None }
  } else {
    Some(text_arg)
  }
}

///|
fn write_xml_escaped(s : String) -> Unit {
  for ch in s {
    match ch {
      '&' => @miniio.stdout.write_text("&amp;") catch { _ => () }
      '<' => @miniio.stdout.write_text("&lt;") catch { _ => () }
      '>' => @miniio.stdout.write_text("&gt;") catch { _ => () }
      '"' => @miniio.stdout.write_text("&quot;") catch { _ => () }
      '\'' => @miniio.stdout.write_text("&apos;") catch { _ => () }
      _ => @miniio.stdout.write_text(ch.to_string()) catch { _ => () }
    }
  }
}

///|
fn append_path_data(
  points : Array[@zeno.Vector],
  verbs : Array[@zeno.Verb],
  dx : Double,
  dy : Double,
) -> String {
  let mut out = ""
  let mut i = 0
  for v in verbs.iter() {
    match v {
      @zeno.Verb::MoveTo => {
        let p = points[i]
        i = i + 1
        out = "\{out}M\{fmt_num(p.x() + dx)} \{fmt_num(-(p.y() + dy))} "
      }
      @zeno.Verb::LineTo => {
        let p = points[i]
        i = i + 1
        out = "\{out}L\{fmt_num(p.x() + dx)} \{fmt_num(-(p.y() + dy))} "
      }
      @zeno.Verb::QuadTo => {
        let p0 = points[i]
        let p1 = points[i + 1]
        i = i + 2
        out = "\{out}Q\{fmt_num(p0.x() + dx)} \{fmt_num(-(p0.y() + dy))} \{fmt_num(p1.x() + dx)} \{fmt_num(-(p1.y() + dy))} "
      }
      @zeno.Verb::CurveTo => {
        let p0 = points[i]
        let p1 = points[i + 1]
        let p2 = points[i + 2]
        i = i + 3
        out = "\{out}C\{fmt_num(p0.x() + dx)} \{fmt_num(-(p0.y() + dy))} \{fmt_num(p1.x() + dx)} \{fmt_num(-(p1.y() + dy))} \{fmt_num(p2.x() + dx)} \{fmt_num(-(p2.y() + dy))} "
      }
      @zeno.Verb::Close => out = "\{out}Z "
    }
  }
  out
}

///|
fn dump_svg(
  font_path : String,
  text : String,
  size : Double,
  script : @swash.Script,
  script_name : String,
  direction : @shape.Direction,
  direction_name : String,
) -> Bool {
  let data = Some(@miniio.read_file(font_path)) catch { _ => None }
  if data is None {
    return false
  }
  let data = data.unwrap()
  let bytes = data.binary()
  let font = match @swash.FontRef::from_index(bytes, 0) {
    None => return false
    Some(f) => f
  }

  let shaper_cx = @shape.ShapeContext::ShapeContext()
  let shaper = shaper_cx
    .builder(font)
    .script(script)
    .direction(direction)
    .size(size)
    .build()
  shaper.add_str(text)

  let coords = shaper.normalized_coords().to_owned()

  let shaped : Array[PlacedGlyph] = []
  let mut total_advance = 0.0
  shaper.shape_with(fn(cluster) {
    for g in cluster.glyphs() {
      let adv = g.advance()
      shaped.push(PlacedGlyph::{
        id: g.id(),
        advance: adv,
        x_offset: g.x(),
        y: g.y(),
      })
      total_advance = total_advance + adv
    }
  })

  let placed : Array[PlacedGlyph] = []
  if direction == @shape.Direction::RightToLeft {
    let mut pen_x = total_advance
    for g in shaped.iter() {
      pen_x = pen_x - g.advance
      placed.push(PlacedGlyph::{
        id: g.id,
        advance: g.advance,
        x_offset: pen_x + g.x_offset,
        y: g.y,
      })
    }
  } else {
    let mut pen_x = 0.0
    for g in shaped.iter() {
      placed.push(PlacedGlyph::{
        id: g.id,
        advance: g.advance,
        x_offset: pen_x + g.x_offset,
        y: g.y,
      })
      pen_x = pen_x + g.advance
    }
  }

  let scale_cx = @scale.ScaleContext::ScaleContext()
  let scaler = scale_cx
    .builder(font)
    .size(size)
    .hint(false)
    .normalized_coords(coords)
    .build()

  let paths : Array[String] = []
  let mut has_bounds = false
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0

  for pg in placed.iter() {
    if pg.id == 0 {
      continue
    }
    let outline = @scale.Outline::Outline()
    if !scaler.scale_outline_into(pg.id, outline) {
      continue
    }
    let points = outline.points()
    if points.length() == 0 {
      continue
    }
    let verbs = outline.verbs()
    paths.push(append_path_data(points, verbs, pg.x_offset, pg.y))
    for p in points.iter() {
      let x = p.x() + pg.x_offset
      let y = -(p.y() + pg.y)
      if !has_bounds {
        min_x = x
        max_x = x
        min_y = y
        max_y = y
        has_bounds = true
      } else {
        if x < min_x {
          min_x = x
        }
        if x > max_x {
          max_x = x
        }
        if y < min_y {
          min_y = y
        }
        if y > max_y {
          max_y = y
        }
      }
    }
  }

  if !has_bounds {
    min_x = 0.0
    min_y = -size
    max_x = if total_advance > 1.0 { total_advance } else { 1.0 }
    max_y = 0.0
  }

  let pad = if size * 0.2 > 2.0 { size * 0.2 } else { 2.0 }
  let view_x = min_x - pad
  let view_y = min_y - pad
  let view_w = max_x - min_x + pad * 2.0
  let view_h = max_y - min_y + pad * 2.0

  @miniio.stdout.write_text("<svg xmlns=\"http://www.w3.org/2000/svg\" ") catch {
    _ => ()
  }
  @miniio.stdout.write_text("viewBox=\"") catch {
    _ => ()
  }
  @miniio.stdout.write_text(fmt_num(view_x)) catch {
    _ => ()
  }
  @miniio.stdout.write_text(" ") catch {
    _ => ()
  }
  @miniio.stdout.write_text(fmt_num(view_y)) catch {
    _ => ()
  }
  @miniio.stdout.write_text(" ") catch {
    _ => ()
  }
  @miniio.stdout.write_text(fmt_num(view_w)) catch {
    _ => ()
  }
  @miniio.stdout.write_text(" ") catch {
    _ => ()
  }
  @miniio.stdout.write_text(fmt_num(view_h)) catch {
    _ => ()
  }
  @miniio.stdout.write_text("\">\n") catch {
    _ => ()
  }

  @miniio.stdout.write_text("  <desc>") catch {
    _ => ()
  }
  @miniio.stdout.write_text("font=") catch {
    _ => ()
  }
  write_xml_escaped(font_path)
  @miniio.stdout.write_text("; text=") catch {
    _ => ()
  }
  write_xml_escaped(text)
  @miniio.stdout.write_text("; size=") catch {
    _ => ()
  }
  @miniio.stdout.write_text(fmt_num(size)) catch {
    _ => ()
  }
  @miniio.stdout.write_text("; script=") catch {
    _ => ()
  }
  @miniio.stdout.write_text(script_name) catch {
    _ => ()
  }
  @miniio.stdout.write_text("; direction=") catch {
    _ => ()
  }
  @miniio.stdout.write_text(direction_name) catch {
    _ => ()
  }
  @miniio.stdout.write_text("; shaped_glyphs=") catch {
    _ => ()
  }
  @miniio.stdout.write_text(placed.length().to_string()) catch {
    _ => ()
  }
  @miniio.stdout.write_text("; outlined_paths=") catch {
    _ => ()
  }
  @miniio.stdout.write_text(paths.length().to_string()) catch {
    _ => ()
  }
  @miniio.stdout.write_text("</desc>\n") catch {
    _ => ()
  }

  @miniio.stdout.write_text("  <rect x=\"") catch {
    _ => ()
  }
  @miniio.stdout.write_text(fmt_num(view_x)) catch {
    _ => ()
  }
  @miniio.stdout.write_text("\" y=\"") catch {
    _ => ()
  }
  @miniio.stdout.write_text(fmt_num(view_y)) catch {
    _ => ()
  }
  @miniio.stdout.write_text("\" width=\"") catch {
    _ => ()
  }
  @miniio.stdout.write_text(fmt_num(view_w)) catch {
    _ => ()
  }
  @miniio.stdout.write_text("\" height=\"") catch {
    _ => ()
  }
  @miniio.stdout.write_text(fmt_num(view_h)) catch {
    _ => ()
  }
  @miniio.stdout.write_text("\" fill=\"white\"/>\n") catch {
    _ => ()
  }

  @miniio.stdout.write_text("  <g fill=\"#111\" fill-rule=\"nonzero\">\n") catch {
    _ => ()
  }
  for p in paths.iter() {
    @miniio.stdout.write_text("    <path d=\"") catch {
      _ => ()
    }
    @miniio.stdout.write_text(p) catch {
      _ => ()
    }
    @miniio.stdout.write_text("\"/>\n") catch {
      _ => ()
    }
  }
  @miniio.stdout.write_text("  </g>\n") catch {
    _ => ()
  }
  @miniio.stdout.write_text("</svg>\n") catch {
    _ => ()
  }
  true
}

///|
fn run() -> Unit {
  let args = Some(@miniio.args_get()) catch { _ => None }
  if args is None {
    @miniio.stderr.write_text("error: failed to read args\n") catch {
      _ => ()
    }
    @miniio.exit(1)
  }
  let args = args.unwrap()
  if args.length() < 3 {
    @miniio.stderr.write_text(
      "usage: moon_swash_svg_dump <font_path> <text> [size] [script] [direction]\n",
    ) catch {
      _ => ()
    }
    @miniio.stderr.write_text(
      "example: moon_swash_svg_dump .private/fonts/SFArabic-37c57b4a237b.ttf \"السَّلَامُ عَلَيْكُمْ\" 18 arabic rtl > out.svg\n",
    ) catch {
      _ => ()
    }
    @miniio.stderr.write_text(
      "text also supports @file:<path>, e.g. @file:input.txt\n",
    ) catch {
      _ => ()
    }
    @miniio.exit(2)
  }

  let font_path = args[1]
  let text = match parse_text_arg(args[2]) {
    Some(v) => v
    None => {
      @miniio.stderr.write_text("error: failed to read text input\n") catch {
        _ => ()
      }
      @miniio.exit(2)
      ""
    }
  }
  let size = if args.length() >= 4 {
    parse_size(args[3]).unwrap_or(14.0)
  } else {
    14.0
  }
  let script_arg = if args.length() >= 5 { args[4] } else { "latin" }
  let direction_arg = if args.length() >= 6 { args[5] } else { "ltr" }
  let (script, script_name) = parse_script(script_arg)
  let (direction, direction_name) = parse_direction(direction_arg)

  if dump_svg(
      font_path, text, size, script, script_name, direction, direction_name,
    ) {
    ()
  } else {
    @miniio.stderr.write_text("error: failed to produce svg\n") catch {
      _ => ()
    }
    @miniio.exit(1)
  }
}

///|
fn main {
  run()
}
