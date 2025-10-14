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
pub trait IMockPausableContract<TContractState> {
    fn test_pausable_initializer(ref self: TContractState, pauser: ContractAddress);
    fn test_assert_only_pauser(self: @TContractState);
    fn test_assert_not_paused(self: @TContractState);
    fn test_ownable_initializer(ref self: TContractState, owner: ContractAddress);
}

// Mock contract that uses both ownable and pausable components for testing
#[starknet::contract]
pub mod MockPausableContract {
    use components::ownable::OwnableComponent;
    use components::pausable::PausableComponent;
    use core::num::traits::Zero;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::Ownable<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::Pausable<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, pauser: ContractAddress) {
        if !owner.is_zero() {
            self.ownable.initializer(owner);
        }
        if !pauser.is_zero() {
            self.pausable.initializer(pauser);
        }
    }

    // Expose internal functions for testing
    #[abi(per_item)]
    #[generate_trait]
    impl MockPausableContractImpl of MockPausableContractTrait {
        #[external(v0)]
        fn test_pausable_initializer(ref self: ContractState, pauser: ContractAddress) {
            self.pausable.initializer(pauser);
        }

        #[external(v0)]
        fn test_assert_only_pauser(self: @ContractState) {
            self.pausable.assert_only_pauser();
        }

        #[external(v0)]
        fn test_assert_not_paused(self: @ContractState) {
            self.pausable.assert_not_paused();
        }

        #[external(v0)]
        fn test_ownable_initializer(ref self: ContractState, owner: ContractAddress) {
            self.ownable.initializer(owner);
        }
    }
}
