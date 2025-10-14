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
pub mod DenylistableComponent {
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::denylistable::errors::Errors;
    // Re-export events for external access
    pub use crate::denylistable::events::{Denylisted, DenylisterChanged, Undenylisted};
    use crate::ownable::OwnableComponent;
    use crate::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;

    #[storage]
    pub struct Storage {
        denylister: ContractAddress,
        denylisted: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        DenylisterChanged: DenylisterChanged,
        Denylisted: Denylisted,
        Undenylisted: Undenylisted,
    }

    #[embeddable_as(Denylistable)]
    pub impl DenylistableImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
    > of crate::denylistable::interface::IDenylistable<ComponentState<TContractState>> {
        /// Returns the address of the current denylister
        fn denylister(self: @ComponentState<TContractState>) -> ContractAddress {
            self.denylister.read()
        }

        /// Updates the denylister address
        ///
        /// Only the owner can call this function
        ///
        /// # Arguments
        ///
        /// * `new_denylister` - The new denylister address
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the owner
        /// - `new_denylister` is the zero address
        fn update_denylister(
            ref self: ComponentState<TContractState>, new_denylister: ContractAddress,
        ) {
            // Only owner can update denylister
            let ownable_component = get_dep_component!(@self, Owner);
            ownable_component.assert_only_owner();

            // Validate new denylister is not zero address
            assert(!new_denylister.is_zero(), Errors::ZERO_ADDRESS_DENYLISTER);

            // Get old denylister for event
            let old_denylister = self.denylister.read();

            // Update denylister
            self.denylister.write(new_denylister);

            // Emit event
            self.emit(DenylisterChanged { old_denylister, new_denylister });
        }

        /// Adds an address to the denylist
        ///
        /// Only the denylister can call this function
        ///
        /// # Arguments
        ///
        /// * `address` - The address to add to the denylist
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the denylister
        /// - `address` is the zero address
        fn denylist(ref self: ComponentState<TContractState>, address: ContractAddress) {
            // Only denylister can denylist addresses
            self.assert_only_denylister();

            // Add to denylist
            self._denylist(address);
        }

        /// Removes an address from the denylist
        ///
        /// Only the denylister can call this function
        ///
        /// # Arguments
        ///
        /// * `address` - The address to remove from the denylist
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the denylister
        /// - `address` is the zero address
        fn undenylist(ref self: ComponentState<TContractState>, address: ContractAddress) {
            // Only denylister can undenylist addresses
            self.assert_only_denylister();

            // Validate address is not zero
            assert(!address.is_zero(), Errors::ZERO_ADDRESS);

            // Remove from denylist
            self.denylisted.write(address, false);

            // Emit event
            self.emit(Undenylisted { address });
        }

        /// Checks if an address is denylisted
        ///
        /// # Arguments
        ///
        /// * `address` - The address to check
        ///
        /// # Returns
        ///
        /// True if the address is denylisted, false otherwise
        fn is_denylisted(self: @ComponentState<TContractState>, address: ContractAddress) -> bool {
            self.denylisted.read(address)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, denylister: ContractAddress) {
            // Validate denylister is not zero address
            assert(!denylister.is_zero(), Errors::ZERO_ADDRESS_DENYLISTER);
            assert(self.denylister.read().is_zero(), Errors::ALREADY_INITIALIZED);
            // Set initial denylister
            self.denylister.write(denylister);
        }

        fn assert_only_denylister(self: @ComponentState<TContractState>) {
            // Verify caller is the denylister
            let denylister = self.denylister.read();
            let caller = get_caller_address();
            assert(caller == denylister, Errors::NOT_DENYLISTER);
        }

        fn assert_not_denylisted(self: @ComponentState<TContractState>, address: ContractAddress) {
            // Check if address is denylisted and revert if it is
            let is_denylisted = self.denylisted.read(address);
            assert(!is_denylisted, Errors::DENYLISTED);
        }

        fn _denylist(ref self: ComponentState<TContractState>, address: ContractAddress) {
            // Validate address is not zero
            assert(!address.is_zero(), Errors::ZERO_ADDRESS);

            // Add to denylist
            self.denylisted.write(address, true);

            // Emit event
            self.emit(Denylisted { address });
        }
    }
}
