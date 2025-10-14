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
    pub const ZERO_ADDRESS_METADATA_UPDATER: felt252 = 'Metadata updater cannot be zero';
    pub const NOT_METADATA_UPDATER: felt252 = 'Caller is not metadata updater';
    pub const ALREADY_INITIALIZED: felt252 = 'Contract already initialized';
    pub const INVALID_NAME: felt252 = 'Name must be non-empty';
    pub const INVALID_SYMBOL: felt252 = 'Symbol must be non-empty';
    pub const INVALID_DECIMALS: felt252 = 'Decimals must be greater than 0';
}
