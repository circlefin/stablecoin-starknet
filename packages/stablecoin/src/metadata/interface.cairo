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
pub trait IMetadata<TContractState> {
    /// Returns the address of the current metadata updater
    fn metadata_updater(self: @TContractState) -> ContractAddress;
    /// Updates the metadata updater address
    fn update_metadata_updater(ref self: TContractState, new_metadata_updater: ContractAddress);
    /// Returns the name of the fiat token
    fn name(self: @TContractState) -> ByteArray;
    /// Returns the symbol of the fiat token
    fn symbol(self: @TContractState) -> ByteArray;
    /// Returns the decimals of the fiat token
    fn decimals(self: @TContractState) -> u8;
    fn update_metadata(ref self: TContractState, name: ByteArray, symbol: ByteArray);
}
