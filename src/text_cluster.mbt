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
/// Script-aware cluster segmentation.
///
/// Ported from `swash/src/text/cluster/*` (swash is dual-licensed Apache-2.0 OR MIT).

///|
/// Arbitrary user data that can be associated with a character throughout
/// the shaping pipeline.
pub type UserData = UInt

///|
/// Boundary type of a character or cluster.
pub(all) enum Boundary {
  None
  Word
  Line
  Mandatory
}

///|
fn boundary_from_raw(raw : UInt) -> Boundary {
  match raw & 0b11U {
    0U => None
    1U => Word
    2U => Line
    _ => Mandatory
  }
}

///|
fn boundary_to_raw(boundary : Boundary) -> UInt {
  match boundary {
    None => 0U
    Word => 1U
    Line => 2U
    Mandatory => 3U
  }
}

///|
/// Information about a character including unicode properties and boundary
/// analysis.
struct CharInfo {
  props : Properties
}

///|
pub fn CharInfo::CharInfo(
  properties : Properties,
  boundary : Boundary,
) -> CharInfo {
  { props: properties.with_boundary(boundary_to_raw(boundary)), }
}

///|
pub fn CharInfo::properties(self : CharInfo) -> Properties {
  self.props
}

///|
pub fn CharInfo::boundary(self : CharInfo) -> Boundary {
  boundary_from_raw(self.props.boundary())
}

///|
fn CharInfo::boundary_raw(self : CharInfo) -> UInt {
  self.props.boundary()
}

///|
fn CharInfo::with_properties(self : CharInfo, props : Properties) -> CharInfo {
  { props: props.with_boundary(self.props.boundary()), }
}

///|
pub fn CharInfo::category(self : CharInfo) -> Category {
  self.props.category()
}

///|
pub fn CharInfo::joining_type(self : CharInfo) -> JoiningType {
  self.props.joining_type()
}

///|
pub fn CharInfo::cluster_break(self : CharInfo) -> ClusterBreak {
  self.props.cluster_break()
}

///|
pub fn CharInfo::is_ignorable(self : CharInfo) -> Bool {
  self.props.is_ignorable()
}

///|
pub fn CharInfo::is_variation_selector(self : CharInfo) -> Bool {
  self.props.is_variation_selector()
}

///|
pub fn CharInfo::contributes_to_shaping(self : CharInfo) -> Bool {
  self.props.contributes_to_shaping()
}

///|
pub fn CharInfo::use_class(self : CharInfo) -> (UseClass, Bool, Bool) {
  self.props.use_class()
}

///|
pub fn CharInfo::myanmar_class(self : CharInfo) -> (MyanmarClass, Bool) {
  self.props.myanmar_class()
}

///|
pub fn CharInfo::cluster_class(self : CharInfo) -> (ClusterBreak, Bool) {
  self.props.cluster_class()
}

///|
pub fn CharInfo::from_char(ch : Char) -> CharInfo {
  { props: Codepoint::properties(ch), }
}

///|
pub fn CharInfo::default() -> CharInfo {
  CharInfo::from_char('\u{0000}')
}

///|
const BOUND_SHIFT : Int = 14

///|
const SPACE_SHIFT : Int = 1

///|
const EMOJI_SHIFT : Int = 8

///|
const INFO_MASK_ALL : UInt = 0xFFFFU

///|
const INFO_LO_MASK : UInt = 0x3FFFU

///|
const SPACE_MASK : UInt = 0b111U

///|
const EMOJI_MASK : UInt = 0b11U

///|
/// Information about a cluster including content properties and boundary analysis.
struct ClusterInfo {
  bits : UInt
}

///|

///|
fn ClusterInfo::ClusterInfo(bits : UInt) -> ClusterInfo {
  { bits, }
}

///|
pub fn ClusterInfo::is_broken(self : ClusterInfo) -> Bool {
  (self.bits & 1U) != 0U
}

///|
pub fn ClusterInfo::is_emoji(self : ClusterInfo) -> Bool {
  ((self.bits >> EMOJI_SHIFT) & EMOJI_MASK) != 0U
}

///|
pub fn ClusterInfo::emoji(self : ClusterInfo) -> Emoji {
  emoji_from_raw((self.bits >> EMOJI_SHIFT) & EMOJI_MASK)
}

///|
pub fn ClusterInfo::is_whitespace(self : ClusterInfo) -> Bool {
  ((self.bits >> SPACE_SHIFT) & SPACE_MASK) != 0U
}

///|
pub fn ClusterInfo::whitespace(self : ClusterInfo) -> Whitespace {
  whitespace_from_raw((self.bits >> SPACE_SHIFT) & SPACE_MASK)
}

///|
pub fn ClusterInfo::is_boundary(self : ClusterInfo) -> Bool {
  self.bits >> BOUND_SHIFT != 0U
}

///|
pub fn ClusterInfo::boundary(self : ClusterInfo) -> Boundary {
  boundary_from_raw(self.bits >> BOUND_SHIFT)
}

///|
/// Presentation mode for an emoji cluster.
pub(all) enum Emoji {
  None
  Default
  Text
  Color
}

///|
fn emoji_from_raw(bits : UInt) -> Emoji {
  match bits & 0b11U {
    0U => None
    1U => Default
    2U => Text
    _ => Color
  }
}

///|
fn emoji_to_raw(e : Emoji) -> UInt {
  match e {
    None => 0U
    Default => 1U
    Text => 2U
    Color => 3U
  }
}

///|
/// Whitespace content of a cluster.
pub(all) enum Whitespace {
  None
  Space
  NoBreakSpace
  Tab
  Newline
  Other
}

///|
pub fn Whitespace::is_space_or_nbsp(self : Whitespace) -> Bool {
  match self {
    Space => true
    NoBreakSpace => true
    _ => false
  }
}

///|
fn whitespace_from_raw(bits : UInt) -> Whitespace {
  match bits & 0b111U {
    0U => None
    1U => Space
    2U => NoBreakSpace
    3U => Tab
    4U => Newline
    5U => Other
    _ => None
  }
}

///|
fn whitespace_to_raw(space : Whitespace) -> UInt {
  match space {
    None => 0U
    Space => 1U
    NoBreakSpace => 2U
    Tab => 3U
    Newline => 4U
    Other => 5U
  }
}

///|
/// Character input to the cluster parser.
struct Token {
  ch : Char
  offset : UInt
  len : UInt
  info : CharInfo
  data : UserData
}

///|
pub fn Token::Token(
  ch : Char,
  offset : UInt,
  len : UInt,
  info : CharInfo,
  data : UserData,
) -> Token {
  { ch, offset, len, info, data, }
}

///|
pub fn Token::default() -> Token {
  { ch: '\u{0000}', offset: 0U, len: 1U, info: CharInfo::default(), data: 0U, }
}

///|
pub fn Token::ch(self : Token) -> Char {
  self.ch
}

///|
pub fn Token::offset(self : Token) -> UInt {
  self.offset
}

///|
pub fn Token::len(self : Token) -> UInt {
  self.len
}

///|
pub fn Token::info(self : Token) -> CharInfo {
  self.info
}

///|
pub fn Token::data(self : Token) -> UserData {
  self.data
}

///|
/// Shaping class of a character.
pub(all) enum ShapeClass {
  Reph
  Pref
  Kinzi
  Base
  Mark
  Halant
  MedialRa
  VMPre
  VPre
  VBlw
  Anusvara
  Zwj
  Zwnj
  Control
  Vs
  Other
}

///|
/// Character output from the cluster parser.
struct ClusterChar {
  mut ch : Char
  offset : UInt
  shape_class : ShapeClass
  joining_type : JoiningType
  ignorable : Bool
  contributes_to_shaping : Bool
  mut glyph_id : GlyphId
  data : UserData
}

///|
pub fn ClusterChar::ClusterChar(
  ch : Char,
  offset : UInt,
  shape_class : ShapeClass,
  joining_type : JoiningType,
  ignorable : Bool,
  contributes_to_shaping : Bool,
  glyph_id : GlyphId,
  data : UserData,
) -> ClusterChar {
  {
    ch,
    offset,
    shape_class,
    joining_type,
    ignorable,
    contributes_to_shaping,
    glyph_id,
    data,
  }
}

///|
pub fn ClusterChar::ch(self : ClusterChar) -> Char {
  self.ch
}

///|
pub fn ClusterChar::offset(self : ClusterChar) -> UInt {
  self.offset
}

