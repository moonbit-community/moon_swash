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
pub extend Attributes with Eq::{not_equal, equal}

///|
pub extend Attributes with Show::{to_string, output}

///|
pub extend Style with Eq::{not_equal, equal}

///|
pub extend Style with Show::{output}

///|
pub extend Weight with Show::{output}

///|
pub extend Weight with Eq::{not_equal, equal}

///|
pub extend Weight with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend Stretch with Show::{output}

///|
pub extend Stretch with Eq::{not_equal, equal}

///|
pub extend Stretch with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend Synthesis with Eq::{not_equal, equal}

///|
pub extend FontRef with TableProvider::{table_by_tag}

///|
pub extend Language with Show::{output}
