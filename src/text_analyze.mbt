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
/// Word breaking strength (corresponds to <https://drafts.csswg.org/css-text/#word-break-property>).
///
/// Ported from `swash/src/text/analyze.rs` (swash is dual-licensed Apache-2.0 OR MIT).
pub(all) enum WordBreakStrength {
  /// Words can be broken according to their normal Unicode rules.
  Normal
  /// Breaking treats numeric, alphabetic, and Southeast Asian classes as Ideographic. Note that this does not affect
  /// breaking punctuation.
  BreakAll
  /// Breaking between typographic letter units or the NU, AL, AI, or ID classes is prohibited.
  KeepAll
}

///|
fn WordBreakStrength::default() -> WordBreakStrength {
  WordBreakStrength::Normal
}

///|
/// Returns an iterator yielding unicode properties and boundary analysis for
/// each character in the specified sequence.
pub fn analyze(chars : Iter[Char]) -> Analyze {
  Analyze::{ chars: CharStream::new(chars), state: BoundaryState::new() }
}

///|
/// Iterator that yields Unicode properties and boundary analysis.
/// This iterator is created by the [`analyze`] function.
pub struct Analyze {
  chars : CharStream
  state : BoundaryState
}

///|
pub fn Analyze::needs_bidi_resolution(self : Analyze) -> Bool {
  self.state.needs_bidi
}

///|
/// Sets the word breaking strength that will be used to analyze the next character.
pub fn Analyze::set_break_strength(
  self : Analyze,
  strength : WordBreakStrength,
) -> Unit {
  self.state.strength = strength
}

///|
pub fn Analyze::next(self : Analyze) -> (Properties, Boundary)? {
  self.state.next(self.chars)
}

///|
pub fn Analyze::iter(self : Analyze) -> Iter[(Properties, Boundary)] {
  let a = self
  Iter::new(fn() { a.next() })
}

///|
struct CharStream {
  iter : Iter[Char]
  mut buf : Array[Char]
  mut buf_offset : Int
  mut done : Bool
}

///|
fn CharStream::new(iter : Iter[Char]) -> CharStream {
  CharStream::{ iter, buf: ([] : Array[Char]), buf_offset: 0, done: false }
}

///|
fn CharStream::fill_to(self : CharStream, n : Int) -> Unit {
  while !self.done && self.buf_offset + n >= self.buf.length() {
    match self.iter.next() {
      None => {
        self.done = true
        return
      }
      Some(c) => self.buf.push(c)
    }
  }
}

///|
fn CharStream::peek(self : CharStream, n : Int) -> Char? {
  self.fill_to(n)
  let ix = self.buf_offset + n
  if ix >= 0 && ix < self.buf.length() {
    Some(self.buf[ix])
  } else {
    None
  }
}

///|
fn CharStream::next(self : CharStream) -> Char? {
  self.fill_to(0)
  if self.buf_offset < self.buf.length() {
    let c = self.buf[self.buf_offset]
    self.buf_offset = self.buf_offset + 1
    if self.buf_offset > 16 {
      let remain = self.buf.length() - self.buf_offset
      let new_buf : Array[Char] = Array::makei(remain, i => self.buf[self.buf_offset +
        i])
      self.buf = new_buf
      self.buf_offset = 0
    }
    Some(c)
  } else {
    None
  }
}

///|
struct BoundaryState {
  mut strength : WordBreakStrength
  mut prev : WordBreak
  mut prevent_next : Bool
  mut ri_count : UInt
  mut emoji : Bool
  mut next_emoji : Bool
  mut line_state : (UInt, LineBreak?)
  mut first : Bool
  mut needs_bidi : Bool
}

///|
fn BoundaryState::new() -> BoundaryState {
  BoundaryState::{
    strength: WordBreakStrength::default(),
    prev: WordBreak::EX,
    prevent_next: false,
    ri_count: 0,
    emoji: false,
    next_emoji: false,
    line_state: (SOT, None),
    first: true,
    needs_bidi: false,
  }
}

