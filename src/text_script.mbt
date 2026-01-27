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
/// Script mapping (minimal subset of swash `text` module).
///
/// Ported from `swash/src/text/unicode.rs` + `unicode_data.rs`.

///|
/// Unicode script.
pub(all) enum Script {
  Adlam
  CaucasianAlbanian
  Ahom
  Arabic
  ImperialAramaic
  Armenian
  Avestan
  Balinese
  Bamum
  BassaVah
  Batak
  Bengali
  Bhaiksuki
  Bopomofo
  Brahmi
  Braille
  Buginese
  Buhid
  Chakma
  CanadianAboriginal
  Carian
  Cham
  Cherokee
  Chorasmian
  Coptic
  Cypriot
  Cyrillic
  Devanagari
  DivesAkuru
  Dogra
  Deseret
  Duployan
  EgyptianHieroglyphs
  Elbasan
  Elymaic
  Ethiopic
  Georgian
  Glagolitic
  GunjalaGondi
  MasaramGondi
  Gothic
  Grantha
  Greek
  Gujarati
  Gurmukhi
  Hangul
  Han
  Hanunoo
  Hatran
  Hebrew
  Hiragana
  AnatolianHieroglyphs
  PahawhHmong
  NyiakengPuachueHmong
  OldHungarian
  OldItalic
  Javanese
  KayahLi
  Katakana
  Kharoshthi
  Khmer
  Khojki
  KhitanSmallScript
  Kannada
  Kaithi
  TaiTham
  Lao
  Latin
  Lepcha
  Limbu
  LinearA
  LinearB
  Lisu
  Lycian
  Lydian
  Mahajani
  Makasar
  Mandaic
  Manichaean
  Marchen
  Medefaidrin
  MendeKikakui
  MeroiticCursive
  MeroiticHieroglyphs
  Malayalam
  Modi
  Mongolian
  Mro
  MeeteiMayek
  Multani
  Myanmar
  Nandinagari
  OldNorthArabian
  Nabataean
  Newa
  Nko
  Nushu
  Ogham
  OlChiki
  OldTurkic
  Oriya
  Osage
  Osmanya
  Palmyrene
  PauCinHau
  OldPermic
  PhagsPa
  InscriptionalPahlavi
  PsalterPahlavi
  Phoenician
  Miao
  InscriptionalParthian
  Rejang
  HanifiRohingya
  Runic
  Samaritan
  OldSouthArabian
  Saurashtra
  SignWriting
  Shavian
  Sharada
  Siddham
  Khudawadi
  Sinhala
  Sogdian
  OldSogdian
  SoraSompeng
  Soyombo
  Sundanese
  SylotiNagri
  Syriac
  Tagbanwa
  Takri
  TaiLe
  NewTaiLue
  Tamil
  Tangut
  TaiViet
  Telugu
  Tifinagh
  Tagalog
  Thaana
  Thai
  Tibetan
  Tirhuta
  Ugaritic
  Vai
  WarangCiti
  Wancho
  OldPersian
  Cuneiform
  Yezidi
  Yi
  ZanabazarSquare
  Inherited
  Common
  Unknown
}

