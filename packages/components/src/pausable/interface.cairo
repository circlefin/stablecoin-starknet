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
pub trait IPausable<TContractState> {
    fn pauser(self: @TContractState) -> ContractAddress;
    fn update_pauser(ref self: TContractState, new_pauser: ContractAddress);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn paused(self: @TContractState) -> bool;
}
