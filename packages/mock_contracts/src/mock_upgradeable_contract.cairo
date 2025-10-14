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

#[starknet::contract]
pub mod MockUpgradeableContract {
    use components::manageable::ManageableComponent;
    use components::manageable::ManageableComponent::InternalTrait as ManageableInternalTrait;
    use components::upgradeable::UpgradeableComponent;
    use core::num::traits::Zero;
    use starknet::ContractAddress;

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: ManageableComponent, storage: manageable, event: ManageableEvent);

    #[abi(embed_v0)]
    impl UpgradeableImpl = UpgradeableComponent::Upgradeable<ContractState>;
    #[abi(embed_v0)]
    impl ManageableImpl = ManageableComponent::Manageable<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        manageable: ManageableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        ManageableEvent: ManageableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        if !admin.is_zero() {
            self.manageable.initializer(admin);
        }
    }
}