///|
let text_script_by_tag : ReadOnlyArray[(Tag, Script)] = [
  (0x61646C6D, Script::Adlam),
  (0x61676862, Script::CaucasianAlbanian),
  (0x61686F6D, Script::Ahom),
  (0x61726162, Script::Arabic),
  (0x61726D69, Script::ImperialAramaic),
  (0x61726D6E, Script::Armenian),
  (0x61767374, Script::Avestan),
  (0x62616C69, Script::Balinese),
  (0x62616D75, Script::Bamum),
  (0x62617373, Script::BassaVah),
  (0x6261746B, Script::Batak),
  (0x626E6732, Script::Bengali),
  (0x62686B73, Script::Bhaiksuki),
  (0x626F706F, Script::Bopomofo),
  (0x62726168, Script::Brahmi),
  (0x62726169, Script::Braille),
  (0x62756769, Script::Buginese),
  (0x62756864, Script::Buhid),
  (0x63616B6D, Script::Chakma),
  (0x63616E73, Script::CanadianAboriginal),
  (0x63617269, Script::Carian),
  (0x6368616D, Script::Cham),
  (0x63686572, Script::Cherokee),
  (0x63687273, Script::Chorasmian),
  (0x636F7074, Script::Coptic),
  (0x63707274, Script::Cypriot),
  (0x6379726C, Script::Cyrillic),
  (0x64657632, Script::Devanagari),
  (0x6469616B, Script::DivesAkuru),
  (0x646F6772, Script::Dogra),
  (0x64737274, Script::Deseret),
  (0x6475706C, Script::Duployan),
  (0x65677970, Script::EgyptianHieroglyphs),
  (0x656C6261, Script::Elbasan),
  (0x656C796D, Script::Elymaic),
  (0x65746869, Script::Ethiopic),
  (0x67656F72, Script::Georgian),
  (0x676C6167, Script::Glagolitic),
  (0x676F6E67, Script::GunjalaGondi),
  (0x676F6E6D, Script::MasaramGondi),
  (0x676F7468, Script::Gothic),
  (0x6772616E, Script::Grantha),
  (0x6772656B, Script::Greek),
  (0x676A7232, Script::Gujarati),
  (0x67757232, Script::Gurmukhi),
  (0x68616E67, Script::Hangul),
  (0x68616E69, Script::Han),
  (0x68616E6F, Script::Hanunoo),
  (0x68617472, Script::Hatran),
  (0x68656272, Script::Hebrew),
  (0x68697261, Script::Hiragana),
  (0x686C7577, Script::AnatolianHieroglyphs),
  (0x686D6E67, Script::PahawhHmong),
  (0x686D6E70, Script::NyiakengPuachueHmong),
  (0x68756E67, Script::OldHungarian),
  (0x6974616C, Script::OldItalic),
  (0x6A617661, Script::Javanese),
  (0x6B616C69, Script::KayahLi),
  (0x6B616E61, Script::Katakana),
  (0x6B686172, Script::Kharoshthi),
  (0x6B686D72, Script::Khmer),
  (0x6B686F6A, Script::Khojki),
  (0x6B697473, Script::KhitanSmallScript),
  (0x6B6E6432, Script::Kannada),
  (0x6B746869, Script::Kaithi),
  (0x6C616E61, Script::TaiTham),
  (0x6C616F6F, Script::Lao),
  (0x6C61746E, Script::Latin),
  (0x6C657063, Script::Lepcha),
  (0x6C696D62, Script::Limbu),
  (0x6C696E61, Script::LinearA),
  (0x6C696E62, Script::LinearB),
  (0x6C697375, Script::Lisu),
  (0x6C796369, Script::Lycian),
  (0x6C796469, Script::Lydian),
  (0x6D61686A, Script::Mahajani),
  (0x6D616B61, Script::Makasar),
  (0x6D616E64, Script::Mandaic),
  (0x6D616E69, Script::Manichaean),
  (0x6D617263, Script::Marchen),
  (0x6D656466, Script::Medefaidrin),
  (0x6D656E64, Script::MendeKikakui),
  (0x6D657263, Script::MeroiticCursive),
  (0x6D65726F, Script::MeroiticHieroglyphs),
  (0x6D6C6D32, Script::Malayalam),
  (0x6D6F6469, Script::Modi),
  (0x6D6F6E67, Script::Mongolian),
  (0x6D726F6F, Script::Mro),
  (0x6D746569, Script::MeeteiMayek),
  (0x6D756C74, Script::Multani),
  (0x6D796D32, Script::Myanmar),
  (0x6E616E64, Script::Nandinagari),
  (0x6E617262, Script::OldNorthArabian),
  (0x6E626174, Script::Nabataean),
  (0x6E657761, Script::Newa),
  (0x6E6B6F20, Script::Nko),
  (0x6E736875, Script::Nushu),
  (0x6F67616D, Script::Ogham),
  (0x6F6C636B, Script::OlChiki),
  (0x6F726B68, Script::OldTurkic),
  (0x6F727932, Script::Oriya),
  (0x6F736765, Script::Osage),
  (0x6F736D61, Script::Osmanya),
  (0x70616C6D, Script::Palmyrene),
  (0x70617563, Script::PauCinHau),
  (0x7065726D, Script::OldPermic),
  (0x70686167, Script::PhagsPa),
  (0x70686C69, Script::InscriptionalPahlavi),
  (0x70686C70, Script::PsalterPahlavi),
  (0x70686E78, Script::Phoenician),
  (0x6D69616F, Script::Miao),
  (0x70727469, Script::InscriptionalParthian),
  (0x726A6E67, Script::Rejang),
  (0x726F6867, Script::HanifiRohingya),
  (0x72756E72, Script::Runic),
  (0x73616D72, Script::Samaritan),
  (0x73617262, Script::OldSouthArabian),
  (0x73617572, Script::Saurashtra),
  (0x73676E77, Script::SignWriting),
  (0x73686177, Script::Shavian),
  (0x73687264, Script::Sharada),
  (0x73696464, Script::Siddham),
  (0x73696E64, Script::Khudawadi),
  (0x73696E68, Script::Sinhala),
  (0x736F6764, Script::Sogdian),
  (0x736F676F, Script::OldSogdian),
  (0x736F7261, Script::SoraSompeng),
  (0x736F796F, Script::Soyombo),
  (0x73756E64, Script::Sundanese),
  (0x73796C6F, Script::SylotiNagri),
  (0x73797263, Script::Syriac),
  (0x74616762, Script::Tagbanwa),
  (0x74616B72, Script::Takri),
  (0x74616C65, Script::TaiLe),
  (0x74616C75, Script::NewTaiLue),
  (0x746D6C32, Script::Tamil),
  (0x74616E67, Script::Tangut),
  (0x74617674, Script::TaiViet),
  (0x74656C75, Script::Telugu),
  (0x74666E67, Script::Tifinagh),
  (0x74676C67, Script::Tagalog),
  (0x74686161, Script::Thaana),
  (0x74686169, Script::Thai),
  (0x74696274, Script::Tibetan),
  (0x74697268, Script::Tirhuta),
  (0x75676172, Script::Ugaritic),
  (0x76616969, Script::Vai),
  (0x77617261, Script::WarangCiti),
  (0x7763686F, Script::Wancho),
  (0x7870656F, Script::OldPersian),
  (0x78737578, Script::Cuneiform),
  (0x79657A69, Script::Yezidi),
  (0x79696969, Script::Yi),
  (0x7A616E62, Script::ZanabazarSquare),
  (0x7A696E68, Script::Inherited),
  (0x7A797979, Script::Common),
  (0x7A7A7A7A, Script::Unknown),
]

