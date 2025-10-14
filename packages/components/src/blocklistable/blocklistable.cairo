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
pub mod BlocklistableComponent {
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::blocklistable::errors::Errors;
    // Re-export events for external access
    pub use crate::blocklistable::events::{Blocklisted, BlocklisterChanged, Unblocklisted};
    use crate::ownable::OwnableComponent;
    use crate::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;

    #[storage]
    pub struct Storage {
        blocklister: ContractAddress,
        blocklisted: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        BlocklisterChanged: BlocklisterChanged,
        Blocklisted: Blocklisted,
        Unblocklisted: Unblocklisted,
    }

    #[embeddable_as(Blocklistable)]
    pub impl BlocklistableImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
    > of crate::blocklistable::interface::IBlocklistable<ComponentState<TContractState>> {
        /// Returns the address of the current blocklister
        fn blocklister(self: @ComponentState<TContractState>) -> ContractAddress {
            self.blocklister.read()
        }

        /// Updates the blocklister address
        ///
        /// Only the owner can call this function
        ///
        /// # Arguments
        ///
        /// * `new_blocklister` - The new blocklister address
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the owner
        /// - `new_blocklister` is the zero address
        fn update_blocklister(
            ref self: ComponentState<TContractState>, new_blocklister: ContractAddress,
        ) {
            // Only owner can update blocklister
            let ownable_component = get_dep_component!(@self, Owner);
            ownable_component.assert_only_owner();

            // Validate new blocklister is not zero address
            assert(!new_blocklister.is_zero(), Errors::ZERO_ADDRESS_BLOCKLISTER);

            // Get old blocklister for event
            let old_blocklister = self.blocklister.read();

            // Update blocklister
            self.blocklister.write(new_blocklister);

            // Emit event
            self.emit(BlocklisterChanged { old_blocklister, new_blocklister });
        }

        /// Adds an address to the blocklist
        ///
        /// Only the blocklister can call this function
        ///
        /// # Arguments
        ///
        /// * `address` - The address to add to the blocklist
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the blocklister
        /// - `address` is the zero address
        fn blocklist(ref self: ComponentState<TContractState>, address: ContractAddress) {
            // Only blocklister can blocklist addresses
            self.assert_only_blocklister();

            // Add to blocklist
            self._blocklist(address);
        }

        /// Removes an address from the blocklist
        ///
        /// Only the blocklister can call this function
        ///
        /// # Arguments
        ///
        /// * `address` - The address to remove from the blocklist
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the blocklister
        /// - `address` is the zero address
        fn unblocklist(ref self: ComponentState<TContractState>, address: ContractAddress) {
            // Only blocklister can unblocklist addresses
            self.assert_only_blocklister();

            // Validate address is not zero
            assert(!address.is_zero(), Errors::ZERO_ADDRESS);

            // Remove from blocklist
            self.blocklisted.write(address, false);

            // Emit event
            self.emit(Unblocklisted { address });
        }

        /// Checks if an address is blocklisted
        ///
        /// # Arguments
        ///
        /// * `address` - The address to check
        ///
        /// # Returns
        ///
        /// True if the address is blocklisted, false otherwise
        fn is_blocklisted(self: @ComponentState<TContractState>, address: ContractAddress) -> bool {
            self.blocklisted.read(address)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, blocklister: ContractAddress) {
            // Validate blocklister is not zero address
            assert(!blocklister.is_zero(), Errors::ZERO_ADDRESS_BLOCKLISTER);
            assert(self.blocklister.read().is_zero(), Errors::ALREADY_INITIALIZED);
            // Set initial blocklister
            self.blocklister.write(blocklister);
        }

        fn assert_only_blocklister(self: @ComponentState<TContractState>) {
            // Verify caller is the blocklister
            let blocklister = self.blocklister.read();
            let caller = get_caller_address();
            assert(caller == blocklister, Errors::NOT_BLOCKLISTER);
        }

        fn assert_not_blocklisted(self: @ComponentState<TContractState>, address: ContractAddress) {
            // Check if address is blocklisted and revert if it is
            let is_blocklisted = self.blocklisted.read(address);
            assert(!is_blocklisted, Errors::BLOCKLISTED);
        }

        fn _blocklist(ref self: ComponentState<TContractState>, address: ContractAddress) {
            // Validate address is not zero
            assert(!address.is_zero(), Errors::ZERO_ADDRESS);

            // Add to blocklist
            self.blocklisted.write(address, true);

            // Emit event
            self.emit(Blocklisted { address });
        }
    }
}
