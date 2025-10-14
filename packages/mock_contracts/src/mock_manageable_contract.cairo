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
pub trait IMockManageableContract<TContractState> {
    fn test_initializer(ref self: TContractState, admin: ContractAddress);
    fn test_assert_only_admin(self: @TContractState);
    fn test_transfer_admin_internal(ref self: TContractState, new_admin: ContractAddress);
    fn test_propose_admin_internal(ref self: TContractState, new_admin: ContractAddress);
}

// Mock contract that uses the manageable component for testing
#[starknet::contract]
pub mod MockManageableContract {
    use components::manageable::ManageableComponent;
    use components::manageable::ManageableComponent::InternalTrait as ManageableInternalTrait;
    use core::num::traits::Zero;
    use starknet::ContractAddress;

    component!(path: ManageableComponent, storage: manageable, event: ManageableEvent);

    #[abi(embed_v0)]
    impl ManageableImpl = ManageableComponent::Manageable<ContractState>;
    impl InternalImpl = ManageableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        manageable: ManageableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ManageableEvent: ManageableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        if !admin.is_zero() {
            self.manageable.initializer(admin);
        }
    }

    // Expose internal functions for testing
    #[abi(per_item)]
    #[generate_trait]
    impl MockManageableContractImpl of MockManageableContractTrait {
        #[external(v0)]
        fn test_initializer(ref self: ContractState, admin: ContractAddress) {
            self.manageable.initializer(admin);
        }

        #[external(v0)]
        fn test_assert_only_admin(self: @ContractState) {
            self.manageable.assert_only_admin();
        }

        #[external(v0)]
        fn test_transfer_admin_internal(ref self: ContractState, new_admin: ContractAddress) {
            self.manageable._transfer_admin(new_admin);
        }

        #[external(v0)]
        fn test_propose_admin_internal(ref self: ContractState, new_admin: ContractAddress) {
            self.manageable._propose_admin(new_admin);
        }
    }
}