///|
pub fn ClusterChar::shape_class(self : ClusterChar) -> ShapeClass {
  self.shape_class
}

///|
pub fn ClusterChar::joining_type(self : ClusterChar) -> JoiningType {
  self.joining_type
}

///|
pub fn ClusterChar::is_ignorable(self : ClusterChar) -> Bool {
  self.ignorable
}

///|
pub fn ClusterChar::contributes_to_shaping(self : ClusterChar) -> Bool {
  self.contributes_to_shaping
}

///|
pub fn ClusterChar::glyph_id(self : ClusterChar) -> GlyphId {
  self.glyph_id
}

///|
pub fn ClusterChar::data(self : ClusterChar) -> UserData {
  self.data
}

///|
/// Iterative status of mapping a character cluster to nominal glyph identifiers.
pub(all) enum Status {
  Discard
  Keep
  Complete
}

///|
/// Source range of a cluster in code units.
struct SourceRange {
  start : UInt
  end : UInt
}

///|
pub fn SourceRange::SourceRange(start : UInt, end : UInt) -> SourceRange {
  { start, end, }
}

///|
pub fn SourceRange::start(self : SourceRange) -> UInt {
  self.start
}

///|
pub fn SourceRange::end(self : SourceRange) -> UInt {
  self.end
}

///|
/// The maximum number of characters in a single cluster.
pub const MAX_CLUSTER_SIZE : Int = 32

///|
priv enum FormKind {
  Original
  Nfd
  Nfc
}

///|
priv enum FormState {
  None
  Valid
  Invalid
}

///|
priv struct Form {
  chars : Array[ClusterChar]
  mut map_len : Int
  mut state : FormState
}

///|

///|
fn Form::Form() -> Form {
  { chars: ([] : Array[ClusterChar]), map_len: 0, state: None, }
}

///|
fn Form::clear(self : Form) -> Unit {
  self.chars.clear()
  self.map_len = 0
  self.state = None
}

///|
fn Form::setup(self : Form) -> Unit {
  let mut count = 0
  for c in self.chars.iter() {
    match c.shape_class {
      Control => ()
      _ => count = count + 1
    }
  }
  self.map_len = if count > 0 { count } else { 1 }
}

///|
fn mapper_map(
  chars : Array[ClusterChar],
  map_len : Int,
  f : (Char) -> GlyphId,
  glyphs : Array[GlyphId],
  best_ratio : Double,
) -> Double {
  if map_len == 0 {
    return 1.0
  }
  let mut mapped = 0
  let n = chars.length()
  for i in 0..<n {
    let c = chars[i]
    if !c.contributes_to_shaping {
      let gid = f(c.ch)
      glyphs[i] = gid
      if map_len == 1 {
        mapped = mapped + 1
      }
    } else {
      let gid = f(c.ch)
      glyphs[i] = gid
      if gid != (0).to_uint16() {
        mapped = mapped + 1
      }
    }
  }
  let ratio = mapped.to_double() / map_len.to_double()
  if ratio > best_ratio {
    for i in 0..<n {
      chars[i].glyph_id = glyphs[i]
    }
  }
  ratio
}

///|
fn Form::map(
  self : Form,
  f : (Char) -> GlyphId,
  glyphs : Array[GlyphId],
  best_ratio : Double,
) -> Double {
  mapper_map(self.chars, self.map_len, f, glyphs, best_ratio)
}

///|
/// Character cluster; output from the parser and input to the shaper.
struct CharCluster {
  mut info_bits : UInt
  chars : Array[ClusterChar]
  mut map_len : Int
  mut start : UInt
  mut end : UInt
  mut force_normalize : Bool
  comp : Form
  decomp : Form
  mut form : FormKind
  mut best_ratio : Double
}

///|
pub fn CharCluster::CharCluster() -> CharCluster {
  {
    info_bits: 0U,
    chars: ([] : Array[ClusterChar]),
    map_len: 0,
    start: 0U,
    end: 0U,
    force_normalize: false,
    comp: Form(),
    decomp: Form(),
    form: Original,
    best_ratio: 0.0,
  }
}

///|
pub fn CharCluster::info(self : CharCluster) -> ClusterInfo {
  ClusterInfo(self.info_bits)
}

///|
pub fn CharCluster::user_data(self : CharCluster) -> UserData {
  if self.chars.length() == 0 {
    0U
  } else {
    self.chars[0].data
  }
}

///|
pub fn CharCluster::range(self : CharCluster) -> SourceRange {
  { start: self.start, end: self.end, }
}

///|
pub fn CharCluster::is_empty(self : CharCluster) -> Bool {
  self.chars.length() == 0
}

///|
pub fn CharCluster::chars(self : CharCluster) -> ArrayView[ClusterChar] {
  self.chars[:]
}

///|
pub fn CharCluster::mapped_chars(self : CharCluster) -> ArrayView[ClusterChar] {
  match self.form {
    Original => self.chars[:]
    Nfd => self.decomp.chars[:]
    Nfc => self.comp.chars[:]
  }
}

///|
pub fn CharCluster::map(self : CharCluster, f : (Char) -> GlyphId) -> Status {
  let len = self.chars.length()
  if len == 0 {
    return Complete
  }
  let glyph_ids : Array[GlyphId] = Array::makei(MAX_CLUSTER_SIZE, _ => {
    (0).to_uint16()
  })
  let prev_ratio = self.best_ratio
  if self.force_normalize {
    match CharCluster::composed(self) {
      None => ()
      Some(_) => {
        let ratio = self.comp.map(f, glyph_ids, self.best_ratio)
        if ratio > self.best_ratio {
          self.best_ratio = ratio
          self.form = Nfc
          if ratio >= 1.0 {
            return Complete
          }
        }
      }
    }
  }
  let map_len = if self.map_len > 0 { self.map_len } else { 1 }
  let ratio = mapper_map(self.chars, map_len, f, glyph_ids, self.best_ratio)
  if ratio > self.best_ratio {
    self.best_ratio = ratio
    self.form = Original
    if ratio >= 1.0 {
      return Complete
    }
  }
  if len > 1 {
    match CharCluster::decomposed(self) {
      None => ()
      Some(_) => {
        let ratio = self.decomp.map(f, glyph_ids, self.best_ratio)
        if ratio > self.best_ratio {
          self.best_ratio = ratio
          self.form = Nfd
          if ratio >= 1.0 {
            return Complete
          }
        }
        if !self.force_normalize {
          match CharCluster::composed(self) {
            None => ()
            Some(_) => {
              let ratio = self.comp.map(f, glyph_ids, self.best_ratio)
              if ratio > self.best_ratio {
                self.best_ratio = ratio
                self.form = Nfc
                if ratio >= 1.0 {
                  return Complete
                }
              }
            }
          }
        }
      }
    }
  }
  if self.best_ratio > prev_ratio {
    Keep
  } else {
    Discard
  }
}

///|
pub fn CharCluster::clear(self : CharCluster) -> Unit {
  self.info_bits = 0U
  self.chars.clear()
  self.map_len = 0
  self.start = 0U
  self.end = 0U
  self.force_normalize = false
  self.comp.clear()
  self.decomp.clear()
  self.form = Original
  self.best_ratio = 0.0
}

///|
fn CharCluster::set_broken(self : CharCluster) -> Unit {
  self.info_bits = self.info_bits | 1U
}

///|
fn CharCluster::set_emoji(self : CharCluster, emoji : Emoji) -> Unit {
  let mask = EMOJI_MASK << EMOJI_SHIFT
  let bits = self.info_bits & (INFO_MASK_ALL ^ mask)
  self.info_bits = bits | (emoji_to_raw(emoji) << EMOJI_SHIFT)
}

///|
fn CharCluster::set_space(self : CharCluster, space : Whitespace) -> Unit {
  let mask = SPACE_MASK << SPACE_SHIFT
  let bits = self.info_bits & (INFO_MASK_ALL ^ mask)
  self.info_bits = bits | (whitespace_to_raw(space) << SPACE_SHIFT)
}

///|
fn CharCluster::set_space_from_char(self : CharCluster, ch : Char) -> Unit {
  match ch {
    ' ' => self.set_space(Space)
    '\u{00A0}' => self.set_space(NoBreakSpace)
    '\t' => self.set_space(Tab)
    _ => ()
  }
}

