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
/// Shaping feature constants.
///
/// Ported from `swash/src/shape/feature.rs` (swash is dual-licensed Apache-2.0 OR MIT).

///|
/// Default tag used in various places.
const DFLT_TAG : Tag = 0x44464C54 // "DFLT"

///|
/// Substitution features.
const CCMP : Tag = 0x63636D70 // "ccmp"

///|
const LOCL : Tag = 0x6C6F636C // "locl"

///|
const RVRN : Tag = 0x7276726E // "rvrn"

///|
const LIGA : Tag = 0x6C696761 // "liga"

///|
const CLIG : Tag = 0x636C6967 // "clig"

///|
const RLIG : Tag = 0x726C6967 // "rlig"

///|
const DLIG : Tag = 0x646C6967 // "dlig"

///|
const CALT : Tag = 0x63616C74 // "calt"

///|
const LJMO : Tag = 0x6C6A6D6F // "ljmo"

///|
const VJMO : Tag = 0x766A6D6F // "vjmo"

///|
const TJMO : Tag = 0x746A6D6F // "tjmo"

///|
const NUKT : Tag = 0x6E756B74 // "nukt"

///|
const AKHN : Tag = 0x616B686E // "akhn"

///|
const RKRF : Tag = 0x726B7266 // "rkrf"

///|
const HALF : Tag = 0x68616C66 // "half"

///|
const HALN : Tag = 0x68616C6E // "haln"

///|
const VATU : Tag = 0x76617475 // "vatu"

///|
const CJCT : Tag = 0x636A6374 // "cjct"

///|
const ISOL : Tag = 0x69736F6C // "isol"

///|
const INIT : Tag = 0x696E6974 // "init"

///|
const MEDI : Tag = 0x6D656469 // "medi"

///|
const MED2 : Tag = 0x6D656432 // "med2"

///|
const FINA : Tag = 0x66696E61 // "fina"

///|
const FIN2 : Tag = 0x66696E32 // "fin2"

///|
const FIN3 : Tag = 0x66696E33 // "fin3"

///|
const MSET : Tag = 0x6D736574 // "mset"

///|
const RPHF : Tag = 0x72706866 // "rphf"

///|
const PREF : Tag = 0x70726566 // "pref"

///|
const ABVF : Tag = 0x61627666 // "abvf"

///|
const BLWF : Tag = 0x626C7766 // "blwf"

///|
const PSTF : Tag = 0x70737466 // "pstf"

///|
const PRES : Tag = 0x70726573 // "pres"

///|
const ABVS : Tag = 0x61627673 // "abvs"

///|
const BLWS : Tag = 0x626C7773 // "blws"

///|
const PSTS : Tag = 0x70737473 // "psts"

///|
const RCLT : Tag = 0x72636C74 // "rclt"

///|
const VERT : Tag = 0x76657274 // "vert"

///|
const VRT2 : Tag = 0x76727432 // "vrt2"

///|
const RTLM : Tag = 0x72746C6D // "rtlm"

///|
/// Positioning features.
const DIST : Tag = 0x64697374 // "dist"

///|
const ABVM : Tag = 0x6162766D // "abvm"

///|
const BLWM : Tag = 0x626C776D // "blwm"

///|
const CURS : Tag = 0x63757273 // "curs"

///|
/// Arabic joining masks.
const ISOL_MASK : Byte = 1

///|
const INIT_MASK : Byte = 2

///|
const MEDI_MASK : Byte = 4

///|
const FINA_MASK : Byte = 8

///|
const MED2_MASK : Byte = 16

///|
const FIN2_MASK : Byte = 32

///|
const FIN3_MASK : Byte = 64

///|
const NONE_MASK : Byte = 0

///|
/// Hangul jamo masks.
const LJMO_MASK : Byte = 1

///|
const VJMO_MASK : Byte = 2

///|
const TJMO_MASK : Byte = 4
