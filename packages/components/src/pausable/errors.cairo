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
    pub const ZERO_ADDRESS_PAUSER: felt252 = 'Pauser cannot be zero address';
    pub const NOT_PAUSER: felt252 = 'Caller is not the pauser';
    pub const PAUSED: felt252 = 'Contract is paused';
    pub const NOT_PAUSED: felt252 = 'Contract is not paused';
    pub const ALREADY_INITIALIZED: felt252 = 'Contract already initialized';
}