///|
fn BoundaryState::reset_state(self : BoundaryState) -> Unit {
  self.ri_count = 0
  self.emoji = false
}

///|
fn BoundaryState::check_word(
  self : BoundaryState,
  props : Properties,
  stream : CharStream,
) -> Bool {
  let b = props.word_break()
  let emoji = props.is_extended_pictographic()
  if self.first {
    self.first = false
    self.prev = b
    self.next_emoji = emoji
    if word_break_eq(b, WordBreak::RI) {
      self.ri_count = 1
    }
    return true
  }
  let prev_emoji = self.emoji
  self.emoji = self.emoji || self.next_emoji
  self.next_emoji = emoji
  let a = self.prev
  self.prev = b
  if self.prevent_next {
    self.prevent_next = false
    return false
  }
  if word_break_eq(a, WordBreak::CR) && word_break_eq(b, WordBreak::LF) {
    self.reset_state()
    return false
  }
  let a_mask = a.mask()
  let b_mask = b.mask()
  if (a_mask & wb3_a) != 0U || (b_mask & wb3_a) != 0U {
    // (Newline | CR | LF) ÷
    // ÷ (Newline | CR | LF)
    self.reset_state()
    return true
  }
  if word_break_eq(a, WordBreak::ZWJ) && emoji {
    self.reset_state()
    return false
  }
  if (b_mask & wb_4) != 0U {
    // Ignore format and extend characters
    self.reset_state()
    self.prev = a
    return false
  }
  if word_break_eq(a, WordBreak::WSegSpace) &&
    word_break_eq(b, WordBreak::WSegSpace) {
    // WSegSpace × WSegSpace
    self.reset_state()
    return false
  }
  if (a_mask & wb_ah_letter) != 0U {
    // AHLetter × AHLetter
    // AHLetter × Numeric
    if (b_mask & (wb_ah_letter | WordBreak::NU.mask())) != 0U {
      self.reset_state()
      return false
    }
    if (b_mask & (WordBreak::ML.mask() | wb_mid_num_let_q)) != 0U {
      // AHLetter	× (MidLetter | MidNumLetQ) AHLetter
      // AHLetter (MidLetter | MidNumLetQ) × AHLetter
      match stream.peek(0) {
        None => ()
        Some(ch) => {
          let c = Codepoint::properties(ch).word_break()
          if (c.mask() & wb_ah_letter) != 0U {
            self.prevent_next = true
            self.reset_state()
            return false
          }
        }
      }
    }
  }
  if word_break_eq(a, WordBreak::HL) {
    if word_break_eq(b, WordBreak::SQ) {
      self.reset_state()
      return false
    }
    if word_break_eq(b, WordBreak::DQ) {
      // Hebrew_Letter × Double_Quote Hebrew_Letter
      // Hebrew_Letter Double_Quote × Hebrew_Letter
      match stream.peek(0) {
        None => ()
        Some(ch) => {
          let c = Codepoint::properties(ch).word_break()
          if word_break_eq(c, WordBreak::HL) {
            self.prevent_next = true
            self.reset_state()
            return false
          }
        }
      }
    }
  }
  if (a_mask & WordBreak::NU.mask()) != 0U {
    // Numeric × Numeric
    // Numeric × AHLetter
    if (b_mask & (WordBreak::NU.mask() | wb_ah_letter)) != 0U {
      self.reset_state()
      return false
    }
    if (b_mask & (WordBreak::MN.mask() | wb_mid_num_let_q)) != 0U {
      match stream.peek(0) {
        None => ()
        Some(ch) => {
          let c = Codepoint::properties(ch).word_break()
          // Numeric (MidNum | MidNumLetQ) × Numeric
          // Numeric × (MidNum | MidNumLetQ) Numeric
          if word_break_eq(c, WordBreak::NU) {
            self.prevent_next = true
            self.reset_state()
            return false
          }
        }
      }
    }
  }
  if word_break_eq(a, WordBreak::KA) && word_break_eq(b, WordBreak::KA) {
    // Katakana × Katakana
    self.reset_state()
    return false
  }
  if (a_mask & wb13_a) != 0U && word_break_eq(b, WordBreak::EX) {
    // (AHLetter | Numeric | Katakana | ExtendNumLet) ×	ExtendNumLet
    self.reset_state()
    return false
  }
  if word_break_eq(a, WordBreak::EX) && (b_mask & wb13_b) != 0U {
    // ExtendNumLet × (AHLetter | Numeric | Katakana)
    self.reset_state()
    return false
  }
  if prev_emoji && word_break_eq(a, WordBreak::ZWJ) && emoji {
    self.ri_count = 0
    return false
  }
  if self.ri_count == 2 {
    self.reset_state()
    if word_break_eq(b, WordBreak::RI) {
      self.ri_count = 1
    }
    return true
  }
  if word_break_eq(b, WordBreak::RI) {
    self.ri_count = self.ri_count + 1
    if !word_break_eq(a, WordBreak::RI) {
      self.reset_state()
      self.ri_count = 1
      return true
    }
    self.emoji = false
    return false
  }
  self.reset_state()
  true
}

