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

#[starknet::interface]
pub trait IMinterManagement<TContractState> {
    /// Configures a controller-minter relationship
    fn configure_controller(
        ref self: TContractState, controller: ContractAddress, minter: ContractAddress,
    );
    /// Removes a controller and its associated minter relationship
    fn remove_controller(ref self: TContractState, controller: ContractAddress);
    /// Updates the master minter address
    fn update_master_minter(ref self: TContractState, new_master_minter: ContractAddress);
    /// Returns the minter address associated with a controller
    fn get_minter(self: @TContractState, controller: ContractAddress) -> ContractAddress;
    /// Returns whether an address is an active minter
    fn is_minter(self: @TContractState, minter: ContractAddress) -> bool;
    /// Returns the minting allowance for a minter
    fn minter_allowance(self: @TContractState, minter: ContractAddress) -> u256;
    /// Returns the current master minter address
    fn master_minter(self: @TContractState) -> ContractAddress;
    /// Configures a minter with a specific allowance
    fn configure_minter(ref self: TContractState, minter_allowance: u256);
    /// Removes a minter and resets its allowance to zero
    fn remove_minter(ref self: TContractState);
    /// Increments a minter's allowance by a specified amount
    fn increment_minter_allowance(ref self: TContractState, increment: u256);
}
