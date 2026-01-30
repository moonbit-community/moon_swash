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
/// Mapping complex text to a sequence of positioned glyphs.
///
/// This package is a strict port of `upstream swash/src/shape/*`.
pub type Tag = @swash.Tag

///|
pub type GlyphId = @swash.GlyphId

///|
pub type UserData = @swash.UserData

///|
pub type ClusterInfo = @swash.ClusterInfo

///|
pub type SourceRange = @swash.SourceRange

///|
pub type ShapeClass = @swash.ShapeClass

///|
pub type JoiningType = @swash.JoiningType

///|
pub type ClusterChar = @swash.ClusterChar

///|
pub type CharCluster = @swash.CharCluster

///|
pub const MAX_CLUSTER_SIZE : Int = @swash.MAX_CLUSTER_SIZE
