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
    pub const ZERO_TO_ADDRESS: felt252 = 'To address cannot be zero';
    pub const ZERO_FROM_ADDRESS: felt252 = 'From address cannot be zero';
    pub const MINT_AMOUNT_NOT_GREATER_THAN_ZERO: felt252 = 'Mint amount must be > 0';
    pub const MINT_AMOUNT_EXCEEDS_ALLOWANCE: felt252 = 'Mint amount exceeds allowance';
    pub const BURN_AMOUNT_NOT_GREATER_THAN_ZERO: felt252 = 'Burn amount must be > 0';
    pub const BURN_AMOUNT_EXCEEDS_BALANCE: felt252 = 'Burn amount exceeds balance';
    pub const TRANSFER_AMOUNT_EXCEEDS_BALANCE: felt252 = 'Transfer amount exceeds balance';
    pub const TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE: felt252 = 'Transfer allowance exceeded';
}