///|
fn text_script_lookup(tag : Tag) -> Script? {
  let mut l = 0
  let mut h = text_script_by_tag.length()
  while l < h {
    let mid = (l + h) / 2
    let (k, v) = text_script_by_tag[mid]
    if k < tag {
      l = mid + 1
    } else if k > tag {
      h = mid
    } else {
      return Some(v)
    }
  }
  None
}

///|
/// Returns the script associated with the specified OpenType script tag.
pub fn Script::from_opentype(tag : Tag) -> Script? {
  text_script_lookup(tag)
}

///|
/// Returns the script as an OpenType tag.
pub fn Script::to_opentype(self : Script) -> Tag {
  match self {
    Adlam => 0x61646C6D
    CaucasianAlbanian => 0x61676862
    Ahom => 0x61686F6D
    Arabic => 0x61726162
    ImperialAramaic => 0x61726D69
    Armenian => 0x61726D6E
    Avestan => 0x61767374
    Balinese => 0x62616C69
    Bamum => 0x62616D75
    BassaVah => 0x62617373
    Batak => 0x6261746B
    Bengali => 0x626E6732
    Bhaiksuki => 0x62686B73
    Bopomofo => 0x626F706F
    Brahmi => 0x62726168
    Braille => 0x62726169
    Buginese => 0x62756769
    Buhid => 0x62756864
    Chakma => 0x63616B6D
    CanadianAboriginal => 0x63616E73
    Carian => 0x63617269
    Cham => 0x6368616D
    Cherokee => 0x63686572
    Chorasmian => 0x63687273
    Coptic => 0x636F7074
    Cypriot => 0x63707274
    Cyrillic => 0x6379726C
    Devanagari => 0x64657632
    DivesAkuru => 0x6469616B
    Dogra => 0x646F6772
    Deseret => 0x64737274
    Duployan => 0x6475706C
    EgyptianHieroglyphs => 0x65677970
    Elbasan => 0x656C6261
    Elymaic => 0x656C796D
    Ethiopic => 0x65746869
    Georgian => 0x67656F72
    Glagolitic => 0x676C6167
    GunjalaGondi => 0x676F6E67
    MasaramGondi => 0x676F6E6D
    Gothic => 0x676F7468
    Grantha => 0x6772616E
    Greek => 0x6772656B
    Gujarati => 0x676A7232
    Gurmukhi => 0x67757232
    Hangul => 0x68616E67
    Han => 0x68616E69
    Hanunoo => 0x68616E6F
    Hatran => 0x68617472
    Hebrew => 0x68656272
    Hiragana => 0x68697261
    AnatolianHieroglyphs => 0x686C7577
    PahawhHmong => 0x686D6E67
    NyiakengPuachueHmong => 0x686D6E70
    OldHungarian => 0x68756E67
    OldItalic => 0x6974616C
    Javanese => 0x6A617661
    KayahLi => 0x6B616C69
    Katakana => 0x6B616E61
    Kharoshthi => 0x6B686172
    Khmer => 0x6B686D72
    Khojki => 0x6B686F6A
    KhitanSmallScript => 0x6B697473
    Kannada => 0x6B6E6432
    Kaithi => 0x6B746869
    TaiTham => 0x6C616E61
    Lao => 0x6C616F6F
    Latin => 0x6C61746E
    Lepcha => 0x6C657063
    Limbu => 0x6C696D62
    LinearA => 0x6C696E61
    LinearB => 0x6C696E62
    Lisu => 0x6C697375
    Lycian => 0x6C796369
    Lydian => 0x6C796469
    Mahajani => 0x6D61686A
    Makasar => 0x6D616B61
    Mandaic => 0x6D616E64
    Manichaean => 0x6D616E69
    Marchen => 0x6D617263
    Medefaidrin => 0x6D656466
    MendeKikakui => 0x6D656E64
    MeroiticCursive => 0x6D657263
    MeroiticHieroglyphs => 0x6D65726F
    Malayalam => 0x6D6C6D32
    Modi => 0x6D6F6469
    Mongolian => 0x6D6F6E67
    Mro => 0x6D726F6F
    MeeteiMayek => 0x6D746569
    Multani => 0x6D756C74
    Myanmar => 0x6D796D32
    Nandinagari => 0x6E616E64
    OldNorthArabian => 0x6E617262
    Nabataean => 0x6E626174
    Newa => 0x6E657761
    Nko => 0x6E6B6F6F
    Nushu => 0x6E736875
    Ogham => 0x6F67616D
    OlChiki => 0x6F6C636B
    OldTurkic => 0x6F726B68
    Oriya => 0x6F727932
    Osage => 0x6F736765
    Osmanya => 0x6F736D61
    Palmyrene => 0x70616C6D
    PauCinHau => 0x70617563
    OldPermic => 0x7065726D
    PhagsPa => 0x70686167
    InscriptionalPahlavi => 0x70686C69
    PsalterPahlavi => 0x70686C70
    Phoenician => 0x70686E78
    Miao => 0x6D69616F
    InscriptionalParthian => 0x70727469
    Rejang => 0x726A6E67
    HanifiRohingya => 0x726F6867
    Runic => 0x72756E72
    Samaritan => 0x73616D72
    OldSouthArabian => 0x73617262
    Saurashtra => 0x73617572
    SignWriting => 0x73676E77
    Shavian => 0x73686177
    Sharada => 0x73687264
    Siddham => 0x73696464
    Khudawadi => 0x73696E64
    Sinhala => 0x73696E68
    Sogdian => 0x736F6764
    OldSogdian => 0x736F676F
    SoraSompeng => 0x736F7261
    Soyombo => 0x736F796F
    Sundanese => 0x73756E64
    SylotiNagri => 0x73796C6F
    Syriac => 0x73797263
    Tagbanwa => 0x74616762
    Takri => 0x74616B72
    TaiLe => 0x74616C65
    NewTaiLue => 0x74616C75
    Tamil => 0x746D6C32
    Tangut => 0x74616E67
    TaiViet => 0x74617674
    Telugu => 0x74656C75
    Tifinagh => 0x74666E67
    Tagalog => 0x74676C67
    Thaana => 0x74686161
    Thai => 0x74686169
    Tibetan => 0x74696274
    Tirhuta => 0x74697268
    Ugaritic => 0x75676172
    Vai => 0x76616969
    WarangCiti => 0x77617261
    Wancho => 0x7763686F
    OldPersian => 0x7870656F
    Cuneiform => 0x78737578
    Yezidi => 0x79657A69
    Yi => 0x79696969
    ZanabazarSquare => 0x7A616E62
    Inherited => 0x7A696E68
    Common => 0x7A797979
    Unknown => 0x7A7A7A7A
  }
}

