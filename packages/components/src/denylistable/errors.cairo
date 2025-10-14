// Copyright (c) 2025 Circle Internet Group, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
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

pub mod Errors {
    pub const ZERO_ADDRESS_DENYLISTER: felt252 = 'Denylister cannot be zero';
    pub const NOT_DENYLISTER: felt252 = 'Caller is not the denylister';
    pub const DENYLISTED: felt252 = 'Address is denylisted';
    pub const ZERO_ADDRESS: felt252 = 'Cannot denylist zero address';
    pub const ALREADY_INITIALIZED: felt252 = 'Contract already initialized';
}
