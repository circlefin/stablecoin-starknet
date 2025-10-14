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
pub mod ManageableComponent {
    use core::num::traits::Zero;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use crate::manageable::errors::Errors;
    // Re-export events for external access
    pub use crate::manageable::events::{AdminChangeStarted, AdminChanged};

    #[storage]
    pub struct Storage {
        admin: ContractAddress,
        pending_admin: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AdminChanged: AdminChanged,
        AdminChangeStarted: AdminChangeStarted,
    }

    #[embeddable_as(Manageable)]
    pub impl ManageableImpl<
        TContractState, +HasComponent<TContractState>,
    > of crate::manageable::interface::IManageable<ComponentState<TContractState>> {
        /// Returns the address of the current admin
        fn admin(self: @ComponentState<TContractState>) -> ContractAddress {
            // Return current admin address
            self.admin.read()
        }

        /// Returns the address of the pending admin
        ///
        /// # Returns
        ///
        /// The pending admin's address (zero if no transfer in progress)
        fn pending_admin(self: @ComponentState<TContractState>) -> ContractAddress {
            // Return pending admin address (zero if no transfer in progress)
            self.pending_admin.read()
        }

        /// Initiates admin transfer to a new account (step 1 of 2)
        ///
        /// Only the current admin can call this function
        ///
        /// # Arguments
        ///
        /// * `new_admin` - The address of the new admin
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - `new_admin` is the zero address
        /// - The caller is not the current admin
        fn transfer_admin(ref self: ComponentState<TContractState>, new_admin: ContractAddress) {
            // Validate new admin is not zero address
            assert(!new_admin.is_zero(), Errors::ZERO_ADDRESS_ADMIN);

            // Only current admin can initiate admin transfer
            self.assert_only_admin();

            // Propose new admin (first step of two-step transfer)
            self._propose_admin(new_admin);
        }

        /// Accepts admin transfer (step 2 of 2)
        ///
        /// Only the pending admin can call this function
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - There is no pending admin
        /// - The caller is not the pending admin
        fn accept_admin(ref self: ComponentState<TContractState>) {
            // Get current pending admin
            let pending_admin: ContractAddress = self.pending_admin.read();

            // Ensure there is a pending admin
            assert(!pending_admin.is_zero(), Errors::NO_PENDING_ADMIN);

            // Get caller address
            let caller: ContractAddress = get_caller_address();

            // Only pending admin can accept admin role
            assert(caller == pending_admin, Errors::NOT_PENDING_ADMIN);

            // Complete admin transfer (second step of two-step transfer)
            self._transfer_admin(pending_admin);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, admin: ContractAddress) {
            // Validate initial admin is not zero address
            assert(!admin.is_zero(), Errors::ZERO_ADDRESS_ADMIN);
            assert(self.admin.read().is_zero(), Errors::ALREADY_INITIALIZED);

            // Set initial admin (bypasses two-step process for initialization)
            self._transfer_admin(admin);
        }

        fn assert_only_admin(self: @ComponentState<TContractState>) {
            // Get current admin
            let admin: ContractAddress = self.admin.read();

            // Get caller address
            let caller: ContractAddress = get_caller_address();

            // Ensure caller is the current admin
            assert(caller == admin, Errors::NOT_ADMIN);
        }

        fn _transfer_admin(ref self: ComponentState<TContractState>, new_admin: ContractAddress) {
            // Get current admin before changing
            let old_admin: ContractAddress = self.admin.read();

            // Update admin to new admin
            self.admin.write(new_admin);

            // Clear pending admin (transfer is complete)
            self.pending_admin.write(Zero::zero());

            // Emit admin transferred event
            self.emit(AdminChanged { old_admin, new_admin });
        }

        fn _propose_admin(ref self: ComponentState<TContractState>, new_admin: ContractAddress) {
            // Get current admin for event
            let old_admin = self.admin.read();

            // Set pending admin (first step of two-step transfer)
            self.pending_admin.write(new_admin);

            // Emit admin transfer started event
            self.emit(AdminChangeStarted { old_admin, new_admin });
        }
    }
}