///|
fn CharCluster::merge_boundary(self : CharCluster, boundary : UInt) -> Unit {
  let cur = self.info_bits >> BOUND_SHIFT
  let merged = if cur > boundary { cur } else { boundary }
  self.info_bits = (self.info_bits & INFO_LO_MASK) | (merged << BOUND_SHIFT)
}

///|
fn CharCluster::force_normalize(self : CharCluster) -> Unit {
  self.force_normalize = true
}

///|
fn CharCluster::push(
  self : CharCluster,
  input : Token,
  class : ShapeClass,
) -> Unit {
  let contributes_to_shaping = input.info.contributes_to_shaping()
  let c = ClusterChar::{
    ch: input.ch,
    shape_class: class,
    joining_type: input.info.joining_type(),
    ignorable: input.info.is_ignorable(),
    contributes_to_shaping,
    glyph_id: (0).to_uint16(),
    offset: input.offset,
    data: input.data,
  }
  if self.chars.length() == 0 {
    self.start = input.offset
  }
  self.merge_boundary(input.info.boundary_raw())
  self.end = input.offset + input.len
  self.chars.push(c)
  if contributes_to_shaping {
    self.map_len = self.map_len + 1
  }
}

///|
fn CharCluster::note_char(self : CharCluster, input : Token) -> Unit {
  if self.chars.length() == 0 {
    self.start = input.offset
  }
  self.merge_boundary(input.info.boundary_raw())
  self.end = input.offset + input.len
}

///|
fn CharCluster::decomposed(self : CharCluster) -> ArrayView[ClusterChar]? {
  match self.decomp.state {
    Invalid => None
    Valid => Some(self.decomp.chars[:])
    None => {
      self.decomp.state = Invalid
      self.decomp.chars.clear()
      for ch in self.chars.iter() {
        for c in Codepoint::decompose(ch.ch) {
          if self.decomp.chars.length() == MAX_CLUSTER_SIZE {
            return None
          }
          let copy = ClusterChar::{
            ch: c,
            offset: ch.offset,
            shape_class: ch.shape_class,
            joining_type: ch.joining_type,
            ignorable: ch.ignorable,
            contributes_to_shaping: ch.contributes_to_shaping,
            glyph_id: ch.glyph_id,
            data: ch.data,
          }
          self.decomp.chars.push(copy)
        }
      }
      if self.decomp.chars.length() == 0 {
        return None
      }
      self.decomp.state = Valid
      self.decomp.setup()
      Some(self.decomp.chars[:])
    }
  }
}

///|
fn CharCluster::composed(self : CharCluster) -> ArrayView[ClusterChar]? {
  match self.comp.state {
    Invalid => None
    Valid => Some(self.comp.chars[:])
    None =>
      match CharCluster::decomposed(self) {
        None => {
          self.comp.state = Invalid
          None
        }
        Some(d) => {
          if d.length() == 0 {
            self.comp.state = Invalid
            return None
          }
          self.comp.state = Invalid
          self.comp.chars.clear()
          let mut last = self.decomp.chars[0]
          let n = self.decomp.chars.length()
          for i in 1..<n {
            let ch = self.decomp.chars[i]
            match compose_pair(last.ch, ch.ch) {
              None => {
                self.comp.chars.push(last)
                last = ch
              }
              Some(comp) => last.ch = comp
            }
          }
          self.comp.chars.push(last)
          self.comp.state = Valid
          self.comp.setup()
          Some(self.comp.chars[:])
        }
      }
  }
}

///|
priv struct TokenStream {
  iter : Iter[Token]
  mut buf : Array[Token]
  mut buf_offset : Int
  mut done : Bool
}

///|

///|
fn TokenStream::TokenStream(iter : Iter[Token]) -> TokenStream {
  { iter, buf: ([] : Array[Token]), buf_offset: 0, done: false, }
}

///|
fn TokenStream::fill_to(self : TokenStream, n : Int) -> Unit {
  while !self.done && self.buf_offset + n >= self.buf.length() {
    match self.iter.next() {
      None => {
        self.done = true
        return
      }
      Some(t) => self.buf.push(t)
    }
  }
}

///|
fn TokenStream::peek(self : TokenStream, n : Int) -> Token? {
  self.fill_to(n)
  let ix = self.buf_offset + n
  if ix >= 0 && ix < self.buf.length() {
    Some(self.buf[ix])
  } else {
    None
  }
}

///|
fn TokenStream::next(self : TokenStream) -> Token? {
  self.fill_to(0)
  if self.buf_offset < self.buf.length() {
    let t = self.buf[self.buf_offset]
    self.buf_offset = self.buf_offset + 1
    if self.buf_offset > 16 {
      let remain = self.buf.length() - self.buf_offset
      let new_buf : Array[Token] = Array::makei(remain, i => {
        self.buf[self.buf_offset + i]
      })
      self.buf = new_buf
      self.buf_offset = 0
    }
    Some(t)
  } else {
    None
  }
}

///|
priv struct SimpleState {
  chars : TokenStream
  mut cur : Token
  mut cur_kind : ClusterBreak
  mut cur_emoji : Bool
  mut done : Bool
}

///|

///|
fn SimpleState::SimpleState(chars : Iter[Token]) -> SimpleState {
  let stream = TokenStream::TokenStream(chars)
  match stream.next() {
    None =>
      {
        chars: stream,
        cur: Token::default(),
        cur_kind: XX,
        cur_emoji: false,
        done: true,
      }
    Some(first) => {
      let (kind, emoji) = first.info.cluster_class()
      {
        chars: stream,
        cur: first,
        cur_kind: kind,
        cur_emoji: emoji,
        done: false,
      }
    }
  }
}

///|
fn SimpleState::next(self : SimpleState, cluster : CharCluster) -> Bool {
  if self.done {
    return false
  }
  simple_parse(self, cluster) |> ignore
  true
}

///|
fn cluster_break_index(kind : ClusterBreak) -> Int {
  match kind {
    CN => 0
    CR => 1
    EX => 2
    L => 3
    LF => 4
    LV => 5
    LVT => 6
    PP => 7
    RI => 8
    SM => 9
    T => 10
    V => 11
    XX => 12
    ZWJ => 13
  }
}

///|
fn cluster_break_eq(a : ClusterBreak, b : ClusterBreak) -> Bool {
  cluster_break_index(a) == cluster_break_index(b)
}

///|
fn simple_accept(
  s : SimpleState,
  cluster : CharCluster,
  kind : ClusterBreak,
) -> Bool? {
  if cluster_break_eq(s.cur_kind, kind) {
    match simple_accept_any(s, cluster) {
      None => None
      Some(_) => Some(true)
    }
  } else {
    Some(false)
  }
}

///|
fn simple_accept_as(
  s : SimpleState,
  cluster : CharCluster,
  kind : ClusterBreak,
  as_class : ShapeClass,
) -> Bool? {
  if cluster_break_eq(s.cur_kind, kind) {
    match simple_accept_any_as(s, cluster, as_class) {
      None => None
      Some(_) => Some(true)
    }
  } else {
    Some(false)
  }
}

///|
fn simple_accept_any(s : SimpleState, cluster : CharCluster) -> Unit? {
  cluster.push(s.cur, Base)
  match simple_advance(s, cluster) {
    None => None
    Some(_) => Some(())
  }
}

///|
fn simple_accept_any_as(
  s : SimpleState,
  cluster : CharCluster,
  as_class : ShapeClass,
) -> Unit? {
  cluster.push(s.cur, as_class)
  match simple_advance(s, cluster) {
    None => None
    Some(_) => Some(())
  }
}

///|
fn simple_advance(s : SimpleState, cluster : CharCluster) -> Unit? {
  if cluster.chars.length() == MAX_CLUSTER_SIZE {
    return None
  }
  match s.chars.next() {
    None => {
      s.done = true
      None
    }
    Some(input) => {
      let (kind, emoji) = input.info.cluster_class()
      s.cur = input
      s.cur_emoji = emoji
      s.cur_kind = kind
      Some(())
    }
  }
}