///|
/// Returns the name of the script.
pub fn Script::name(self : Script) -> String {
  match self {
    Adlam => "Adlam"
    CaucasianAlbanian => "Caucasian Albanian"
    Ahom => "Ahom"
    Arabic => "Arabic"
    ImperialAramaic => "Imperial Aramaic"
    Armenian => "Armenian"
    Avestan => "Avestan"
    Balinese => "Balinese"
    Bamum => "Bamum"
    BassaVah => "Bassa Vah"
    Batak => "Batak"
    Bengali => "Bengali"
    Bhaiksuki => "Bhaiksuki"
    Bopomofo => "Bopomofo"
    Brahmi => "Brahmi"
    Braille => "Braille"
    Buginese => "Buginese"
    Buhid => "Buhid"
    Chakma => "Chakma"
    CanadianAboriginal => "Canadian Aboriginal"
    Carian => "Carian"
    Cham => "Cham"
    Cherokee => "Cherokee"
    Chorasmian => "Chorasmian"
    Coptic => "Coptic"
    Cypriot => "Cypriot"
    Cyrillic => "Cyrillic"
    Devanagari => "Devanagari"
    DivesAkuru => "Dives Akuru"
    Dogra => "Dogra"
    Deseret => "Deseret"
    Duployan => "Duployan"
    EgyptianHieroglyphs => "Egyptian Hieroglyphs"
    Elbasan => "Elbasan"
    Elymaic => "Elymaic"
    Ethiopic => "Ethiopic"
    Georgian => "Georgian"
    Glagolitic => "Glagolitic"
    GunjalaGondi => "Gunjala Gondi"
    MasaramGondi => "Masaram Gondi"
    Gothic => "Gothic"
    Grantha => "Grantha"
    Greek => "Greek"
    Gujarati => "Gujarati"
    Gurmukhi => "Gurmukhi"
    Hangul => "Hangul"
    Han => "Han"
    Hanunoo => "Hanunoo"
    Hatran => "Hatran"
    Hebrew => "Hebrew"
    Hiragana => "Hiragana"
    AnatolianHieroglyphs => "Anatolian Hieroglyphs"
    PahawhHmong => "Pahawh Hmong"
    NyiakengPuachueHmong => "Nyiakeng Puachue Hmong"
    OldHungarian => "Old Hungarian"
    OldItalic => "Old Italic"
    Javanese => "Javanese"
    KayahLi => "Kayah Li"
    Katakana => "Katakana"
    Kharoshthi => "Kharoshthi"
    Khmer => "Khmer"
    Khojki => "Khojki"
    KhitanSmallScript => "Khitan Small Script"
    Kannada => "Kannada"
    Kaithi => "Kaithi"
    TaiTham => "Tai Tham"
    Lao => "Lao"
    Latin => "Latin"
    Lepcha => "Lepcha"
    Limbu => "Limbu"
    LinearA => "Linear A"
    LinearB => "Linear B"
    Lisu => "Lisu"
    Lycian => "Lycian"
    Lydian => "Lydian"
    Mahajani => "Mahajani"
    Makasar => "Makasar"
    Mandaic => "Mandaic"
    Manichaean => "Manichaean"
    Marchen => "Marchen"
    Medefaidrin => "Medefaidrin"
    MendeKikakui => "Mende Kikakui"
    MeroiticCursive => "Meroitic Cursive"
    MeroiticHieroglyphs => "Meroitic Hieroglyphs"
    Malayalam => "Malayalam"
    Modi => "Modi"
    Mongolian => "Mongolian"
    Mro => "Mro"
    MeeteiMayek => "Meetei Mayek"
    Multani => "Multani"
    Myanmar => "Myanmar"
    Nandinagari => "Nandinagari"
    OldNorthArabian => "Old North Arabian"
    Nabataean => "Nabataean"
    Newa => "Newa"
    Nko => "Nko"
    Nushu => "Nushu"
    Ogham => "Ogham"
    OlChiki => "Ol Chiki"
    OldTurkic => "Old Turkic"
    Oriya => "Oriya"
    Osage => "Osage"
    Osmanya => "Osmanya"
    Palmyrene => "Palmyrene"
    PauCinHau => "Pau Cin Hau"
    OldPermic => "Old Permic"
    PhagsPa => "Phags Pa"
    InscriptionalPahlavi => "Inscriptional Pahlavi"
    PsalterPahlavi => "Psalter Pahlavi"
    Phoenician => "Phoenician"
    Miao => "Miao"
    InscriptionalParthian => "Inscriptional Parthian"
    Rejang => "Rejang"
    HanifiRohingya => "Hanifi Rohingya"
    Runic => "Runic"
    Samaritan => "Samaritan"
    OldSouthArabian => "Old South Arabian"
    Saurashtra => "Saurashtra"
    SignWriting => "SignWriting"
    Shavian => "Shavian"
    Sharada => "Sharada"
    Siddham => "Siddham"
    Khudawadi => "Khudawadi"
    Sinhala => "Sinhala"
    Sogdian => "Sogdian"
    OldSogdian => "Old Sogdian"
    SoraSompeng => "Sora Sompeng"
    Soyombo => "Soyombo"
    Sundanese => "Sundanese"
    SylotiNagri => "Syloti Nagri"
    Syriac => "Syriac"
    Tagbanwa => "Tagbanwa"
    Takri => "Takri"
    TaiLe => "Tai Le"
    NewTaiLue => "New Tai Lue"
    Tamil => "Tamil"
    Tangut => "Tangut"
    TaiViet => "Tai Viet"
    Telugu => "Telugu"
    Tifinagh => "Tifinagh"
    Tagalog => "Tagalog"
    Thaana => "Thaana"
    Thai => "Thai"
    Tibetan => "Tibetan"
    Tirhuta => "Tirhuta"
    Ugaritic => "Ugaritic"
    Vai => "Vai"
    WarangCiti => "Warang Citi"
    Wancho => "Wancho"
    OldPersian => "Old Persian"
    Cuneiform => "Cuneiform"
    Yezidi => "Yezidi"
    Yi => "Yi"
    ZanabazarSquare => "Zanabazar Square"
    Inherited => "Inherited"
    Common => "Common"
    Unknown => "Unknown"
  }
}

