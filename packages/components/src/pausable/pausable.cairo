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
pub mod PausableComponent {
    use core::num::traits::Zero;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use crate::ownable::OwnableComponent;
    use crate::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;
    use crate::pausable::errors::Errors;
    // Re-export events for external access
    pub use crate::pausable::events::{Paused, PauserChanged, Unpaused};

    #[storage]
    pub struct Storage {
        pauser: ContractAddress,
        paused: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Paused: Paused,
        Unpaused: Unpaused,
        PauserChanged: PauserChanged,
    }

    #[embeddable_as(Pausable)]
    pub impl PausableImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
    > of crate::pausable::interface::IPausable<ComponentState<TContractState>> {
        /// Returns the address of the current pauser
        fn pauser(self: @ComponentState<TContractState>) -> ContractAddress {
            self.pauser.read()
        }

        /// Updates the pauser address
        ///
        /// Only the owner can call this function
        ///
        /// # Arguments
        ///
        /// * `new_pauser` - The new pauser address
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the owner
        /// - `new_pauser` is the zero address
        fn update_pauser(ref self: ComponentState<TContractState>, new_pauser: ContractAddress) {
            // Only owner can update pauser
            let ownable_component = get_dep_component!(@self, Owner);
            ownable_component.assert_only_owner();

            // Validate new pauser is not zero address
            assert(!new_pauser.is_zero(), Errors::ZERO_ADDRESS_PAUSER);

            // Get old pauser
            let old_pauser = self.pauser.read();

            // Update pauser
            self.pauser.write(new_pauser);

            // Emit event
            self.emit(PauserChanged { old_pauser, new_pauser });
        }

        /// Pauses the contract
        ///
        /// Only the pauser can call this function
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the pauser
        fn pause(ref self: ComponentState<TContractState>) {
            // Only pauser can pause
            self.assert_only_pauser();

            // Set paused state
            self.paused.write(true);

            // Emit event
            self.emit(Paused {});
        }

        /// Unpauses the contract
        ///
        /// Only the pauser can call this function
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the pauser
        fn unpause(ref self: ComponentState<TContractState>) {
            // Only pauser can unpause
            self.assert_only_pauser();

            // Set unpaused state
            self.paused.write(false);

            // Emit event
            self.emit(Unpaused {});
        }

        /// Returns whether the contract is currently paused
        ///
        /// # Returns
        ///
        /// True if the contract is paused, false otherwise
        fn paused(self: @ComponentState<TContractState>) -> bool {
            self.paused.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, pauser: ContractAddress) {
            assert(!pauser.is_zero(), Errors::ZERO_ADDRESS_PAUSER);
            assert(self.pauser.read().is_zero(), Errors::ALREADY_INITIALIZED);
            self.pauser.write(pauser);
            // Contract starts unpaused
            self.paused.write(false);
        }

        fn assert_only_pauser(self: @ComponentState<TContractState>) {
            let pauser = self.pauser.read();
            let caller = get_caller_address();
            assert(caller == pauser, Errors::NOT_PAUSER);
        }

        fn assert_not_paused(self: @ComponentState<TContractState>) {
            let is_paused = self.paused.read();
            assert(!is_paused, Errors::PAUSED);
        }
    }
}
