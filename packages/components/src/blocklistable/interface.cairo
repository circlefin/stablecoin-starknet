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
pub trait IBlocklistable<TContractState> {
    fn blocklister(self: @TContractState) -> ContractAddress;
    fn update_blocklister(ref self: TContractState, new_blocklister: ContractAddress);
    fn blocklist(ref self: TContractState, address: ContractAddress);
    fn unblocklist(ref self: TContractState, address: ContractAddress);
    fn is_blocklisted(self: @TContractState, address: ContractAddress) -> bool;
}
