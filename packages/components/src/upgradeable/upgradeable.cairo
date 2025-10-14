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

#[starknet::component]
pub mod UpgradeableComponent {
    use core::num::traits::Zero;
    use starknet::{ClassHash, SyscallResultTrait};
    use crate::manageable::ManageableComponent;
    use crate::manageable::ManageableComponent::InternalTrait as ManageableInternalTrait;
    use crate::upgradeable::errors::Errors;
    // Re-export events for external access
    pub use crate::upgradeable::events::ContractUpgraded;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ContractUpgraded: ContractUpgraded,
    }

    #[embeddable_as(Upgradeable)]
    pub impl UpgradeableImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Admin: ManageableComponent::HasComponent<TContractState>,
    > of crate::upgradeable::interface::IUpgradeable<ComponentState<TContractState>> {
        /// Upgrades the contract to a new implementation
        ///
        /// Only the admin can call this function
        ///
        /// # Arguments
        ///
        /// * `new_class_hash` - The new contract class hash to upgrade to
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the admin
        /// - `new_class_hash` is zero
        /// - The upgrade syscall fails
        fn upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            // Only admin can upgrade the contract
            let manageable_component = get_dep_component!(@self, Admin);
            manageable_component.assert_only_admin();

            // Validate class hash is not zero
            assert(!new_class_hash.is_zero(), Errors::INVALID_CLASS);

            // Replace the current class with the new one
            starknet::syscalls::replace_class_syscall(new_class_hash).unwrap_syscall();

            // Emit upgrade event
            self.emit(ContractUpgraded { class_hash: new_class_hash });
        }
    }
}
