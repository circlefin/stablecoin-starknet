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
pub mod MetadataComponent {
    use components::ownable::OwnableComponent;
    use components::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;
    use core::num::traits::Zero;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use crate::metadata::errors::Errors;
    // Re-export events for external access
    pub use crate::metadata::events::{MetadataUpdated, MetadataUpgraderUpdated};

    #[storage]
    pub struct Storage {
        metadata_updater: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MetadataUpdated: MetadataUpdated,
        MetadataUpgraderUpdated: MetadataUpgraderUpdated,
    }

    #[embeddable_as(Metadata)]
    pub impl MetadataImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
    > of crate::metadata::interface::IMetadata<ComponentState<TContractState>> {
        /// Returns the address of the current metadata updater
        fn metadata_updater(self: @ComponentState<TContractState>) -> ContractAddress {
            self.metadata_updater.read()
        }

        /// Updates the metadata updater address
        ///
        /// Only the owner can call this function
        ///
        /// # Arguments
        ///
        /// * `new_metadata_updater` - The new metadata updater address
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the owner
        /// - `new_metadata_updater` is the zero address
        fn update_metadata_updater(
            ref self: ComponentState<TContractState>, new_metadata_updater: ContractAddress,
        ) {
            // Only owner can update metadata updater
            let ownable_component = get_dep_component!(@self, Owner);
            ownable_component.assert_only_owner();

            // Validate new metadata updater is not zero address
            assert(!new_metadata_updater.is_zero(), Errors::ZERO_ADDRESS_METADATA_UPDATER);

            // Capture old metadata updater before updating
            let old_metadata_updater = self.metadata_updater.read();

            // Update metadata updater
            self.metadata_updater.write(new_metadata_updater);

            // Emit event
            self.emit(MetadataUpgraderUpdated { old_metadata_updater, new_metadata_updater });
        }

        /// Returns the name of the fiat token
        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            self.name.read()
        }

        /// Returns the symbol of the fiat token
        fn symbol(self: @ComponentState<TContractState>) -> ByteArray {
            self.symbol.read()
        }

        /// Returns the decimals of the fiat token
        fn decimals(self: @ComponentState<TContractState>) -> u8 {
            self.decimals.read()
        }

        /// Updates the metadata
        ///
        /// Only the metadata updater can call this function
        ///
        /// # Arguments
        ///
        /// * `name` - The new name of the fiat token
        /// * `symbol` - The new symbol of the fiat token
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the metadata updater
        /// - `name` is empty
        /// - `symbol` is empty
        fn update_metadata(
            ref self: ComponentState<TContractState>, name: ByteArray, symbol: ByteArray,
        ) {
            // Only metadata updater can update metadata
            self.assert_only_metadata_updater();
            assert(name.len() > 0, Errors::INVALID_NAME);
            assert(symbol.len() > 0, Errors::INVALID_SYMBOL);

            // Update metadata
            self.name.write(name.clone());
            self.symbol.write(symbol.clone());

            // Emit event when metadata is updated
            self.emit(MetadataUpdated { name, symbol, decimals: self.decimals.read() });
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the metadata component
        ///
        /// # Arguments
        ///
        /// * `metadata_updater` - The address of the metadata updater
        /// * `name` - The name of the fiat token
        /// * `symbol` - The symbol of the fiat token
        /// * `decimals` - The decimals of the fiat token
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - `metadata_updater` is the zero address
        /// - The component is already initialized
        /// - `name` is empty
        /// - `symbol` is empty
        /// - `decimals` is not greater than 0
        fn initializer(
            ref self: ComponentState<TContractState>,
            metadata_updater: ContractAddress,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8,
        ) {
            assert(!metadata_updater.is_zero(), Errors::ZERO_ADDRESS_METADATA_UPDATER);
            assert(self.metadata_updater.read().is_zero(), Errors::ALREADY_INITIALIZED);
            assert(name.len() > 0, Errors::INVALID_NAME);
            assert(symbol.len() > 0, Errors::INVALID_SYMBOL);
            assert(decimals > 0, Errors::INVALID_DECIMALS);

            self.metadata_updater.write(metadata_updater);
            self.name.write(name);
            self.symbol.write(symbol);
            self.decimals.write(decimals);
        }

        /// Asserts that the caller is the metadata updater
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the metadata updater
        fn assert_only_metadata_updater(self: @ComponentState<TContractState>) {
            let metadata_updater = self.metadata_updater.read();
            let caller = get_caller_address();
            assert(caller == metadata_updater, Errors::NOT_METADATA_UPDATER);
        }
    }
}
