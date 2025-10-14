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
pub trait IMockOwnableContract<TContractState> {
    fn test_initializer(ref self: TContractState, owner: ContractAddress);
    fn test_assert_only_owner(self: @TContractState);
    fn test_transfer_ownership_internal(ref self: TContractState, new_owner: ContractAddress);
    fn test_propose_owner_internal(ref self: TContractState, new_owner: ContractAddress);
}

// Mock contract that uses the ownable component for testing
#[starknet::contract]
pub mod MockOwnableContract {
    use components::ownable::OwnableComponent;
    use core::num::traits::Zero;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::Ownable<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        if !owner.is_zero() {
            self.ownable.initializer(owner);
        }
    }

    // Expose internal functions for testing
    #[abi(per_item)]
    #[generate_trait]
    impl MockOwnableContractImpl of MockOwnableContractTrait {
        #[external(v0)]
        fn test_initializer(ref self: ContractState, owner: ContractAddress) {
            self.ownable.initializer(owner);
        }

        #[external(v0)]
        fn test_assert_only_owner(self: @ContractState) {
            self.ownable.assert_only_owner();
        }

        #[external(v0)]
        fn test_transfer_ownership_internal(ref self: ContractState, new_owner: ContractAddress) {
            self.ownable._transfer_ownership(new_owner);
        }

        #[external(v0)]
        fn test_propose_owner_internal(ref self: ContractState, new_owner: ContractAddress) {
            self.ownable._propose_owner(new_owner);
        }
    }
}