///|
fn BoundaryState::check_line(
  self : BoundaryState,
  props : Properties,
) -> Boundary {
  let (st, prev_lb) = self.line_state
  let lb = props.line_break()
  let val = pair_table[st.reinterpret_as_int()][line_break_index(lb)]

  // word-break: break-all
  //
  // Treat the NU, AL, and SA line breaking classes as ID.
  let mode_val = match self.strength {
    WordBreakStrength::BreakAll => {
      let left = match prev_lb {
        Some(prev) =>
          if is_break_all_class(prev) {
            LINEBREAK_ID
          } else {
            st.reinterpret_as_int()
          }
        None => st.reinterpret_as_int()
      }
      let right = if is_break_all_class(lb) {
        LINEBREAK_ID
      } else {
        line_break_index(lb)
      }
      pair_table[left][right]
    }
    _ => val
  }
  let mut mode = if (mode_val & MANDATORY_BREAK_BIT) != 0U {
    Boundary::Mandatory
  } else if (mode_val & ALLOWED_BREAK_BIT) != 0U &&
    !opt_line_break_eq(prev_lb, LineBreak::ZWJ) {
    Boundary::Line
  } else {
    Boundary::None
  }

  // word-break: keep-all
  //
  // Prohibit breaking between typographic letter units or the NU, AL, or
  // AI, or ID classes.
  // (See https://github.com/unicode-org/icu4x/blob/1e27279/components/segmenter/src/line.rs#L836-L840)
  match (self.strength, prev_lb) {
    (WordBreakStrength::KeepAll, Some(prev)) =>
      if is_keep_all_class(prev) && is_keep_all_class(lb) {
        mode = Boundary::None
      }
    _ => ()
  }

  // Store the original value, not the modified one.
  self.line_state = (val & LINE_STATE_MASK, Some(lb))
  mode
}

///|
fn BoundaryState::next(
  self : BoundaryState,
  stream : CharStream,
) -> (Properties, Boundary)? {
  match stream.next() {
    None => None
    Some(ch) => {
      let props = Codepoint::properties(ch)
      let mut boundary = self.check_line(props)
      let word = self.check_word(props, stream)
      match boundary {
        Boundary::None => if word { boundary = Boundary::Word }
        _ => ()
      }
      self.needs_bidi = self.needs_bidi || props.bidi_class().needs_resolution()
      Some((props, boundary))
    }
  }
}

///|
const ALLOWED_BREAK_BIT : UInt = 0x80U

///|
const MANDATORY_BREAK_BIT : UInt = 0x40U

///|
const LINE_STATE_MASK : UInt = 0xFFU ^ (ALLOWED_BREAK_BIT | MANDATORY_BREAK_BIT)

///|
const SOT : UInt = 44U

///|
const LINEBREAK_ID : Int = 20

