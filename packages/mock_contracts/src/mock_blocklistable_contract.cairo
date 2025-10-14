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
pub trait IMockBlocklistableContract<TContractState> {
    fn test_blocklistable_initializer(ref self: TContractState, blocklister: ContractAddress);
    fn test_assert_only_blocklister(self: @TContractState);
    fn test_assert_not_blocklisted(self: @TContractState, address: ContractAddress);
    fn test_ownable_initializer(ref self: TContractState, owner: ContractAddress);
}

// Mock contract that uses both ownable and blocklistable components for testing
#[starknet::contract]
pub mod MockBlocklistableContract {
    use components::blocklistable::BlocklistableComponent;
    use components::ownable::OwnableComponent;
    use core::num::traits::Zero;
    use starknet::ContractAddress;

    component!(path: BlocklistableComponent, storage: blocklistable, event: BlocklistableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::Ownable<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl BlocklistableImpl = BlocklistableComponent::Blocklistable<ContractState>;
    impl BlocklistableInternalImpl = BlocklistableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        blocklistable: BlocklistableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        BlocklistableEvent: BlocklistableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, blocklister: ContractAddress) {
        if !owner.is_zero() {
            self.ownable.initializer(owner);
        }
        if !blocklister.is_zero() {
            self.blocklistable.initializer(blocklister);
        }
    }

    // Expose internal functions for testing
    #[abi(per_item)]
    #[generate_trait]
    impl MockBlocklistableContractImpl of MockBlocklistableContractTrait {
        #[external(v0)]
        fn test_blocklistable_initializer(ref self: ContractState, blocklister: ContractAddress) {
            self.blocklistable.initializer(blocklister);
        }

        #[external(v0)]
        fn test_assert_only_blocklister(self: @ContractState) {
            self.blocklistable.assert_only_blocklister();
        }

        #[external(v0)]
        fn test_assert_not_blocklisted(self: @ContractState, address: ContractAddress) {
            self.blocklistable.assert_not_blocklisted(address);
        }

        #[external(v0)]
        fn test_ownable_initializer(ref self: ContractState, owner: ContractAddress) {
            self.ownable.initializer(owner);
        }
    }
}
