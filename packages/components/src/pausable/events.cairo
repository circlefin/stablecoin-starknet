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

use starknet::ContractAddress;

/// Emitted when the contract is paused
#[derive(Drop, starknet::Event)]
pub struct Paused {}

/// Emitted when the contract is unpaused
#[derive(Drop, starknet::Event)]
pub struct Unpaused {}

/// Emitted when the pauser address is changed
#[derive(Drop, starknet::Event)]
pub struct PauserChanged {
    #[key]
    pub old_pauser: ContractAddress,
    #[key]
    pub new_pauser: ContractAddress,
}
