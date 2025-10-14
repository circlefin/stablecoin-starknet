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
pub mod MinterManagementComponent {
    use components::ownable::OwnableComponent;
    use components::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;
    use components::pausable::PausableComponent;
    use components::pausable::PausableComponent::InternalTrait as PausableInternalTrait;
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::minter_management::errors::Errors;
    // Re-export events for external access
    pub use crate::minter_management::events::{
        ControllerConfigured, ControllerRemoved, MasterMinterChanged, MinterAllowanceIncremented,
        MinterConfigured, MinterRemoved,
    };

    #[storage]
    pub struct Storage {
        master_minter: ContractAddress,
        minters: Map<ContractAddress, bool>,
        minter_allowances: Map<ContractAddress, u256>,
        minter_controllers: Map<ContractAddress, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ControllerConfigured: ControllerConfigured,
        ControllerRemoved: ControllerRemoved,
        MasterMinterChanged: MasterMinterChanged,
        MinterConfigured: MinterConfigured,
        MinterRemoved: MinterRemoved,
        MinterAllowanceIncremented: MinterAllowanceIncremented,
    }

    #[embeddable_as(MinterManagement)]
    pub impl MinterManagementImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
        impl Pausable: PausableComponent::HasComponent<TContractState>,
    > of crate::minter_management::interface::IMinterManagement<ComponentState<TContractState>> {
        /// Configures a minter with a specific allowance
        ///
        /// Only controllers can call this function for their assigned minter.
        /// This activates the minter and sets their minting allowance.
        ///
        /// # Arguments
        ///
        /// * `minter_allowance` - The maximum amount the minter can mint
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The contract is paused
        /// - The caller is not a valid controller (zero address controller)
        /// - The controller has no assigned minter
        fn configure_minter(ref self: ComponentState<TContractState>, minter_allowance: u256) {
            let pausable_component = get_dep_component!(@self, Pausable);
            pausable_component.assert_not_paused();
            self.assert_only_controller();

            let controller: ContractAddress = get_caller_address();
            let minter: ContractAddress = self.minter_controllers.read(controller);
            self.minters.write(minter, true);
            self.minter_allowances.write(minter, minter_allowance);
            self.emit(MinterConfigured { controller, minter, allowance: minter_allowance });
        }

        /// Removes a minter and resets its allowance to zero
        ///
        /// Only controllers can call this function for their assigned minter.
        /// This deactivates the minter and sets their allowance to zero.
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not a valid controller (zero address controller)
        /// - The controller has no assigned minter
        fn remove_minter(ref self: ComponentState<TContractState>) {
            self.assert_only_controller();
            let controller: ContractAddress = get_caller_address();
            let minter: ContractAddress = self.minter_controllers.read(controller);
            self.minters.write(minter, false);
            self.minter_allowances.write(minter, 0);
            self.emit(MinterRemoved { controller, minter });
        }

        /// Increments a minter's allowance by a specified amount
        ///
        /// Only controllers can call this function for their assigned minter.
        /// This increases the minter's allowance without replacing it entirely.
        ///
        /// # Arguments
        ///
        /// * `increment` - The amount to add to the current allowance
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The contract is paused
        /// - The caller is not a valid controller (zero address controller)
        /// - The increment amount is zero
        /// - The controller has no assigned minter
        fn increment_minter_allowance(ref self: ComponentState<TContractState>, increment: u256) {
            let pausable_component = get_dep_component!(@self, Pausable);
            pausable_component.assert_not_paused();
            self.assert_only_controller();
            assert(increment > 0, Errors::INCREMENT_ZERO);

            let controller: ContractAddress = get_caller_address();
            let minter: ContractAddress = self.minter_controllers.read(controller);
            assert(self.minters.read(minter), Errors::NOT_CONTROLLER_MINTER);
            let new_allowance = self.minter_allowances.read(minter) + increment;
            self.minter_allowances.write(minter, new_allowance);
            self
                .emit(
                    MinterAllowanceIncremented {
                        controller, minter, allowance_increment: increment, new_allowance,
                    },
                );
        }

        /// Configures a controller-minter relationship
        ///
        /// Only the master minter can call this function.
        /// This establishes which minter a controller can manage.
        ///
        /// # Arguments
        ///
        /// * `controller` - The controller address that will manage the minter
        /// * `minter` - The minter address that will be managed by the controller
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the master minter
        /// - The controller address is zero
        /// - The minter address is zero
        fn configure_controller(
            ref self: ComponentState<TContractState>,
            controller: ContractAddress,
            minter: ContractAddress,
        ) {
            // Only master minter can configure controller
            self.assert_only_master_minter();
            // Validate controller is not zero address
            assert(!controller.is_zero(), Errors::ZERO_ADDRESS_CONTROLLER);
            // Validate minter is not zero address
            assert(!minter.is_zero(), Errors::ZERO_ADDRESS_MINTER);
            self.minter_controllers.write(controller, minter);
            self.emit(ControllerConfigured { controller, minter });
        }

        /// Removes a controller and its associated minter relationship
        ///
        /// Only the master minter can call this function.
        /// This removes the controller's ability to manage its assigned minter.
        ///
        /// # Arguments
        ///
        /// * `controller` - The controller address to remove
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the master minter
        /// - The controller address is zero
        /// - The controller is not assigned a minter
        fn remove_controller(
            ref self: ComponentState<TContractState>, controller: ContractAddress,
        ) {
            // Only master minter can configure controller
            self.assert_only_master_minter();
            // Validate controller is not zero address
            assert(!controller.is_zero(), Errors::ZERO_ADDRESS_CONTROLLER);
            assert(!self.minter_controllers.read(controller).is_zero(), Errors::NOT_CONTROLLER);
            self.minter_controllers.write(controller, Zero::zero());
            self.emit(ControllerRemoved { controller });
        }

        /// Updates the master minter address
        ///
        /// Only the owner can call this function.
        /// The master minter has the authority to configure and remove controllers.
        ///
        /// # Arguments
        ///
        /// * `new_master_minter` - The new master minter address
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The caller is not the owner
        /// - The new master minter address is zero
        fn update_master_minter(
            ref self: ComponentState<TContractState>, new_master_minter: ContractAddress,
        ) {
            // Only owner can update master_minter
            let ownable_component = get_dep_component!(@self, Owner);
            ownable_component.assert_only_owner();

            // Validate new master minter is not zero address
            assert(!new_master_minter.is_zero(), Errors::ZERO_ADDRESS_MASTER_MINTER);

            let old_master_minter = self.master_minter.read();
            self.master_minter.write(new_master_minter);
            self.emit(MasterMinterChanged { old_master_minter, new_master_minter });
        }

        /// Returns the minter address associated with a controller
        ///
        /// # Arguments
        ///
        /// * `controller` - The controller address to query
        ///
        /// # Returns
        ///
        /// The minter address associated with the controller (zero if not configured)
        fn get_minter(
            self: @ComponentState<TContractState>, controller: ContractAddress,
        ) -> ContractAddress {
            self.minter_controllers.read(controller)
        }

        /// Returns the minting allowance for a minter
        ///
        /// # Arguments
        ///
        /// * `minter` - The minter address to query
        ///
        /// # Returns
        ///
        /// The current minting allowance for the minter
        fn minter_allowance(
            self: @ComponentState<TContractState>, minter: ContractAddress,
        ) -> u256 {
            self.minter_allowances.read(minter)
        }

        /// Returns whether an address is an active minter
        ///
        /// # Arguments
        ///
        /// * `minter` - The address to check
        ///
        /// # Returns
        ///
        /// True if the address is an active minter, false otherwise
        fn is_minter(self: @ComponentState<TContractState>, minter: ContractAddress) -> bool {
            self.minters.read(minter)
        }

        /// Returns the current master minter address
        ///
        /// # Returns
        ///
        /// The address of the current master minter
        fn master_minter(self: @ComponentState<TContractState>) -> ContractAddress {
            self.master_minter.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the component with an initial master minter
        ///
        /// This function should be called during contract initialization.
        ///
        /// # Arguments
        ///
        /// * `master_minter` - The initial master minter address
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The master minter address is zero
        /// - The component has already been initialized
        fn initializer(ref self: ComponentState<TContractState>, master_minter: ContractAddress) {
            assert(!master_minter.is_zero(), Errors::ZERO_ADDRESS_MASTER_MINTER);
            assert(self.master_minter.read().is_zero(), Errors::ALREADY_INITIALIZED);
            self.master_minter.write(master_minter);
        }

        /// Asserts that the caller is an active minter
        ///
        /// # Panics
        ///
        /// This function will panic if the caller is not an active minter.
        fn assert_only_minters(self: @ComponentState<TContractState>) {
            // Get caller address
            let caller: ContractAddress = get_caller_address();

            // Ensure caller is a minter
            assert(self.minters.read(caller), Errors::NOT_MINTER);
        }

        /// Asserts that the caller is the current master minter
        ///
        /// # Panics
        ///
        /// This function will panic if the caller is not the master minter.
        fn assert_only_master_minter(self: @ComponentState<TContractState>) {
            // Get current master minter
            let master_minter: ContractAddress = self.master_minter.read();

            // Get caller address
            let caller: ContractAddress = get_caller_address();

            // Ensure caller is the current master minter
            assert(caller == master_minter, Errors::NOT_MASTER_MINTER);
        }

        /// Asserts that the caller is a valid controller
        ///
        /// A valid controller is one that has been assigned a minter.
        ///
        /// # Panics
        ///
        /// This function will panic if the caller is not a valid controller.
        fn assert_only_controller(self: @ComponentState<TContractState>) {
            // Get caller address
            let caller: ContractAddress = get_caller_address();

            // Validate caller is not zero address
            assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CONTROLLER);

            // Check if caller is a valid controller by looking up their minter
            let minter: ContractAddress = self.minter_controllers.read(caller);

            // If minter is zero address, controller doesn't exist
            assert(!minter.is_zero(), Errors::NOT_CONTROLLER);
        }

        /// Decrements a minter's allowance by a specified amount
        ///
        /// This is an internal function that can be used by the embedding contract
        /// to decrease a minter's allowance, typically after a mint operation.
        ///
        /// # Arguments
        ///
        /// * `minter` - The minter address whose allowance should be decremented
        /// * `decrement` - The amount to subtract from the current allowance
        ///
        /// # Panics
        ///
        /// This function will panic if:
        /// - The minter address is zero
        /// - The decrement amount is zero
        /// - The decrement amount exceeds the current allowance
        fn decrement_minter_allowance(
            ref self: ComponentState<TContractState>, minter: ContractAddress, decrement: u256,
        ) {
            // Validate minter is not zero address
            assert(!minter.is_zero(), Errors::ZERO_ADDRESS_MINTER);
            // Validate decrement is not zero
            assert(decrement > 0, Errors::DECREMENT_ZERO);

            let current_allowance = self.minter_allowances.read(minter);
            // Validate decrement doesn't exceed current allowance
            assert(decrement <= current_allowance, Errors::INSUFFICIENT_ALLOWANCE);

            let new_allowance = current_allowance - decrement;
            self.minter_allowances.write(minter, new_allowance);
        }
    }
}