///|
fn simple_parse_emoji_extension(
  s : SimpleState,
  cluster : CharCluster,
) -> Bool? {
  while true {
    if cluster_break_eq(s.cur_kind, EX) {
      match s.cur.ch.to_int() {
        0x200C =>
          match simple_accept_any_as(s, cluster, Zwnj) {
            None => return None
            Some(_) => ()
          }
        0xFE0F => {
          cluster.set_emoji(Color)
          cluster.note_char(s.cur)
          match simple_advance(s, cluster) {
            None => return None
            Some(_) => ()
          }
        }
        0xFE0E => {
          cluster.set_emoji(Text)
          cluster.note_char(s.cur)
          match simple_advance(s, cluster) {
            None => return None
            Some(_) => ()
          }
        }
        _ =>
          match simple_accept_any_as(s, cluster, Mark) {
            None => return None
            Some(_) => ()
          }
      }
    } else if cluster_break_eq(s.cur_kind, ZWJ) {
      match simple_accept_any_as(s, cluster, Zwj) {
        None => return None
        Some(_) => ()
      }
      return Some(true)
    } else {
      break
    }
  }
  Some(false)
}

///|
fn simple_parse_extension(s : SimpleState, cluster : CharCluster) -> Bool? {
  if cluster_break_eq(s.cur_kind, EX) {
    if s.cur.ch.to_int() == 0x200C {
      match simple_accept_any_as(s, cluster, Zwnj) {
        None => return None
        Some(_) => ()
      }
    } else if s.cur.info.is_variation_selector() {
      match simple_accept_any_as(s, cluster, Vs) {
        None => return None
        Some(_) => ()
      }
    } else {
      cluster.force_normalize()
      match simple_accept_any_as(s, cluster, Mark) {
        None => return None
        Some(_) => ()
      }
    }
    Some(true)
  } else if cluster_break_eq(s.cur_kind, SM) {
    cluster.force_normalize()
    match simple_accept_any_as(s, cluster, Mark) {
      None => return None
      Some(_) => ()
    }
    Some(true)
  } else if cluster_break_eq(s.cur_kind, ZWJ) {
    match simple_accept_any_as(s, cluster, Zwj) {
      None => return None
      Some(_) => ()
    }
    Some(true)
  } else {
    Some(false)
  }
}

///|
fn simple_parse(s : SimpleState, cluster : CharCluster) -> Unit? {
  while true {
    match simple_accept(s, cluster, PP) {
      None => return None
      Some(true) => ()
      Some(false) => break
    }
  }
  if s.cur_emoji {
    cluster.set_emoji(Default)
    while s.cur_emoji {
      match simple_accept_any_as(s, cluster, Base) {
        None => return None
        Some(_) => ()
      }
      match simple_parse_emoji_extension(s, cluster) {
        None => return None
        Some(true) => ()
        Some(false) => break
      }
    }
  } else {
    match s.cur_kind {
      CN =>
        match simple_accept_any_as(s, cluster, Control) {
          None => return None
          Some(_) => ()
        }
      LF => {
        cluster.set_space(Newline)
        match simple_accept_any_as(s, cluster, Control) {
          None => return None
          Some(_) => ()
        }
      }
      CR => {
        cluster.set_space(Newline)
        match simple_accept_any_as(s, cluster, Control) {
          None => return None
          Some(_) => ()
        }
        match simple_accept_as(s, cluster, LF, Control) {
          None => return None
          Some(v) => v |> ignore
        }
      }
      L => {
        match simple_accept_any(s, cluster) {
          None => return None
          Some(_) => ()
        }
        match s.cur_kind {
          L =>
            match simple_accept_any(s, cluster) {
              None => return None
              Some(_) => ()
            }
          V =>
            match simple_accept_any(s, cluster) {
              None => return None
              Some(_) => ()
            }
          LV =>
            match simple_accept_any(s, cluster) {
              None => return None
              Some(_) => ()
            }
          LVT =>
            match simple_accept_any(s, cluster) {
              None => return None
              Some(_) => ()
            }
          _ => ()
        }
      }
      LV => {
        match simple_accept_any(s, cluster) {
          None => return None
          Some(_) => ()
        }
        match s.cur_kind {
          V =>
            match simple_accept_any(s, cluster) {
              None => return None
              Some(_) => ()
            }
          T =>
            match simple_accept_any(s, cluster) {
              None => return None
              Some(_) => ()
            }
          _ => ()
        }
      }
      V => {
        match simple_accept_any(s, cluster) {
          None => return None
          Some(_) => ()
        }
        match s.cur_kind {
          V =>
            match simple_accept_any(s, cluster) {
              None => return None
              Some(_) => ()
            }
          T =>
            match simple_accept_any(s, cluster) {
              None => return None
              Some(_) => ()
            }
          _ => ()
        }
      }
      LVT => {
        match simple_accept_any(s, cluster) {
          None => return None
          Some(_) => ()
        }
        match simple_accept(s, cluster, T) {
          None => return None
          Some(v) => v |> ignore
        }
      }
      T => {
        match simple_accept_any(s, cluster) {
          None => return None
          Some(_) => ()
        }
        match simple_accept(s, cluster, T) {
          None => return None
          Some(v) => v |> ignore
        }
      }
      RI =>
        match simple_accept(s, cluster, RI) {
          None => return None
          Some(v) => v |> ignore
        }
      EX => cluster.set_broken()
      SM => cluster.set_broken()
      ZWJ => cluster.set_broken()
      _ => {
        cluster.set_space_from_char(s.cur.ch)
        match simple_accept_any(s, cluster) {
          None => return None
          Some(_) => ()
        }
      }
    }
  }
  while true {
    match simple_parse_extension(s, cluster) {
      None => return None
      Some(true) => ()
      Some(false) => break
    }
  }
  Some(())
}

///|
fn UseClass::to_shape_class(self : UseClass) -> ShapeClass {
  match self {
    B => Base
    H => Halant
    VPre => VPre
    VMPre => VMPre
    VBlw => VBlw
    R => Reph
    ZWNJ => Zwnj
    ZWJ => Zwj
    _ => Other
  }
}

///|
priv struct ComplexTokens {
  stream : TokenStream
  decomp : Array[(Token, UseClass)]
  mut decomp_offset : Int
  script : Script
}

///|

///|
fn ComplexTokens::ComplexTokens(
  script : Script,
  iter : Iter[Token],
) -> ComplexTokens {
  {
    stream: TokenStream(iter),
    decomp: ([] : Array[(Token, UseClass)]),
    decomp_offset: 0,
    script,
  }
}

///|
fn ComplexTokens::next(self : ComplexTokens) -> (Token, UseClass, Bool)? {
  if self.decomp_offset < self.decomp.length() {
    let (input, class) = self.decomp[self.decomp_offset]
    self.decomp_offset = self.decomp_offset + 1
    Some((input, class, false))
  } else {
    match self.stream.next() {
      None => None
      Some(input) => {
        let (class, needs_decomp, emoji) = input.info.use_class()
        if needs_decomp {
          self.decomp.clear()
          self.decomp_offset = 0
          for c in Codepoint::decompose(input.ch) {
            if self.decomp.length() == 3 {
              break
            }
            let props = Codepoint::properties(c)
            let (cclass, _, _) = props.use_class()
            let c2 = Token::{
              ch: c,
              offset: input.offset,
              len: input.len,
              info: input.info.with_properties(props),
              data: input.data,
            }
            self.decomp.push((c2, cclass))
          }
          self.next()
        } else {
          match self.script {
            Khmer =>
              match input.ch.to_int() {
                0x17BE => {
                  let a = '\u{17C1}'
                  let props = Codepoint::properties(a)
                  let (aclass, _, _) = props.use_class()
                  let a = Token::{
                    ch: a,
                    offset: input.offset,
                    len: input.len,
                    info: input.info.with_properties(props),
                    data: input.data,
                  }
                  self.decomp.clear()
                  self.decomp.push((a, aclass))
                  self.decomp.push((input, class))
                  self.decomp_offset = 0
                  self.next()
                }
                0x17BF => {
                  let a = '\u{17C1}'
                  let props = Codepoint::properties(a)
                  let (aclass, _, _) = props.use_class()
                  let a = Token::{
                    ch: a,
                    offset: input.offset,
                    len: input.len,
                    info: input.info.with_properties(props),
                    data: input.data,
                  }
                  self.decomp.clear()
                  self.decomp.push((a, aclass))
                  self.decomp.push((input, class))
                  self.decomp_offset = 0
                  self.next()
                }
                0x17C0 => {
                  let a = '\u{17C1}'
                  let props = Codepoint::properties(a)
                  let (aclass, _, _) = props.use_class()
                  let a = Token::{
                    ch: a,
                    offset: input.offset,
                    len: input.len,
                    info: input.info.with_properties(props),
                    data: input.data,
                  }
                  self.decomp.clear()
                  self.decomp.push((a, aclass))
                  self.decomp.push((input, class))
                  self.decomp_offset = 0
                  self.next()
                }
                0x17C4 => {
                  let a = '\u{17C1}'
                  let props = Codepoint::properties(a)
                  let (aclass, _, _) = props.use_class()
                  let a = Token::{
                    ch: a,
                    offset: input.offset,
                    len: input.len,
                    info: input.info.with_properties(props),
                    data: input.data,
                  }
                  self.decomp.clear()
                  self.decomp.push((a, aclass))
                  self.decomp.push((input, class))
                  self.decomp_offset = 0
                  self.next()
                }
                0x17C5 => {
                  let a = '\u{17C1}'
                  let props = Codepoint::properties(a)
                  let (aclass, _, _) = props.use_class()
                  let a = Token::{
                    ch: a,
                    offset: input.offset,
                    len: input.len,
                    info: input.info.with_properties(props),
                    data: input.data,
                  }
                  self.decomp.clear()
                  self.decomp.push((a, aclass))
                  self.decomp.push((input, class))
                  self.decomp_offset = 0
                  self.next()
                }
                _ => Some((input, class, emoji))
              }
            _ => Some((input, class, emoji))
          }
        }
      }
    }
  }
}

