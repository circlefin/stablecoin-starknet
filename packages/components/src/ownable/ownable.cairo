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
pub mod OwnableComponent {
    use core::num::traits::Zero;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use crate::ownable::errors::Errors;
    // Re-export events for external access
    pub use crate::ownable::events::{OwnershipTransferStarted, OwnershipTransferred};

    #[storage]
    pub struct Storage {
        owner: ContractAddress,
        pending_owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        OwnershipTransferred: OwnershipTransferred,
        OwnershipTransferStarted: OwnershipTransferStarted,
    }

    #[embeddable_as(Ownable)]
    pub impl OwnableImpl<
        TContractState, +HasComponent<TContractState>,
    > of crate::ownable::interface::IOwnable<ComponentState<TContractState>> {
        /// Returns the address of the current owner
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            // Return current owner address
            self.owner.read()
        }

        /// Returns the address of the pending owner
        ///
        /// # Returns
        ///
        /// The pending owner's address (zero if no transfer in progress)
        fn pending_owner(self: @ComponentState<TContractState>) -> ContractAddress {
            // Return pending owner address (zero if no transfer in progress)
            self.pending_owner.read()
        }

        /// Initiates ownership transfer to a new account (step 1 of 2)
        ///
        /// Only the current owner can call this function
        ///
        /// # Arguments
        ///
        /// * `new_owner` - The address of the new owner
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - `new_owner` is the zero address
        /// - The caller is not the current owner
        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress,
        ) {
            // Validate new owner is not zero address
            assert(!new_owner.is_zero(), Errors::ZERO_ADDRESS_OWNER);

            // Only current owner can initiate ownership transfer
            self.assert_only_owner();

            // Propose new owner (first step of two-step transfer)
            self._propose_owner(new_owner);
        }

        /// Accepts ownership transfer (step 2 of 2)
        ///
        /// Only the pending owner can call this function
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - There is no pending owner
        /// - The caller is not the pending owner
        fn accept_ownership(ref self: ComponentState<TContractState>) {
            // Get current pending owner
            let pending_owner: ContractAddress = self.pending_owner.read();

            // Ensure there is a pending owner
            assert(!pending_owner.is_zero(), Errors::NO_PENDING_OWNER);

            // Get caller address
            let caller: ContractAddress = get_caller_address();

            // Only pending owner can accept ownership
            assert(caller == pending_owner, Errors::NOT_PENDING_OWNER);

            // Complete ownership transfer (second step of two-step transfer)
            self._transfer_ownership(pending_owner);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the component with an initial owner
        ///
        /// This bypasses the two-step process for initialization
        ///
        /// # Arguments
        ///
        /// * `owner` - The initial owner address
        ///
        /// # Panics
        ///
        /// This function will panic if `owner` is the zero address.
        fn initializer(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            // Validate initial owner is not zero address
            assert(!owner.is_zero(), Errors::ZERO_ADDRESS_OWNER);
            assert(self.owner.read().is_zero(), Errors::ALREADY_INITIALIZED);
            // Set initial owner (bypasses two-step process for initialization)
            self._transfer_ownership(owner);
        }

        /// Asserts that the caller is the current owner
        ///
        /// # Panics
        ///
        /// This function will panic if the caller is not the current owner.
        fn assert_only_owner(self: @ComponentState<TContractState>) {
            // Get current owner
            let owner: ContractAddress = self.owner.read();

            // Get caller address
            let caller: ContractAddress = get_caller_address();

            // Ensure caller is the current owner
            assert(caller == owner, Errors::NOT_OWNER);
        }

        fn _transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress,
        ) {
            // Get current owner before changing
            let old_owner: ContractAddress = self.owner.read();

            // Update owner to new owner
            self.owner.write(new_owner);

            // Clear pending owner (transfer is complete)
            self.pending_owner.write(Zero::zero());

            // Emit ownership transferred event
            self.emit(OwnershipTransferred { old_owner, new_owner });
        }

        fn _propose_owner(ref self: ComponentState<TContractState>, new_owner: ContractAddress) {
            // Get current owner for event
            let old_owner = self.owner.read();

            // Set pending owner (first step of two-step transfer)
            self.pending_owner.write(new_owner);

            // Emit ownership transfer started event
            self.emit(OwnershipTransferStarted { old_owner, new_owner });
        }
    }
}