///|
fn is_break_all_class(lb : LineBreak) -> Bool {
  match lb {
    LineBreak::AL | LineBreak::NU | LineBreak::SA => true
    _ => false
  }
}

///|
fn is_keep_all_class(lb : LineBreak) -> Bool {
  match lb {
    LineBreak::AI
    | LineBreak::AL
    | LineBreak::ID
    | LineBreak::NU
    | LineBreak::HY
    | LineBreak::H2
    | LineBreak::H3
    | LineBreak::JL
    | LineBreak::JV
    | LineBreak::JT
    | LineBreak::CJ => true
    _ => false
  }
}

///|
fn opt_line_break_eq(opt : LineBreak?, lb : LineBreak) -> Bool {
  match opt {
    None => false
    Some(v) => line_break_eq(v, lb)
  }
}

///|
fn line_break_eq(a : LineBreak, b : LineBreak) -> Bool {
  line_break_index(a) == line_break_index(b)
}

///|
fn line_break_index(lb : LineBreak) -> Int {
  match lb {
    LineBreak::AI => 0
    LineBreak::AL => 1
    LineBreak::B2 => 2
    LineBreak::BA => 3
    LineBreak::BB => 4
    LineBreak::BK => 5
    LineBreak::CB => 6
    LineBreak::CJ => 7
    LineBreak::CL => 8
    LineBreak::CM => 9
    LineBreak::CP => 10
    LineBreak::CR => 11
    LineBreak::EB => 12
    LineBreak::EM => 13
    LineBreak::EX => 14
    LineBreak::GL => 15
    LineBreak::H2 => 16
    LineBreak::H3 => 17
    LineBreak::HL => 18
    LineBreak::HY => 19
    LineBreak::ID => 20
    LineBreak::IN => 21
    LineBreak::IS => 22
    LineBreak::JL => 23
    LineBreak::JT => 24
    LineBreak::JV => 25
    LineBreak::LF => 26
    LineBreak::NL => 27
    LineBreak::NS => 28
    LineBreak::NU => 29
    LineBreak::OP => 30
    LineBreak::PO => 31
    LineBreak::PR => 32
    LineBreak::QU => 33
    LineBreak::RI => 34
    LineBreak::SA => 35
    LineBreak::SG => 36
    LineBreak::SP => 37
    LineBreak::SY => 38
    LineBreak::WJ => 39
    LineBreak::XX => 40
    LineBreak::ZW => 41
    LineBreak::ZWJ => 42
  }
}

///|
fn word_break_eq(a : WordBreak, b : WordBreak) -> Bool {
  word_break_index(a) == word_break_index(b)
}

///|
fn WordBreak::mask(self : WordBreak) -> UInt {
  1U << word_break_index(self)
}

///|
fn word_break_index(wb : WordBreak) -> Int {
  match wb {
    WordBreak::CR => 0
    WordBreak::DQ => 1
    WordBreak::EX => 2
    WordBreak::Extend => 3
    WordBreak::FO => 4
    WordBreak::HL => 5
    WordBreak::KA => 6
    WordBreak::LE => 7
    WordBreak::LF => 8
    WordBreak::MB => 9
    WordBreak::ML => 10
    WordBreak::MN => 11
    WordBreak::NL => 12
    WordBreak::NU => 13
    WordBreak::RI => 14
    WordBreak::SQ => 15
    WordBreak::WSegSpace => 16
    WordBreak::XX => 17
    WordBreak::ZWJ => 18
  }
}

///|
let wb_ah_letter : UInt = WordBreak::LE.mask() | WordBreak::HL.mask()

///|
let wb_mid_num_let_q : UInt = WordBreak::MB.mask() | WordBreak::SQ.mask()

///|
let wb3_a : UInt = WordBreak::NL.mask() |
  WordBreak::CR.mask() |
  WordBreak::LF.mask()

///|
let wb_4 : UInt = WordBreak::Extend.mask() |
  WordBreak::FO.mask() |
  WordBreak::ZWJ.mask()