///|
priv struct ComplexState {
  chars : ComplexTokens
  mut cur : Token
  mut cur_kind : UseClass
  mut cur_emoji : Bool
  mut done : Bool
}

///|

///|
fn ComplexState::ComplexState(
  script : Script,
  chars : Iter[Token],
) -> ComplexState {
  let tokens = ComplexTokens::ComplexTokens(script, chars)
  match tokens.next() {
    None =>
      {
        chars: tokens,
        cur: Token::default(),
        cur_kind: O,
        cur_emoji: false,
        done: true,
      }
    Some((first, kind, emoji)) =>
      {
        chars: tokens,
        cur: first,
        cur_kind: kind,
        cur_emoji: emoji,
        done: false,
      }
  }
}

///|
fn ComplexState::next(self : ComplexState, cluster : CharCluster) -> Bool {
  if self.done {
    return false
  }
  complex_parse(self, cluster) |> ignore
  true
}

///|
fn use_class_index(kind : UseClass) -> Int {
  match kind {
    B => 0
    CGJ => 1
    CMAbv => 2
    CMBlw => 3
    CS => 4
    FAbv => 5
    FBlw => 6
    FPst => 7
    FM => 8
    GB => 9
    H => 10
    HN => 11
    IND => 12
    MAbv => 13
    MBlw => 14
    MPre => 15
    MPst => 16
    N => 17
    O => 18
    R => 19
    Rsv => 20
    S => 21
    SMAbv => 22
    SMBlw => 23
    SUB => 24
    VAbv => 25
    VBlw => 26
    VPre => 27
    VPst => 28
    VMAbv => 29
    VMBlw => 30
    VMPre => 31
    VMPst => 32
    VS => 33
    WJ => 34
    ZWJ => 35
    ZWNJ => 36
  }
}

///|
fn use_class_eq(a : UseClass, b : UseClass) -> Bool {
  use_class_index(a) == use_class_index(b)
}

///|
fn complex_accept_as(
  s : ComplexState,
  cluster : CharCluster,
  kind : UseClass,
  as_class : ShapeClass,
) -> Bool? {
  if use_class_eq(s.cur_kind, kind) {
    match complex_accept_any_as(s, cluster, as_class) {
      None => None
      Some(_) => Some(true)
    }
  } else {
    Some(false)
  }
}

///|
fn complex_accept(
  s : ComplexState,
  cluster : CharCluster,
  kind : UseClass,
) -> Bool? {
  complex_accept_as(s, cluster, kind, Other)
}

///|
fn complex_accept_zero_or_many(
  s : ComplexState,
  cluster : CharCluster,
  kind : UseClass,
) -> Bool? {
  let mut some = false
  while true {
    match complex_accept(s, cluster, kind) {
      None => return None
      Some(true) => some = true
      Some(false) => break
    }
  }
  Some(some)
}

///|
fn complex_accept_zero_or_many_as(
  s : ComplexState,
  cluster : CharCluster,
  kind : UseClass,
  as_class : ShapeClass,
) -> Bool? {
  let mut some = false
  while true {
    match complex_accept_as(s, cluster, kind, as_class) {
      None => return None
      Some(true) => some = true
      Some(false) => break
    }
  }
  Some(some)
}

///|
fn complex_accept_any(s : ComplexState, cluster : CharCluster) -> Unit? {
  cluster.push(s.cur, Other)
  match complex_advance(s, cluster) {
    None => None
    Some(_) => Some(())
  }
}

///|
fn complex_accept_any_as(
  s : ComplexState,
  cluster : CharCluster,
  as_class : ShapeClass,
) -> Unit? {
  cluster.push(s.cur, as_class)
  match complex_advance(s, cluster) {
    None => None
    Some(_) => Some(())
  }
}

///|
fn complex_advance(s : ComplexState, cluster : CharCluster) -> Unit? {
  if cluster.chars.length() == MAX_CLUSTER_SIZE {
    return None
  }
  match s.chars.next() {
    None => {
      s.done = true
      None
    }
    Some((input, kind, emoji)) => {
      s.cur = input
      s.cur_kind = kind
      s.cur_emoji = emoji
      if input.ch == '\u{034F}' {
        match complex_accept_any_as(s, cluster, Other) {
          None => return None
          Some(_) => ()
        }
      }
      Some(())
    }
  }
}

///|
fn complex_parse_emoji_extension(
  s : ComplexState,
  cluster : CharCluster,
) -> Bool? {
  while true {
    match s.cur.info.cluster_break() {
      EX =>
        match s.cur.ch.to_int() {
          0x200C =>
            match complex_accept_any_as(s, cluster, Zwnj) {
              None => return None
              Some(_) => ()
            }
          0xFE0F => {
            cluster.set_emoji(Color)
            cluster.note_char(s.cur)
            match complex_advance(s, cluster) {
              None => return None
              Some(_) => ()
            }
          }
          0xFE0E => {
            cluster.set_emoji(Text)
            cluster.note_char(s.cur)
            match complex_advance(s, cluster) {
              None => return None
              Some(_) => ()
            }
          }
          _ =>
            match complex_accept_any_as(s, cluster, Mark) {
              None => return None
              Some(_) => ()
            }
        }
      ZWJ => {
        match complex_accept_any_as(s, cluster, Zwj) {
          None => return None
          Some(_) => ()
        }
        return Some(true)
      }
      _ => break
    }
  }
  Some(false)
}

///|
fn complex_parse_halant_number(
  s : ComplexState,
  cluster : CharCluster,
) -> Bool? {
  match s.cur_kind {
    HN => {
      match complex_accept_any_as(s, cluster, Halant) {
        None => return None
        Some(_) => ()
      }
      match s.cur_kind {
        N => {
          match complex_accept_any_as(s, cluster, Base) {
            None => return None
            Some(_) => ()
          }
          match complex_accept_as(s, cluster, VS, Vs) {
            None => return None
            Some(v) => v |> ignore
          }
          Some(true)
        }
        _ => Some(false)
      }
    }
    _ => None
  }
}

///|
fn complex_parse_halant_base(
  s : ComplexState,
  cluster : CharCluster,
  vt : Ref[Bool],
) -> Bool? {
  vt.val = false
  match s.cur_kind {
    SUB => {
      match complex_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      match complex_accept_zero_or_many(s, cluster, CMAbv) {
        None => return None
        Some(v) => v |> ignore
      }
      match complex_accept_zero_or_many(s, cluster, CMBlw) {
        None => return None
        Some(v) => v |> ignore
      }
      Some(true)
    }
    H => {
      vt.val = true
      match s.chars.script {
        Khmer =>
          if s.cur.ch == '\u{17D2}' {
            match complex_accept_any_as(s, cluster, Other) {
              None => return None
              Some(_) => ()
            }
          } else {
            match complex_accept_any_as(s, cluster, Halant) {
              None => return None
              Some(_) => ()
            }
          }
        _ =>
          match complex_accept_any_as(s, cluster, Halant) {
            None => return None
            Some(_) => ()
          }
      }
      match s.cur_kind {
        B => {
          vt.val = false
          match complex_accept_any_as(s, cluster, Base) {
            None => return None
            Some(_) => ()
          }
          match complex_accept_as(s, cluster, VS, Vs) {
            None => return None
            Some(v) => v |> ignore
          }
          match complex_accept_zero_or_many(s, cluster, CMAbv) {
            None => return None
            Some(v) => v |> ignore
          }
          match complex_accept_zero_or_many(s, cluster, CMBlw) {
            None => return None
            Some(v) => v |> ignore
          }
          Some(true)
        }
        _ => Some(false)
      }
    }
    _ => Some(false)
  }
}

