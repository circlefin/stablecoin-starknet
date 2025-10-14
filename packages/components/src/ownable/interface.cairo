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
pub trait IOwnable<TContractState> {
    /// Returns the address of the current owner
    fn owner(self: @TContractState) -> ContractAddress;
    /// Returns the address of the pending owner (if any)
    fn pending_owner(self: @TContractState) -> ContractAddress;
    /// Proposes a new owner (two-step ownership transfer)
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    /// Accepts ownership transfer (must be called by pending owner)
    fn accept_ownership(ref self: TContractState);
}
