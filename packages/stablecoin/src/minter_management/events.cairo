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

/// Emitted when the master minter address is changed
#[derive(Drop, starknet::Event)]
pub struct MasterMinterChanged {
    #[key]
    pub old_master_minter: ContractAddress,
    #[key]
    pub new_master_minter: ContractAddress,
}

/// Emitted when a minter is configured with an allowance
#[derive(Drop, starknet::Event)]
pub struct MinterConfigured {
    #[key]
    pub controller: ContractAddress,
    #[key]
    pub minter: ContractAddress,
    pub allowance: u256,
}

/// Emitted when a minter is removed and its allowance is reset
#[derive(Drop, starknet::Event)]
pub struct MinterRemoved {
    #[key]
    pub controller: ContractAddress,
    #[key]
    pub minter: ContractAddress,
}

/// Emitted when a minter's allowance is incremented
#[derive(Drop, starknet::Event)]
pub struct MinterAllowanceIncremented {
    #[key]
    pub controller: ContractAddress,
    #[key]
    pub minter: ContractAddress,
    pub allowance_increment: u256,
    pub new_allowance: u256,
}

/// Emitted when a controller-minter relationship is established
#[derive(Drop, starknet::Event)]
pub struct ControllerConfigured {
    #[key]
    pub controller: ContractAddress,
    #[key]
    pub minter: ContractAddress,
}

/// Emitted when a controller is removed
#[derive(Drop, starknet::Event)]
pub struct ControllerRemoved {
    #[key]
    pub controller: ContractAddress,
}
