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
    pub const ALREADY_INITIALIZED: felt252 = 'Contract already initialized';
    pub const ZERO_ADDRESS_CONTROLLER: felt252 = 'Controller cannot be zero';
    pub const ZERO_ADDRESS_MINTER: felt252 = 'Minter cannot be zero address';
    pub const ZERO_ADDRESS_MASTER_MINTER: felt252 = 'Master Minter cannot be zero';
    pub const INCREMENT_ZERO: felt252 = 'Increment amount cannot be zero';
    pub const DECREMENT_ZERO: felt252 = 'Decrement amount cannot be zero';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient minter allowance';
    pub const NOT_MASTER_MINTER: felt252 = 'Caller is not the master minter';
    pub const NOT_MINTER: felt252 = 'Caller is not a minter';
    pub const NOT_CONTROLLER_MINTER: felt252 = 'Minter is not configured';
    pub const NOT_CONTROLLER: felt252 = 'Caller is not a controller';
}