///|
/// Returns true if the script requires complex shaping.
pub fn Script::is_complex(self : Script) -> Bool {
  match self {
    Adlam => true
    CaucasianAlbanian => false
    Ahom => true
    Arabic => false
    ImperialAramaic => false
    Armenian => false
    Avestan => false
    Balinese => true
    Bamum => false
    BassaVah => false
    Batak => true
    Bengali => true
    Bhaiksuki => true
    Bopomofo => false
    Brahmi => true
    Braille => false
    Buginese => true
    Buhid => true
    Chakma => true
    CanadianAboriginal => false
    Carian => false
    Cham => true
    Cherokee => false
    Chorasmian => false
    Coptic => false
    Cypriot => false
    Cyrillic => false
    Devanagari => true
    DivesAkuru => false
    Dogra => true
    Deseret => false
    Duployan => true
    EgyptianHieroglyphs => true
    Elbasan => false
    Elymaic => true
    Ethiopic => false
    Georgian => false
    Glagolitic => false
    GunjalaGondi => true
    MasaramGondi => true
    Gothic => false
    Grantha => true
    Greek => false
    Gujarati => true
    Gurmukhi => true
    Hangul => false
    Han => false
    Hanunoo => true
    Hatran => false
    Hebrew => false
    Hiragana => false
    AnatolianHieroglyphs => false
    PahawhHmong => true
    NyiakengPuachueHmong => true
    OldHungarian => false
    OldItalic => false
    Javanese => true
    KayahLi => false
    Katakana => false
    Kharoshthi => true
    Khmer => true
    Khojki => true
    KhitanSmallScript => false
    Kannada => true
    Kaithi => true
    TaiTham => true
    Lao => false
    Latin => false
    Lepcha => true
    Limbu => true
    LinearA => false
    LinearB => false
    Lisu => false
    Lycian => false
    Lydian => false
    Mahajani => true
    Makasar => true
    Mandaic => true
    Manichaean => true
    Marchen => true
    Medefaidrin => true
    MendeKikakui => false
    MeroiticCursive => false
    MeroiticHieroglyphs => false
    Malayalam => true
    Modi => true
    Mongolian => false
    Mro => false
    MeeteiMayek => false
    Multani => true
    Myanmar => true
    Nandinagari => true
    OldNorthArabian => false
    Nabataean => false
    Newa => true
    Nko => false
    Nushu => false
    Ogham => false
    OlChiki => false
    OldTurkic => false
    Oriya => true
    Osage => false
    Osmanya => false
    Palmyrene => false
    PauCinHau => false
    OldPermic => false
    PhagsPa => false
    InscriptionalPahlavi => false
    PsalterPahlavi => true
    Phoenician => false
    Miao => true
    InscriptionalParthian => false
    Rejang => true
    HanifiRohingya => true
    Runic => false
    Samaritan => false
    OldSouthArabian => false
    Saurashtra => true
    SignWriting => false
    Shavian => false
    Sharada => true
    Siddham => true
    Khudawadi => true
    Sinhala => true
    Sogdian => true
    OldSogdian => true
    SoraSompeng => false
    Soyombo => true
    Sundanese => true
    SylotiNagri => true
    Syriac => false
    Tagbanwa => true
    Takri => true
    TaiLe => false
    NewTaiLue => false
    Tamil => true
    Tangut => false
    TaiViet => true
    Telugu => true
    Tifinagh => true
    Tagalog => true
    Thaana => false
    Thai => false
    Tibetan => true
    Tirhuta => true
    Ugaritic => false
    Vai => false
    WarangCiti => false
    Wancho => true
    OldPersian => false
    Cuneiform => false
    Yezidi => false
    Yi => false
    ZanabazarSquare => true
    Inherited => false
    Common => false
    Unknown => false
  }
}