///|
let wb13_a : UInt = wb_ah_letter |
  WordBreak::NU.mask() |
  WordBreak::KA.mask() |
  WordBreak::EX.mask()

///|
let wb13_b : UInt = wb_ah_letter | WordBreak::NU.mask() | WordBreak::KA.mask()

///|
let pair_table : ReadOnlyArray[ReadOnlyArray[UInt]] = [
  [
    1, 1, 130, 3, 132, 5, 134, 28, 8, 1, 10, 11, 140, 141, 14, 15, 144, 145, 18,
    19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 29, 30, 31, 32, 33, 162, 1, 1, 37,
    38, 39, 1, 41, 1, 235,
  ],
  [
    1, 1, 130, 3, 132, 5, 134, 28, 8, 1, 10, 11, 140, 141, 14, 15, 144, 145, 18,
    19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 29, 30, 31, 32, 33, 162, 1, 1, 37,
    38, 39, 1, 41, 1, 235,
  ],
  [
    129, 129, 2, 3, 132, 5, 134, 28, 8, 2, 10, 11, 140, 141, 14, 15, 144, 145, 146,
    19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 157, 158, 159, 160, 33, 162, 129,
    129, 50, 38, 39, 129, 41, 2, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 3, 10, 11, 140, 141, 14, 143, 144, 145,
    146, 19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 157, 158, 159, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 3, 235,
  ],
  [
    1, 1, 2, 3, 4, 5, 134, 28, 8, 4, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 1, 1, 37, 38, 39, 1,
    41, 4, 235,
  ],
  [
    193, 193, 194, 195, 196, 197, 198, 220, 200, 193, 202, 203, 204, 205, 206, 207,
    208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223,
    224, 225, 226, 193, 193, 229, 230, 231, 193, 233, 193, 235,
  ],
  [
    129, 129, 130, 131, 132, 5, 134, 156, 8, 6, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 147, 148, 149, 22, 151, 152, 153, 26, 27, 156, 157, 158, 159, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 6, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 28, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 157, 158, 159, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 28, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 8, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 157, 158, 31, 32, 33, 162,
    129, 129, 48, 38, 39, 129, 41, 8, 235,
  ],
  [
    1, 1, 130, 3, 132, 5, 134, 28, 8, 9, 10, 11, 140, 141, 14, 15, 144, 145, 18,
    19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 29, 30, 31, 32, 33, 162, 1, 1, 37,
    38, 39, 1, 41, 9, 235,
  ],
  [
    1, 1, 130, 3, 132, 5, 134, 28, 8, 10, 10, 11, 140, 141, 14, 15, 144, 145, 18,
    19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 29, 158, 31, 32, 33, 162, 1, 1,
    49, 38, 39, 1, 41, 10, 235,
  ],
  [
    193, 193, 194, 195, 196, 197, 198, 220, 200, 193, 202, 203, 204, 205, 206, 207,
    208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 26, 219, 220, 221, 222, 223,
    224, 225, 226, 193, 193, 229, 230, 231, 193, 233, 193, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 12, 10, 11, 140, 13, 14, 15, 144, 145,
    146, 19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 157, 158, 31, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 12, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 13, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 157, 158, 31, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 13, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 14, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 157, 158, 159, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 14, 235,
  ],
  [
    1, 1, 2, 3, 4, 5, 6, 28, 8, 15, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 1, 1, 37, 38, 39, 1, 41,
    15, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 16, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 21, 22, 151, 24, 25, 26, 27, 28, 157, 158, 31, 160, 33, 162, 129,
    129, 37, 38, 39, 129, 41, 16, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 17, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 21, 22, 151, 24, 153, 26, 27, 28, 157, 158, 31, 160, 33, 162, 129,
    129, 37, 38, 39, 129, 41, 17, 235,
  ],
  [
    1, 1, 130, 51, 132, 5, 134, 28, 8, 18, 10, 11, 140, 141, 14, 15, 144, 145, 18,
    51, 148, 21, 22, 151, 152, 153, 26, 27, 28, 29, 30, 31, 32, 33, 162, 1, 1, 37,
    38, 39, 1, 41, 18, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 19, 10, 11, 140, 141, 14, 143, 144, 145,
    146, 19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 29, 158, 159, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 19, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 20, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 157, 158, 31, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 20, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 21, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 157, 158, 159, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 21, 235,
  ],
  [
    1, 1, 130, 3, 132, 5, 134, 28, 8, 22, 10, 11, 140, 141, 14, 15, 144, 145, 18,
    19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 29, 158, 159, 160, 33, 162, 1, 1,
    37, 38, 39, 1, 41, 22, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 23, 10, 11, 140, 141, 14, 15, 16, 17, 146,
    19, 148, 21, 22, 23, 152, 25, 26, 27, 28, 157, 158, 31, 160, 33, 162, 129, 129,
    37, 38, 39, 129, 41, 23, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 24, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 21, 22, 151, 24, 153, 26, 27, 28, 157, 158, 31, 160, 33, 162, 129,
    129, 37, 38, 39, 129, 41, 24, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 25, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 21, 22, 151, 24, 25, 26, 27, 28, 157, 158, 31, 160, 33, 162, 129,
    129, 37, 38, 39, 129, 41, 25, 235,
  ],
  [
    193, 193, 194, 195, 196, 197, 198, 220, 200, 193, 202, 203, 204, 205, 206, 207,
    208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223,
    224, 225, 226, 193, 193, 229, 230, 231, 193, 233, 193, 235,
  ],
  [
    193, 193, 194, 195, 196, 197, 198, 220, 200, 193, 202, 203, 204, 205, 206, 207,
    208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223,
    224, 225, 226, 193, 193, 229, 230, 231, 193, 233, 193, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 28, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 157, 158, 159, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 28, 235,
  ],
  [
    1, 1, 130, 3, 132, 5, 134, 28, 8, 29, 10, 11, 140, 141, 14, 15, 144, 145, 18,
    19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 29, 30, 31, 32, 33, 162, 1, 1, 37,
    38, 39, 1, 41, 29, 235,
  ],
  [
    1, 1, 2, 3, 4, 5, 6, 28, 8, 30, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 1, 1, 46, 38, 39, 1, 41,
    30, 235,
  ],
  [
    1, 1, 130, 3, 132, 5, 134, 28, 8, 31, 10, 11, 140, 141, 14, 15, 144, 145, 18,
    19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 29, 30, 159, 160, 33, 162, 1, 1,
    37, 38, 39, 1, 41, 31, 235,
  ],
  [
    1, 1, 130, 3, 132, 5, 134, 28, 8, 32, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
    20, 149, 22, 23, 24, 25, 26, 27, 28, 29, 30, 159, 160, 33, 162, 1, 1, 37, 38,
    39, 1, 41, 32, 235,
  ],
  [
    1, 1, 2, 3, 4, 5, 6, 28, 8, 33, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 1, 1, 47, 38, 39, 1, 41,
    33, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 34, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 157, 158, 159, 160, 33, 52,
    129, 129, 37, 38, 39, 129, 41, 34, 235,
  ],
  [
    1, 1, 130, 3, 132, 5, 134, 28, 8, 1, 10, 11, 140, 141, 14, 15, 144, 145, 18,
    19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 29, 30, 31, 32, 33, 162, 1, 1, 37,
    38, 39, 1, 41, 1, 235,
  ],
  [
    1, 1, 130, 3, 132, 5, 134, 28, 8, 1, 10, 11, 140, 141, 14, 15, 144, 145, 18,
    19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 29, 30, 31, 32, 33, 162, 1, 1, 37,
    38, 39, 1, 41, 1, 235,
  ],
  [
    129, 129, 130, 131, 132, 5, 134, 156, 8, 129, 10, 11, 140, 141, 14, 143, 144,
    145, 146, 147, 148, 149, 22, 151, 152, 153, 26, 27, 156, 157, 158, 159, 160,
    161, 162, 129, 129, 37, 38, 39, 129, 41, 129, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 38, 10, 11, 140, 141, 14, 15, 144, 145,
    18, 19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 29, 158, 159, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 38, 235,
  ],
  [
    1, 1, 2, 3, 4, 5, 6, 28, 8, 39, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 1, 1, 37, 38, 39, 1, 41,
    39, 235,
  ],
  [
    1, 1, 130, 3, 132, 5, 134, 28, 8, 1, 10, 11, 140, 141, 14, 15, 144, 145, 18,
    19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 29, 30, 31, 32, 33, 162, 1, 1, 37,
    38, 39, 1, 41, 1, 235,
  ],
  [
    129, 129, 130, 131, 132, 5, 134, 156, 136, 129, 138, 11, 140, 141, 142, 143,
    144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 26, 27, 156, 157, 158, 159,
    160, 161, 162, 129, 129, 45, 166, 167, 129, 41, 129, 235,
  ],
  [
    1, 1, 130, 3, 132, 5, 134, 28, 8, 42, 10, 11, 140, 141, 14, 15, 144, 145, 18,
    19, 148, 21, 22, 151, 152, 153, 26, 27, 28, 29, 30, 31, 32, 33, 162, 1, 1, 37,
    38, 39, 1, 41, 42, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 129, 10, 11, 140, 141, 14, 143, 144, 145,
    146, 19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 157, 158, 159, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 129, 235,
  ],
  [
    1, 1, 2, 3, 4, 5, 6, 28, 8, 1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 1, 1, 37, 38, 39, 1, 41,
    1, 43,
  ],
  [
    129, 129, 130, 131, 132, 5, 134, 156, 136, 129, 138, 11, 140, 141, 142, 143,
    144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 26, 27, 156, 157, 158, 159,
    160, 161, 162, 129, 129, 45, 166, 167, 129, 41, 129, 235,
  ],
  [
    1, 1, 2, 3, 4, 5, 6, 28, 8, 1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 1, 1, 46, 38, 39, 1, 41,
    1, 235,
  ],
  [
    129, 129, 130, 131, 132, 5, 134, 156, 8, 129, 10, 11, 140, 141, 14, 143, 144,
    145, 146, 147, 148, 149, 22, 151, 152, 153, 26, 27, 156, 157, 30, 159, 160, 161,
    162, 129, 129, 47, 38, 39, 129, 41, 129, 235,
  ],
  [
    129, 129, 130, 131, 132, 5, 134, 28, 8, 129, 10, 11, 140, 141, 14, 143, 144,
    145, 146, 147, 148, 149, 22, 151, 152, 153, 26, 27, 28, 157, 158, 159, 160, 161,
    162, 129, 129, 48, 38, 39, 129, 41, 129, 235,
  ],
  [
    129, 129, 130, 131, 132, 5, 134, 28, 8, 129, 10, 11, 140, 141, 14, 143, 144,
    145, 146, 147, 148, 149, 22, 151, 152, 153, 26, 27, 28, 157, 158, 159, 160, 161,
    162, 129, 129, 49, 38, 39, 129, 41, 129, 235,
  ],
  [
    129, 129, 2, 131, 132, 5, 134, 156, 8, 129, 10, 11, 140, 141, 14, 143, 144, 145,
    146, 147, 148, 149, 22, 151, 152, 153, 26, 27, 156, 157, 158, 159, 160, 161,
    162, 129, 129, 50, 38, 39, 129, 41, 129, 235,
  ],
  [
    1, 1, 2, 3, 4, 5, 134, 28, 8, 51, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 1, 1, 37, 38, 39, 1,
    41, 51, 235,
  ],
  [
    129, 129, 130, 3, 132, 5, 134, 28, 8, 52, 10, 11, 140, 141, 14, 15, 144, 145,
    146, 19, 148, 149, 22, 151, 152, 153, 26, 27, 28, 157, 158, 159, 160, 33, 162,
    129, 129, 37, 38, 39, 129, 41, 52, 235,
  ],
]
