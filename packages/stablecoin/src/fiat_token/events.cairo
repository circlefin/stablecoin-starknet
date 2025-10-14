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

#[derive(Drop, starknet::Event)]
pub struct FiatTokenInitialized {
    pub initialized_version: u8,
}

#[derive(Drop, starknet::Event)]
pub struct Mint {
    #[key]
    pub minter: ContractAddress,
    #[key]
    pub to: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Burn {
    #[key]
    pub burner: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Transfer {
    #[key]
    pub from: ContractAddress,
    #[key]
    pub to: ContractAddress,
    pub value: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Approval {
    #[key]
    pub owner: ContractAddress,
    #[key]
    pub spender: ContractAddress,
    pub value: u256,
}