///|
/// Returns true if the script has cursive joining.
pub fn Script::is_joined(self : Script) -> Bool {
  match self {
    Adlam => true
    CaucasianAlbanian => false
    Ahom => false
    Arabic => true
    ImperialAramaic => false
    Armenian => false
    Avestan => false
    Balinese => false
    Bamum => false
    BassaVah => false
    Batak => false
    Bengali => false
    Bhaiksuki => false
    Bopomofo => false
    Brahmi => false
    Braille => false
    Buginese => false
    Buhid => false
    Chakma => false
    CanadianAboriginal => false
    Carian => false
    Cham => false
    Cherokee => false
    Chorasmian => false
    Coptic => false
    Cypriot => false
    Cyrillic => false
    Devanagari => false
    DivesAkuru => false
    Dogra => false
    Deseret => false
    Duployan => false
    EgyptianHieroglyphs => false
    Elbasan => false
    Elymaic => false
    Ethiopic => false
    Georgian => false
    Glagolitic => false
    GunjalaGondi => false
    MasaramGondi => false
    Gothic => false
    Grantha => false
    Greek => false
    Gujarati => false
    Gurmukhi => false
    Hangul => false
    Han => false
    Hanunoo => false
    Hatran => false
    Hebrew => false
    Hiragana => false
    AnatolianHieroglyphs => false
    PahawhHmong => false
    NyiakengPuachueHmong => false
    OldHungarian => false
    OldItalic => false
    Javanese => false
    KayahLi => false
    Katakana => false
    Kharoshthi => false
    Khmer => false
    Khojki => false
    KhitanSmallScript => false
    Kannada => false
    Kaithi => false
    TaiTham => false
    Lao => false
    Latin => false
    Lepcha => false
    Limbu => false
    LinearA => false
    LinearB => false
    Lisu => false
    Lycian => false
    Lydian => false
    Mahajani => false
    Makasar => false
    Mandaic => true
    Manichaean => true
    Marchen => false
    Medefaidrin => false
    MendeKikakui => false
    MeroiticCursive => false
    MeroiticHieroglyphs => false
    Malayalam => false
    Modi => false
    Mongolian => true
    Mro => false
    MeeteiMayek => false
    Multani => false
    Myanmar => false
    Nandinagari => false
    OldNorthArabian => false
    Nabataean => false
    Newa => false
    Nko => true
    Nushu => false
    Ogham => false
    OlChiki => false
    OldTurkic => false
    Oriya => false
    Osage => false
    Osmanya => false
    Palmyrene => false
    PauCinHau => false
    OldPermic => false
    PhagsPa => true
    InscriptionalPahlavi => false
    PsalterPahlavi => true
    Phoenician => false
    Miao => false
    InscriptionalParthian => false
    Rejang => false
    HanifiRohingya => false
    Runic => false
    Samaritan => false
    OldSouthArabian => false
    Saurashtra => false
    SignWriting => false
    Shavian => false
    Sharada => false
    Siddham => false
    Khudawadi => false
    Sinhala => false
    Sogdian => false
    OldSogdian => false
    SoraSompeng => false
    Soyombo => false
    Sundanese => false
    SylotiNagri => false
    Syriac => true
    Tagbanwa => false
    Takri => false
    TaiLe => false
    NewTaiLue => false
    Tamil => false
    Tangut => false
    TaiViet => false
    Telugu => false
    Tifinagh => false
    Tagalog => false
    Thaana => false
    Thai => false
    Tibetan => false
    Tirhuta => false
    Ugaritic => false
    Vai => false
    WarangCiti => false
    Wancho => false
    OldPersian => false
    Cuneiform => false
    Yezidi => false
    Yi => false
    ZanabazarSquare => false
    Inherited => false
    Common => false
    Unknown => false
  }
}
