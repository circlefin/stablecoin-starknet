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
pub trait IMockDenylistableContract<TContractState> {
    fn test_denylistable_initializer(ref self: TContractState, denylister: ContractAddress);
    fn test_assert_only_denylister(self: @TContractState);
    fn test_assert_not_denylisted(self: @TContractState, address: ContractAddress);
    fn test_ownable_initializer(ref self: TContractState, owner: ContractAddress);
}

// Mock contract that uses both ownable and denylistable components for testing
#[starknet::contract]
pub mod MockDenylistableContract {
    use components::denylistable::DenylistableComponent;
    use components::ownable::OwnableComponent;
    use core::num::traits::Zero;
    use starknet::ContractAddress;

    component!(path: DenylistableComponent, storage: denylistable, event: DenylistableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::Ownable<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl DenylistableImpl = DenylistableComponent::Denylistable<ContractState>;
    impl DenylistableInternalImpl = DenylistableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        denylistable: DenylistableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        DenylistableEvent: DenylistableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, denylister: ContractAddress) {
        if !owner.is_zero() {
            self.ownable.initializer(owner);
        }
        if !denylister.is_zero() {
            self.denylistable.initializer(denylister);
        }
    }

    // Expose internal functions for testing
    #[abi(per_item)]
    #[generate_trait]
    impl MockDenylistableContractImpl of MockDenylistableContractTrait {
        #[external(v0)]
        fn test_denylistable_initializer(ref self: ContractState, denylister: ContractAddress) {
            self.denylistable.initializer(denylister);
        }

        #[external(v0)]
        fn test_assert_only_denylister(self: @ContractState) {
            self.denylistable.assert_only_denylister();
        }

        #[external(v0)]
        fn test_assert_not_denylisted(self: @ContractState, address: ContractAddress) {
            self.denylistable.assert_not_denylisted(address);
        }

        #[external(v0)]
        fn test_ownable_initializer(ref self: ContractState, owner: ContractAddress) {
            self.ownable.initializer(owner);
        }
    }
}