///|
fn complex_parse_vowel_modifier(
  s : ComplexState,
  cluster : CharCluster,
) -> Bool? {
  match s.cur_kind {
    VMPre => {
      match complex_accept_any_as(s, cluster, VMPre) {
        None => return None
        Some(_) => ()
      }
      Some(true)
    }
    VMAbv => {
      match complex_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      Some(true)
    }
    VMBlw => {
      match complex_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      Some(true)
    }
    VMPst => {
      match complex_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      Some(true)
    }
    H => {
      match complex_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      Some(true)
    }
    _ => Some(false)
  }
}

///|
fn complex_parse_standard_tail(
  s : ComplexState,
  cluster : CharCluster,
  is_potential_symbol : Bool,
  vt : Ref[Bool],
) -> Unit? {
  match complex_accept_as(s, cluster, VS, Vs) {
    None => return None
    Some(v) => v |> ignore
  }
  let k = s.cur_kind
  if is_potential_symbol && (use_class_eq(k, SMAbv) || use_class_eq(k, SMBlw)) {
    match complex_accept_zero_or_many(s, cluster, SMAbv) {
      None => return None
      Some(v) => v |> ignore
    }
    match complex_accept_zero_or_many(s, cluster, SMBlw) {
      None => return None
      Some(v) => v |> ignore
    }
    return Some(())
  }
  match complex_accept_zero_or_many(s, cluster, CMAbv) {
    None => return None
    Some(v) => v |> ignore
  }
  match complex_accept_zero_or_many(s, cluster, CMBlw) {
    None => return None
    Some(v) => v |> ignore
  }
  while true {
    match complex_parse_halant_base(s, cluster, vt) {
      None => return None
      Some(true) => ()
      Some(false) => break
    }
  }
  if vt.val {
    return Some(())
  }
  match complex_accept(s, cluster, MPre) {
    None => return None
    Some(v) => v |> ignore
  }
  match complex_accept(s, cluster, MAbv) {
    None => return None
    Some(v) => v |> ignore
  }
  match complex_accept(s, cluster, MBlw) {
    None => return None
    Some(v) => v |> ignore
  }
  match complex_accept(s, cluster, MBlw) {
    None => return None
    Some(v) => v |> ignore
  }
  match complex_accept(s, cluster, MPst) {
    None => return None
    Some(v) => v |> ignore
  }
  match complex_accept_zero_or_many_as(s, cluster, VPre, VPre) {
    None => return None
    Some(v) => v |> ignore
  }
  match complex_accept_zero_or_many(s, cluster, VAbv) {
    None => return None
    Some(v) => v |> ignore
  }
  match complex_accept_zero_or_many(s, cluster, VBlw) {
    None => return None
    Some(v) => v |> ignore
  }
  match complex_accept_zero_or_many(s, cluster, VPst) {
    None => return None
    Some(v) => v |> ignore
  }
  while true {
    match complex_parse_vowel_modifier(s, cluster) {
      None => return None
      Some(true) => ()
      Some(false) => break
    }
  }
  match complex_accept_zero_or_many(s, cluster, FAbv) {
    None => return None
    Some(v) => v |> ignore
  }
  match complex_accept_zero_or_many(s, cluster, FBlw) {
    None => return None
    Some(v) => v |> ignore
  }
  match complex_accept_zero_or_many(s, cluster, FPst) {
    None => return None
    Some(v) => v |> ignore
  }
  match complex_accept(s, cluster, FM) {
    None => return None
    Some(v) => v |> ignore
  }
  Some(())
}

///|
fn complex_parse_standard(
  s : ComplexState,
  cluster : CharCluster,
  is_potential_symbol : Bool,
  vt : Ref[Bool],
) -> Unit? {
  match s.cur_kind {
    B => {
      match complex_accept_any_as(s, cluster, Base) {
        None => return None
        Some(_) => ()
      }
      match complex_parse_standard_tail(s, cluster, is_potential_symbol, vt) {
        None => return None
        Some(_) => ()
      }
    }
    GB => {
      match complex_accept_any_as(s, cluster, Base) {
        None => return None
        Some(_) => ()
      }
      match complex_parse_standard_tail(s, cluster, is_potential_symbol, vt) {
        None => return None
        Some(_) => ()
      }
    }
    _ => {
      cluster.set_broken()
      match complex_accept_any_as(s, cluster, s.cur_kind.to_shape_class()) {
        None => return None
        Some(_) => ()
      }
    }
  }
  Some(())
}

///|
fn complex_parse(s : ComplexState, cluster : CharCluster) -> Unit? {
  let vt = Ref(false)
  if s.done {
    return Some(())
  }
  if s.cur_emoji {
    cluster.set_emoji(Default)
    while s.cur_emoji {
      match complex_accept_any_as(s, cluster, Base) {
        None => return None
        Some(_) => ()
      }
      match complex_parse_emoji_extension(s, cluster) {
        None => return None
        Some(true) => ()
        Some(false) => break
      }
    }
    return Some(())
  }
  match s.cur_kind {
    O =>
      match s.cur.ch {
        '\r' => {
          cluster.set_space(Newline)
          match complex_accept_any_as(s, cluster, Control) {
            None => return None
            Some(_) => ()
          }
          if s.cur.ch == '\n' {
            match complex_accept_any_as(s, cluster, Control) {
              None => return None
              Some(_) => ()
            }
          }
        }
        '\n' => {
          cluster.set_space(Newline)
          match complex_accept_any_as(s, cluster, Control) {
            None => return None
            Some(_) => ()
          }
        }
        _ => {
          cluster.set_space_from_char(s.cur.ch)
          let class = match s.cur.info.category() {
            Format =>
              match s.cur.ch.to_int() {
                0x200C => ShapeClass::Zwnj
                0x200D => Zwj
                _ => Control
              }
            Control => Control
            _ => Base
          }
          match complex_accept_any_as(s, cluster, class) {
            None => return None
            Some(_) => ()
          }
        }
      }
    IND => {
      match complex_accept_any_as(s, cluster, Base) {
        None => return None
        Some(_) => ()
      }
      match complex_accept_as(s, cluster, VS, Vs) {
        None => return None
        Some(v) => v |> ignore
      }
    }
    Rsv => {
      match complex_accept_any_as(s, cluster, Base) {
        None => return None
        Some(_) => ()
      }
      match complex_accept_as(s, cluster, VS, Vs) {
        None => return None
        Some(v) => v |> ignore
      }
    }
    WJ => {
      match complex_accept_any_as(s, cluster, Base) {
        None => return None
        Some(_) => ()
      }
      match complex_accept_as(s, cluster, VS, Vs) {
        None => return None
        Some(v) => v |> ignore
      }
    }
    R => {
      match complex_accept_any_as(s, cluster, Reph) {
        None => return None
        Some(_) => ()
      }
      match complex_parse_standard(s, cluster, false, vt) {
        None => return None
        Some(_) => ()
      }
    }
    CS => {
      match complex_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      match complex_parse_standard(s, cluster, false, vt) {
        None => return None
        Some(_) => ()
      }
    }
    B =>
      match complex_parse_standard(s, cluster, false, vt) {
        None => return None
        Some(_) => ()
      }
    GB =>
      match complex_parse_standard(s, cluster, true, vt) {
        None => return None
        Some(_) => ()
      }
    N => {
      match complex_accept_any_as(s, cluster, Base) {
        None => return None
        Some(_) => ()
      }
      match complex_accept_as(s, cluster, VS, Vs) {
        None => return None
        Some(v) => v |> ignore
      }
      while true {
        match complex_parse_halant_number(s, cluster) {
          None => break
          Some(true) => ()
          Some(false) => break
        }
      }
    }
    S => {
      match complex_accept_any_as(s, cluster, Base) {
        None => return None
        Some(_) => ()
      }
      match complex_accept_as(s, cluster, VS, Vs) {
        None => return None
        Some(v) => v |> ignore
      }
      match complex_accept_zero_or_many(s, cluster, SMAbv) {
        None => return None
        Some(v) => v |> ignore
      }
      match complex_accept_zero_or_many(s, cluster, SMBlw) {
        None => return None
        Some(v) => v |> ignore
      }
    }
    _ =>
      match complex_parse_standard(s, cluster, false, vt) {
        None => return None
        Some(_) => ()
      }
  }
  None
}

///|
priv struct MyanmarState {
  chars : TokenStream
  mut cur : Token
  mut cur_kind : MyanmarClass
  mut cur_emoji : Bool
  mut done : Bool
}

///|

///|
fn MyanmarState::MyanmarState(chars : Iter[Token]) -> MyanmarState {
  let stream = TokenStream::TokenStream(chars)
  match stream.next() {
    None =>
      {
        chars: stream,
        cur: Token::default(),
        cur_kind: O,
        cur_emoji: false,
        done: true,
      }
    Some(first) => {
      let (kind, emoji) = first.info.myanmar_class()
      {
        chars: stream,
        cur: first,
        cur_kind: kind,
        cur_emoji: emoji,
        done: false,
      }
    }
  }
}

///|
fn MyanmarState::next(self : MyanmarState, cluster : CharCluster) -> Bool {
  if self.done {
    return false
  }
  myanmar_parse(self, cluster) |> ignore
  true
}

///|
fn myanmar_class_index(kind : MyanmarClass) -> Int {
  match kind {
    A => 0
    As => 1
    C => 2
    D => 3
    D0 => 4
    DB => 5
    GB => 6
    H => 7
    IV => 8
    J => 9
    K => 10
    MH => 11
    MR => 12
    MW => 13
    MY => 14
    O => 15
    P => 16
    PT => 17
    R => 18
    S => 19
    V => 20
    VAbv => 21
    VBlw => 22
    VPre => 23
    VPst => 24
    VS => 25
    WJ => 26
  }
}

///|
fn myanmar_class_eq(a : MyanmarClass, b : MyanmarClass) -> Bool {
  myanmar_class_index(a) == myanmar_class_index(b)
}

///|
fn myanmar_accept_as(
  s : MyanmarState,
  cluster : CharCluster,
  kind : MyanmarClass,
  as_class : ShapeClass,
) -> Bool? {
  if myanmar_class_eq(s.cur_kind, kind) {
    match myanmar_accept_any_as(s, cluster, as_class) {
      None => None
      Some(_) => Some(true)
    }
  } else {
    Some(false)
  }
}

///|
fn myanmar_accept(
  s : MyanmarState,
  cluster : CharCluster,
  kind : MyanmarClass,
) -> Bool? {
  myanmar_accept_as(s, cluster, kind, Other)
}

///|
fn myanmar_accept_zero_or_many(
  s : MyanmarState,
  cluster : CharCluster,
  kind : MyanmarClass,
) -> Bool? {
  let mut some = false
  while true {
    match myanmar_accept(s, cluster, kind) {
      None => return None
      Some(true) => some = true
      Some(false) => break
    }
  }
  Some(some)
}

///|
fn myanmar_accept_zero_or_many_as(
  s : MyanmarState,
  cluster : CharCluster,
  kind : MyanmarClass,
  as_class : ShapeClass,
) -> Bool? {
  let mut some = false
  while true {
    match myanmar_accept_as(s, cluster, kind, as_class) {
      None => return None
      Some(true) => some = true
      Some(false) => break
    }
  }
  Some(some)
}

///|
fn myanmar_accept_any(s : MyanmarState, cluster : CharCluster) -> Unit? {
  cluster.push(s.cur, Other)
  match myanmar_advance(s, cluster) {
    None => None
    Some(_) => Some(())
  }
}

///|
fn myanmar_accept_any_as(
  s : MyanmarState,
  cluster : CharCluster,
  as_class : ShapeClass,
) -> Unit? {
  cluster.push(s.cur, as_class)
  match myanmar_advance(s, cluster) {
    None => None
    Some(_) => Some(())
  }
}

///|
fn myanmar_advance(s : MyanmarState, cluster : CharCluster) -> Unit? {
  if cluster.chars.length() == MAX_CLUSTER_SIZE {
    return None
  }
  match s.chars.next() {
    None => {
      s.done = true
      None
    }
    Some(input) => {
      let (kind, emoji) = input.info.myanmar_class()
      s.cur = input
      s.cur_emoji = emoji
      s.cur_kind = kind
      if input.ch == '\u{034F}' {
        match myanmar_accept_any(s, cluster) {
          None => return None
          Some(_) => ()
        }
      }
      Some(())
    }
  }
}

///|
fn myanmar_parse_emoji_extension(
  s : MyanmarState,
  cluster : CharCluster,
) -> Bool? {
  while true {
    match s.cur.info.cluster_break() {
      EX =>
        match s.cur.ch.to_int() {
          0x200C =>
            match myanmar_accept_any_as(s, cluster, Zwnj) {
              None => return None
              Some(_) => ()
            }
          0xFE0F => {
            cluster.set_emoji(Color)
            cluster.note_char(s.cur)
            match myanmar_advance(s, cluster) {
              None => return None
              Some(_) => ()
            }
          }
          0xFE0E => {
            cluster.set_emoji(Text)
            cluster.note_char(s.cur)
            match myanmar_advance(s, cluster) {
              None => return None
              Some(_) => ()
            }
          }
          _ =>
            match myanmar_accept_any_as(s, cluster, Mark) {
              None => return None
              Some(_) => ()
            }
        }
      ZWJ => {
        match myanmar_accept_any_as(s, cluster, Zwj) {
          None => return None
          Some(_) => ()
        }
        return Some(true)
      }
      _ => break
    }
  }
  Some(false)
}

///|
fn myanmar_parse_stacked_consonant_or_vowel(
  s : MyanmarState,
  cluster : CharCluster,
  vt : Ref[Bool],
) -> Bool? {
  vt.val = false
  match s.cur_kind {
    H => {
      vt.val = true
      match myanmar_accept_any_as(s, cluster, Halant) {
        None => return None
        Some(_) => ()
      }
      match s.cur_kind {
        C => {
          vt.val = false
          match myanmar_accept_any_as(s, cluster, Base) {
            None => return None
            Some(_) => ()
          }
          match myanmar_accept_as(s, cluster, VS, Vs) {
            None => return None
            Some(v) => v |> ignore
          }
          Some(true)
        }
        IV => {
          vt.val = false
          match myanmar_accept_any_as(s, cluster, Base) {
            None => return None
            Some(_) => ()
          }
          match myanmar_accept_as(s, cluster, VS, Vs) {
            None => return None
            Some(v) => v |> ignore
          }
          Some(true)
        }
        _ => Some(false)
      }
    }
    _ => Some(false)
  }
}

///|
fn myanmar_parse_post_base_vowel(
  s : MyanmarState,
  cluster : CharCluster,
) -> Bool? {
  match s.cur_kind {
    VPst => {
      match myanmar_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      match myanmar_accept(s, cluster, MH) {
        None => return None
        Some(v) => v |> ignore
      }
      match myanmar_accept_zero_or_many(s, cluster, As) {
        None => return None
        Some(v) => v |> ignore
      }
      match myanmar_accept_zero_or_many(s, cluster, VAbv) {
        None => return None
        Some(v) => v |> ignore
      }
      match myanmar_accept_zero_or_many_as(s, cluster, A, Anusvara) {
        None => return None
        Some(v) => v |> ignore
      }
      match myanmar_accept(s, cluster, DB) {
        None => return None
        Some(true) =>
          match myanmar_accept(s, cluster, As) {
            None => return None
            Some(v) => v |> ignore
          }
        Some(false) => ()
      }
      Some(true)
    }
    _ => Some(false)
  }
}

///|
fn myanmar_parse_pwo_tone_mark(
  s : MyanmarState,
  cluster : CharCluster,
) -> Bool? {
  match s.cur_kind {
    PT => {
      match myanmar_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      match myanmar_accept(s, cluster, As) {
        None => return None
        Some(true) =>
          match myanmar_accept_as(s, cluster, A, Anusvara) {
            None => return None
            Some(v) => v |> ignore
          }
        Some(false) => {
          match myanmar_accept_zero_or_many_as(s, cluster, A, Anusvara) {
            None => return None
            Some(v) => v |> ignore
          }
          match myanmar_accept(s, cluster, DB) {
            None => return None
            Some(v) => v |> ignore
          }
          match myanmar_accept(s, cluster, As) {
            None => return None
            Some(v) => v |> ignore
          }
        }
      }
      Some(true)
    }
    _ => Some(false)
  }
}

///|
fn myanmar_parse(s : MyanmarState, cluster : CharCluster) -> Unit? {
  let vt = Ref(false)
  if s.done {
    return Some(())
  }
  if s.cur_emoji {
    cluster.set_emoji(Default)
    while s.cur_emoji {
      match myanmar_accept_any_as(s, cluster, Base) {
        None => return None
        Some(_) => ()
      }
      match myanmar_parse_emoji_extension(s, cluster) {
        None => return None
        Some(true) => ()
        Some(false) => break
      }
    }
    return Some(())
  }
  match s.cur_kind {
    O => {
      match s.cur.ch {
        '\r' => {
          cluster.set_space(Newline)
          match myanmar_accept_any_as(s, cluster, Control) {
            None => return None
            Some(_) => ()
          }
          if s.cur.ch == '\n' {
            match myanmar_accept_any_as(s, cluster, Control) {
              None => return None
              Some(_) => ()
            }
          }
        }
        '\n' => {
          cluster.set_space(Newline)
          match myanmar_accept_any_as(s, cluster, Control) {
            None => return None
            Some(_) => ()
          }
        }
        _ => {
          cluster.set_space_from_char(s.cur.ch)
          let class = match s.cur.info.category() {
            Format =>
              match s.cur.ch.to_int() {
                0x200C => ShapeClass::Zwnj
                0x200D => Zwj
                _ => Control
              }
            Control => Control
            _ => Base
          }
          match myanmar_accept_any_as(s, cluster, class) {
            None => return None
            Some(_) => ()
          }
        }
      }
      ()
    }
    P => {
      match myanmar_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      ()
    }
    S => {
      match myanmar_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      ()
    }
    R => {
      match myanmar_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      ()
    }
    WJ => {
      match myanmar_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      ()
    }
    D0 => {
      match myanmar_accept_any(s, cluster) {
        None => return None
        Some(_) => ()
      }
      ()
    }
    _ => {
      match s.cur.ch.to_int() {
        0x1004 =>
          match myanmar_try_kinzi(s, cluster) {
            None => return None
            Some(_) => ()
          }
        0x101B =>
          match myanmar_try_kinzi(s, cluster) {
            None => return None
            Some(_) => ()
          }
        0x105A =>
          match myanmar_try_kinzi(s, cluster) {
            None => return None
            Some(_) => ()
          }
        _ => ()
      }
      match s.cur_kind {
        C =>
          match myanmar_parse_main(s, cluster, vt) {
            None => return None
            Some(_) => ()
          }
        IV =>
          match myanmar_parse_main(s, cluster, vt) {
            None => return None
            Some(_) => ()
          }
        D =>
          match myanmar_parse_main(s, cluster, vt) {
            None => return None
            Some(_) => ()
          }
        DB =>
          match myanmar_parse_main(s, cluster, vt) {
            None => return None
            Some(_) => ()
          }
        _ => {
          cluster.set_broken()
          match myanmar_accept_any(s, cluster) {
            None => return None
            Some(_) => ()
          }
          return Some(())
        }
      }
      return Some(())
    }
  }
  None
}

///|
fn myanmar_try_kinzi(s : MyanmarState, cluster : CharCluster) -> Unit? {
  match s.chars.peek(0) {
    None => Some(())
    Some(b) =>
      if b.ch == '\u{103A}' {
        match s.chars.peek(1) {
          None => Some(())
          Some(c) =>
            if c.ch == '\u{1039}' {
              cluster.push(s.cur, Kinzi)
              cluster.push(b, Kinzi)
              cluster.push(c, Kinzi)
              match myanmar_advance(s, cluster) {
                None => return None
                Some(_) => ()
              }
              match myanmar_advance(s, cluster) {
                None => return None
                Some(_) => ()
              }
              match myanmar_advance(s, cluster) {
                None => return None
                Some(_) => ()
              }
              Some(())
            } else {
              Some(())
            }
        }
      } else {
        Some(())
      }
  }
}

///|
fn myanmar_parse_main(
  s : MyanmarState,
  cluster : CharCluster,
  vt : Ref[Bool],
) -> Unit? {
  match myanmar_accept_any_as(s, cluster, Base) {
    None => return None
    Some(_) => ()
  }
  match myanmar_accept_as(s, cluster, VS, Vs) {
    None => return None
    Some(v) => v |> ignore
  }
  while true {
    match myanmar_parse_stacked_consonant_or_vowel(s, cluster, vt) {
      None => return None
      Some(true) => ()
      Some(false) => break
    }
  }
  if vt.val {
    return Some(())
  }
  match myanmar_accept_zero_or_many(s, cluster, As) {
    None => return None
    Some(v) => v |> ignore
  }
  match myanmar_accept(s, cluster, MY) {
    None => return None
    Some(true) =>
      match myanmar_accept(s, cluster, As) {
        None => return None
        Some(v) => v |> ignore
      }
    Some(false) => ()
  }
  match myanmar_accept_as(s, cluster, MR, MedialRa) {
    None => return None
    Some(v) => v |> ignore
  }
  match myanmar_accept(s, cluster, MW) {
    None => return None
    Some(true) => {
      match myanmar_accept(s, cluster, MH) {
        None => return None
        Some(v) => v |> ignore
      }
      match myanmar_accept(s, cluster, As) {
        None => return None
        Some(v) => v |> ignore
      }
    }
    Some(false) =>
      match myanmar_accept(s, cluster, MH) {
        None => return None
        Some(true) =>
          match myanmar_accept(s, cluster, As) {
            None => return None
            Some(v) => v |> ignore
          }
        Some(false) => ()
      }
  }
  match myanmar_accept_zero_or_many_as(s, cluster, VPre, VPre) {
    None => return None
    Some(v) => v |> ignore
  }
  match myanmar_accept_zero_or_many(s, cluster, VAbv) {
    None => return None
    Some(v) => v |> ignore
  }
  match myanmar_accept_zero_or_many_as(s, cluster, VBlw, VBlw) {
    None => return None
    Some(v) => v |> ignore
  }
  match myanmar_accept_zero_or_many_as(s, cluster, A, Anusvara) {
    None => return None
    Some(v) => v |> ignore
  }
  match myanmar_accept(s, cluster, DB) {
    None => return None
    Some(true) =>
      match myanmar_accept(s, cluster, As) {
        None => return None
        Some(v) => v |> ignore
      }
    Some(false) => ()
  }
  while true {
    match myanmar_parse_post_base_vowel(s, cluster) {
      None => return None
      Some(true) => ()
      Some(false) => break
    }
  }
  while true {
    match myanmar_parse_pwo_tone_mark(s, cluster) {
      None => return None
      Some(true) => ()
      Some(false) => break
    }
  }
  match myanmar_accept_zero_or_many(s, cluster, V) {
    None => return None
    Some(v) => v |> ignore
  }
  match myanmar_accept(s, cluster, J) {
    None => return None
    Some(v) => v |> ignore
  }
  Some(())
}

///|
/// Parser that accepts a sequence of characters and outputs character clusters.
struct Parser {
  mut inner : Inner
}

///|
priv enum Inner {
  Simple(SimpleState)
  Myanmar(MyanmarState)
  Complex(ComplexState)
}

///|
pub fn Parser::Parser(script : Script, tokens : Iter[Token]) -> Parser {
  let inner = if script.is_complex() {
    match script {
      Myanmar => Inner::Myanmar(MyanmarState(tokens))
      _ => Complex(ComplexState(script, tokens))
    }
  } else {
    Simple(SimpleState(tokens))
  }
  { inner, }
}

///|
pub fn Parser::next(self : Parser, cluster : CharCluster) -> Bool {
  cluster.clear()
  match self.inner {
    Simple(s) => {
      let ok = s.next(cluster)
      self.inner = Simple(s)
      ok
    }
    Myanmar(s) => {
      let ok = s.next(cluster)
      self.inner = Myanmar(s)
      ok
    }
    Complex(s) => {
      let ok = s.next(cluster)
      self.inner = Complex(s)
      ok
    }
  }
}
