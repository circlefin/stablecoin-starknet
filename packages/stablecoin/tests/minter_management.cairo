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

use components::pausable::{IPausableDispatcher, IPausableDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use stablecoin::minter_management::{
    IMinterManagementDispatcher, IMinterManagementDispatcherTrait, MinterManagementComponent,
};
use starknet::ContractAddress;

// Mock contract that uses ownable, pausable, and controller components for testing
#[starknet::contract]
mod MockControllerContract {
    use components::ownable::OwnableComponent;
    use components::pausable::PausableComponent;
    use core::num::traits::Zero;
    use stablecoin::minter_management::MinterManagementComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(
        path: MinterManagementComponent, storage: minter_management, event: MinterManagementEvent,
    );

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::Ownable<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::Pausable<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl MinterManagementImpl =
        MinterManagementComponent::MinterManagement<ContractState>;
    impl MinterManagementInternalImpl = MinterManagementComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        minter_management: MinterManagementComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        MinterManagementEvent: MinterManagementComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        pauser: ContractAddress,
        master_minter: ContractAddress,
    ) {
        if !owner.is_zero() {
            self.ownable.initializer(owner);
        }
        if !pauser.is_zero() {
            self.pausable.initializer(pauser);
        }
        if !master_minter.is_zero() {
            self.minter_management.initializer(master_minter);
        }
    }

    // Expose internal functions for testing
    #[abi(per_item)]
    #[generate_trait]
    impl TestHelperImpl of TestHelperTrait {
        #[external(v0)]
        fn test_controller_initializer(ref self: ContractState, master_minter: ContractAddress) {
            self.minter_management.initializer(master_minter);
        }

        #[external(v0)]
        fn test_assert_only_master_minter(self: @ContractState) {
            self.minter_management.assert_only_master_minter();
        }

        #[external(v0)]
        fn test_assert_only_controller(self: @ContractState) {
            self.minter_management.assert_only_controller();
        }

        #[external(v0)]
        fn test_assert_only_minters(self: @ContractState) {
            self.minter_management.assert_only_minters();
        }

        #[external(v0)]
        fn test_ownable_initializer(ref self: ContractState, owner: ContractAddress) {
            self.ownable.initializer(owner);
        }

        #[external(v0)]
        fn test_pausable_initializer(ref self: ContractState, pauser: ContractAddress) {
            self.pausable.initializer(pauser);
        }

        #[external(v0)]
        fn test_decrement_minter_allowance(
            ref self: ContractState, minter: ContractAddress, decrement: u256,
        ) {
            self.minter_management.decrement_minter_allowance(minter, decrement);
        }
    }
}

// Helper trait for accessing test functions
#[starknet::interface]
trait ITestHelper<TContractState> {
    fn test_controller_initializer(ref self: TContractState, master_minter: ContractAddress);
    fn test_assert_only_master_minter(self: @TContractState);
    fn test_assert_only_controller(self: @TContractState);
    fn test_assert_only_minters(self: @TContractState);
    fn test_ownable_initializer(ref self: TContractState, owner: ContractAddress);
    fn test_pausable_initializer(ref self: TContractState, pauser: ContractAddress);
    fn test_decrement_minter_allowance(
        ref self: TContractState, minter: ContractAddress, decrement: u256,
    );
}

fn deploy_mock_contract(
    owner: ContractAddress, pauser: ContractAddress, master_minter: ContractAddress,
) -> ContractAddress {
    let contract = declare("MockControllerContract").unwrap().contract_class();
    let constructor_calldata = array![owner.into(), pauser.into(), master_minter.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn deploy_uninitialized_contract() -> ContractAddress {
    let contract = declare("MockControllerContract").unwrap().contract_class();
    let zero_address: ContractAddress = 0.try_into().unwrap();
    let constructor_calldata = array![
        zero_address.into(), zero_address.into(), zero_address.into(),
    ];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn get_test_addresses() -> (
    ContractAddress,
    ContractAddress,
    ContractAddress,
    ContractAddress,
    ContractAddress,
    ContractAddress,
) {
    let owner: ContractAddress = 123.try_into().unwrap();
    let master_minter: ContractAddress = 456.try_into().unwrap();
    let controller: ContractAddress = 789.try_into().unwrap();
    let minter: ContractAddress = 999.try_into().unwrap();
    let unauthorized: ContractAddress = 888.try_into().unwrap();
    let pauser: ContractAddress = 101.try_into().unwrap();
    (owner, master_minter, controller, minter, unauthorized, pauser)
}

fn get_additional_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress) {
    let controller2: ContractAddress = 111.try_into().unwrap();
    let minter2: ContractAddress = 222.try_into().unwrap();
    let new_master_minter: ContractAddress = 333.try_into().unwrap();
    (controller2, minter2, new_master_minter)
}

// ================================
// CORE FUNCTIONALITY TESTS
// ================================

#[test]
fn test_initialized_contract_state() {
    let (owner, master_minter, _, _, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Check that master minter is set correctly
    assert!(
        dispatcher.master_minter() == master_minter,
        "Master minter should return the correct address",
    );

    // Check initial state for non-existent controller/minter
    assert!(
        dispatcher.get_minter(zero_address) == zero_address,
        "Non-existent controller should return zero minter",
    );
    assert!(!dispatcher.is_minter(zero_address), "Zero address should not be a minter");
    assert!(
        dispatcher.minter_allowance(zero_address) == 0,
        "Non-existent minter should have zero allowance",
    );
}

#[test]
fn test_uninitialized_contract_state() {
    let contract_address = deploy_uninitialized_contract();
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Check that master minter is zero when uninitialized
    assert!(
        dispatcher.master_minter() == zero_address,
        "Uninitialized master minter should be zero address",
    );
}

#[test]
fn test_configure_controller_functionality() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Configure controller as master minter
    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    // Check that controller was configured
    assert!(dispatcher.get_minter(controller) == minter, "Controller should have correct minter");

    // Verify ControllerConfigured event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MinterManagementComponent::Event::ControllerConfigured(
                        MinterManagementComponent::ControllerConfigured { controller, minter },
                    ),
                ),
            ],
        );
}

#[test]
fn test_configure_multiple_controllers() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let (controller2, minter2, _) = get_additional_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    start_cheat_caller_address(contract_address, master_minter);

    // Configure first controller
    dispatcher.configure_controller(controller, minter);

    // Configure second controller
    dispatcher.configure_controller(controller2, minter2);

    stop_cheat_caller_address(contract_address);

    // Check both controllers are configured correctly
    assert!(
        dispatcher.get_minter(controller) == minter, "First controller should have correct minter",
    );
    assert!(
        dispatcher.get_minter(controller2) == minter2,
        "Second controller should have correct minter",
    );
}

#[test]
fn test_reconfigure_existing_controller_with_different_minter() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let (_, new_minter, _) = get_additional_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    start_cheat_caller_address(contract_address, master_minter);

    // Configure controller with initial minter
    dispatcher.configure_controller(controller, minter);

    // Verify initial configuration
    assert!(dispatcher.get_minter(controller) == minter, "Controller should have initial minter");

    // Spy on events for reconfiguration
    let mut spy = spy_events();

    // Reconfigure same controller with different minter
    dispatcher.configure_controller(controller, new_minter);

    stop_cheat_caller_address(contract_address);

    // Verify controller was reconfigured with new minter
    assert!(
        dispatcher.get_minter(controller) == new_minter,
        "Controller should have new minter after reconfiguration",
    );

    // Verify ControllerConfigured event was emitted for reconfiguration
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MinterManagementComponent::Event::ControllerConfigured(
                        MinterManagementComponent::ControllerConfigured {
                            controller, minter: new_minter,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_remove_controller_functionality() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(contract_address, master_minter);

    // First configure a controller
    dispatcher.configure_controller(controller, minter);
    assert!(dispatcher.get_minter(controller) == minter, "Controller should be configured");

    // Spy on events
    let mut spy = spy_events();

    // Remove the controller
    dispatcher.remove_controller(controller);

    stop_cheat_caller_address(contract_address);

    // Check that controller was removed
    assert!(dispatcher.get_minter(controller) == zero_address, "Controller should be removed");

    // Verify ControllerRemoved event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MinterManagementComponent::Event::ControllerRemoved(
                        MinterManagementComponent::ControllerRemoved { controller },
                    ),
                ),
            ],
        );
}

#[test]
fn test_update_master_minter_functionality() {
    let (owner, master_minter, _, _, _, pauser) = get_test_addresses();
    let (_, _, new_master_minter) = get_additional_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Update master minter as owner
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_master_minter(new_master_minter);
    stop_cheat_caller_address(contract_address);

    // Check that master minter was updated
    assert!(dispatcher.master_minter() == new_master_minter, "Master minter should be updated");

    // Verify MasterMinterChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MinterManagementComponent::Event::MasterMinterChanged(
                        MinterManagementComponent::MasterMinterChanged {
                            old_master_minter: master_minter, new_master_minter,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_configure_minter_functionality() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let allowance: u256 = 1000;

    // First configure controller-minter relationship
    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    // Spy on events
    let mut spy = spy_events();

    // Configure minter allowance as controller
    start_cheat_caller_address(contract_address, controller);
    dispatcher.configure_minter(allowance);
    stop_cheat_caller_address(contract_address);

    // Check minter state
    assert!(dispatcher.is_minter(minter), "Address should be a minter");
    assert!(
        dispatcher.minter_allowance(minter) == allowance, "Minter should have correct allowance",
    );

    // Verify MinterConfigured event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MinterManagementComponent::Event::MinterConfigured(
                        MinterManagementComponent::MinterConfigured {
                            controller, minter, allowance,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_remove_minter_functionality() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let allowance: u256 = 1000;

    // Configure controller-minter relationship and set allowance
    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    dispatcher.configure_minter(allowance);
    assert!(dispatcher.is_minter(minter), "Minter should be configured");
    assert!(dispatcher.minter_allowance(minter) == allowance, "Minter should have allowance");

    // Spy on events
    let mut spy = spy_events();

    // Remove minter
    dispatcher.remove_minter();
    stop_cheat_caller_address(contract_address);

    // Check minter state
    assert!(!dispatcher.is_minter(minter), "Address should no longer be a minter");
    assert!(dispatcher.minter_allowance(minter) == 0, "Minter allowance should be zero");

    // Verify MinterRemoved event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MinterManagementComponent::Event::MinterRemoved(
                        MinterManagementComponent::MinterRemoved { controller, minter },
                    ),
                ),
            ],
        );
}

#[test]
fn test_increment_minter_allowance_functionality() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let initial_allowance: u256 = 500;
    let increment: u256 = 300;

    // Configure controller-minter relationship and set initial allowance
    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    dispatcher.configure_minter(initial_allowance);

    // Spy on events
    let mut spy = spy_events();

    // Increment allowance
    dispatcher.increment_minter_allowance(increment);
    stop_cheat_caller_address(contract_address);

    let expected_allowance = initial_allowance + increment;
    assert!(
        dispatcher.minter_allowance(minter) == expected_allowance,
        "Minter allowance should be incremented",
    );

    // Verify MinterAllowanceIncremented event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MinterManagementComponent::Event::MinterAllowanceIncremented(
                        MinterManagementComponent::MinterAllowanceIncremented {
                            controller,
                            minter,
                            allowance_increment: increment,
                            new_allowance: expected_allowance,
                        },
                    ),
                ),
            ],
        );
}

// ================================
// ERROR HANDLING TESTS
// ================================

#[test]
#[should_panic(expected: ('Caller is not the master minter',))]
fn test_configure_controller_rejects_non_master_minter() {
    let (owner, master_minter, controller, minter, unauthorized, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.configure_controller(controller, minter);
}

#[test]
#[should_panic(expected: ('Controller cannot be zero',))]
fn test_configure_controller_rejects_zero_controller() {
    let (owner, master_minter, _, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(zero_address, minter);
}

#[test]
#[should_panic(expected: ('Minter cannot be zero address',))]
fn test_configure_controller_rejects_zero_minter() {
    let (owner, master_minter, controller, _, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(controller, zero_address);
}

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_configure_minter_rejects_when_paused() {
    let (owner, master_minter, controller, _, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let pausable_dispatcher = IPausableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, pauser);
    pausable_dispatcher.pause();
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    dispatcher.configure_minter(1000);
}

#[test]
#[should_panic(expected: ('Controller cannot be zero',))]
fn test_configure_minter_rejects_zero_minter() {
    let (owner, master_minter, _, _, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(contract_address, zero_address);
    dispatcher.configure_minter(1000);
}

#[test]
#[should_panic(expected: ('Caller is not a controller',))]
fn test_configure_minter_rejects_non_controller() {
    let (owner, master_minter, _, _, _, pauser) = get_test_addresses();
    let (_, _, unauthorized) = get_additional_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.configure_minter(1000);
}

#[test]
#[should_panic(expected: ('Controller cannot be zero',))]
fn test_remove_minter_rejects_zero_controller() {
    let (owner, master_minter, _, _, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(contract_address, zero_address);
    dispatcher.remove_minter();
}

#[test]
#[should_panic(expected: ('Caller is not a controller',))]
fn test_remove_minter_rejects_non_controller() {
    let (owner, master_minter, _, _, _, pauser) = get_test_addresses();
    let (_, _, unauthorized) = get_additional_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.remove_minter();
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_update_master_minter_rejects_non_owner() {
    let (owner, master_minter, _, _, unauthorized, pauser) = get_test_addresses();
    let (_, _, new_master_minter) = get_additional_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.update_master_minter(new_master_minter);
}

#[test]
#[should_panic(expected: ('Master Minter cannot be zero',))]
fn test_update_master_minter_rejects_zero_address() {
    let (owner, master_minter, _, _, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_master_minter(zero_address);
}

#[test]
#[should_panic(expected: ('Caller is not a controller',))]
fn test_increment_minter_allowance_rejects_zero_address() {
    let (owner, master_minter, _, _, _, pauser) = get_test_addresses();
    let (_, _, unauthorized) = get_additional_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.increment_minter_allowance(1000);
}

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_increment_minter_allowance_rejects_when_paused() {
    let (owner, master_minter, controller, _, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let pausable_dispatcher = IPausableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, pauser);
    pausable_dispatcher.pause();
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    dispatcher.increment_minter_allowance(1000);
}

#[test]
#[should_panic(expected: ('Caller is not a controller',))]
fn test_increment_minter_allowance_rejects_non_controller() {
    let (owner, master_minter, _, _, _, pauser) = get_test_addresses();
    let (_, _, unauthorized) = get_additional_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.increment_minter_allowance(1000);
}

#[test]
#[should_panic(expected: ('Minter is not configured',))]
fn test_increment_minter_allowance_rejects_non_minter() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    dispatcher.configure_minter(1000);
    dispatcher.remove_minter();
    dispatcher.increment_minter_allowance(1000);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Increment amount cannot be zero',))]
fn test_increment_minter_allowance_rejects_zero_increment() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    // Configure controller-minter relationship
    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    dispatcher.increment_minter_allowance(0);
}

// ================================
// INTERNAL FUNCTIONS TESTS
// ================================

#[test]
fn test_initializer_functionality() {
    let (_, master_minter, _, _, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let minter_management_dispatcher = IMinterManagementDispatcher { contract_address };
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    // Initialize with master minter
    test_dispatcher.test_controller_initializer(master_minter);

    // Check that master minter is set
    assert!(
        minter_management_dispatcher.master_minter() == master_minter,
        "Initializer should set the master minter",
    );
}

#[test]
#[should_panic(expected: ('Master Minter cannot be zero',))]
fn test_initializer_rejects_zero_address() {
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = ITestHelperDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    test_dispatcher.test_controller_initializer(zero_address);
}

#[test]
#[should_panic(expected: ('Contract already initialized',))]
fn test_initializer_rejects_already_initialized() {
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = ITestHelperDispatcher { contract_address };
    let (_, master_minter, _, _, _, _) = get_test_addresses();
    let (_, _, new_master_minter) = get_additional_test_addresses();

    test_dispatcher.test_controller_initializer(master_minter);
    test_dispatcher.test_controller_initializer(new_master_minter);
}

#[test]
fn test_assert_only_master_minter_functionality() {
    let (owner, master_minter, _, _, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    // Should pass for master minter
    start_cheat_caller_address(contract_address, master_minter);
    test_dispatcher.test_assert_only_master_minter();
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not the master minter',))]
fn test_assert_only_master_minter_fails_for_non_master_minter() {
    let (owner, master_minter, _, _, unauthorized, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    test_dispatcher.test_assert_only_master_minter();
}

#[test]
fn test_assert_only_controller_functionality() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    // Configure controller first
    start_cheat_caller_address(contract_address, master_minter);
    let minter_management_dispatcher = IMinterManagementDispatcher { contract_address };
    minter_management_dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    // Should pass for valid controller
    start_cheat_caller_address(contract_address, controller);
    test_dispatcher.test_assert_only_controller();
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not a controller',))]
fn test_assert_only_controller_fails_for_non_controller() {
    let (owner, master_minter, _, _, unauthorized, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    test_dispatcher.test_assert_only_controller();
}

#[test]
fn test_assert_only_minters_functionality() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };
    let minter_management_dispatcher = IMinterManagementDispatcher { contract_address };

    // Configure controller-minter relationship and activate minter
    start_cheat_caller_address(contract_address, master_minter);
    minter_management_dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    minter_management_dispatcher.configure_minter(1000);
    stop_cheat_caller_address(contract_address);

    // Should pass for valid minter
    start_cheat_caller_address(contract_address, minter);
    test_dispatcher.test_assert_only_minters();
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not a minter',))]
fn test_assert_only_minters_fails_for_non_minter() {
    let (owner, master_minter, _, _, unauthorized, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    test_dispatcher.test_assert_only_minters();
}

#[test]
fn test_decrement_minter_allowance_functionality() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };
    let minter_management_dispatcher = IMinterManagementDispatcher { contract_address };
    let initial_allowance: u256 = 1000;
    let decrement: u256 = 300;

    // Configure controller-minter relationship and set allowance
    start_cheat_caller_address(contract_address, master_minter);
    minter_management_dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    minter_management_dispatcher.configure_minter(initial_allowance);
    stop_cheat_caller_address(contract_address);

    // Verify initial allowance
    assert!(
        minter_management_dispatcher.minter_allowance(minter) == initial_allowance,
        "Initial allowance should be set correctly",
    );

    // Decrement allowance
    test_dispatcher.test_decrement_minter_allowance(minter, decrement);

    // Verify allowance was decremented
    let expected_allowance = initial_allowance - decrement;
    assert!(
        minter_management_dispatcher.minter_allowance(minter) == expected_allowance,
        "Allowance should be decremented correctly",
    );
}

#[test]
#[should_panic(expected: ('Minter cannot be zero address',))]
fn test_decrement_minter_allowance_rejects_zero_minter() {
    let (owner, master_minter, _, _, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    test_dispatcher.test_decrement_minter_allowance(zero_address, 100);
}

#[test]
#[should_panic(expected: ('Decrement amount cannot be zero',))]
fn test_decrement_minter_allowance_rejects_zero_decrement() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };
    let minter_management_dispatcher = IMinterManagementDispatcher { contract_address };

    // Configure controller-minter relationship and set allowance
    start_cheat_caller_address(contract_address, master_minter);
    minter_management_dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    minter_management_dispatcher.configure_minter(1000);
    stop_cheat_caller_address(contract_address);

    // Try to decrement by zero
    test_dispatcher.test_decrement_minter_allowance(minter, 0);
}

#[test]
#[should_panic(expected: ('Insufficient minter allowance',))]
fn test_decrement_minter_allowance_rejects_insufficient_allowance() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };
    let minter_management_dispatcher = IMinterManagementDispatcher { contract_address };
    let initial_allowance: u256 = 500;
    let excessive_decrement: u256 = 1000;

    // Configure controller-minter relationship and set allowance
    start_cheat_caller_address(contract_address, master_minter);
    minter_management_dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    minter_management_dispatcher.configure_minter(initial_allowance);
    stop_cheat_caller_address(contract_address);

    // Try to decrement more than available
    test_dispatcher.test_decrement_minter_allowance(minter, excessive_decrement);
}

#[test]
fn test_multiple_decrements() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };
    let controller_dispatcher = IMinterManagementDispatcher { contract_address };
    let initial_allowance: u256 = 1000;

    // Configure controller-minter relationship and set allowance
    start_cheat_caller_address(contract_address, master_minter);
    controller_dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    controller_dispatcher.configure_minter(initial_allowance);
    stop_cheat_caller_address(contract_address);

    // Multiple decrements
    test_dispatcher.test_decrement_minter_allowance(minter, 200);
    test_dispatcher.test_decrement_minter_allowance(minter, 300);
    test_dispatcher.test_decrement_minter_allowance(minter, 100);

    // Verify final allowance
    let expected_allowance = initial_allowance - 200 - 300 - 100;
    assert!(
        controller_dispatcher.minter_allowance(minter) == expected_allowance,
        "Multiple decrements should accumulate correctly",
    );
}

#[test]
fn test_decrement_exact_allowance() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };
    let minter_management_dispatcher = IMinterManagementDispatcher { contract_address };
    let initial_allowance: u256 = 1000;

    // Configure controller-minter relationship and set allowance
    start_cheat_caller_address(contract_address, master_minter);
    minter_management_dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    minter_management_dispatcher.configure_minter(initial_allowance);
    stop_cheat_caller_address(contract_address);

    // Decrement exactly the allowance amount
    test_dispatcher.test_decrement_minter_allowance(minter, initial_allowance);

    // Verify allowance is exactly zero
    assert!(
        minter_management_dispatcher.minter_allowance(minter) == 0,
        "Exact decrement should result in zero allowance",
    );
}

#[test]
fn test_decrement_and_increment_combination() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };
    let minter_management_dispatcher = IMinterManagementDispatcher { contract_address };
    let initial_allowance: u256 = 1000;

    // Configure controller-minter relationship and set allowance
    start_cheat_caller_address(contract_address, master_minter);
    minter_management_dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    minter_management_dispatcher.configure_minter(initial_allowance);

    // Decrement allowance
    test_dispatcher.test_decrement_minter_allowance(minter, 300);

    // Verify intermediate state
    assert!(
        minter_management_dispatcher.minter_allowance(minter) == 700,
        "Allowance should be decremented to 700",
    );

    // Increment allowance again
    minter_management_dispatcher.increment_minter_allowance(500);

    stop_cheat_caller_address(contract_address);

    // Verify final state
    assert!(
        minter_management_dispatcher.minter_allowance(minter) == 1200,
        "Allowance should be 1200 after decrement and increment",
    );
}

#[test]
fn test_decrement_with_large_values() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let test_dispatcher = ITestHelperDispatcher { contract_address };
    let minter_management_dispatcher = IMinterManagementDispatcher { contract_address };

    // Use large values
    let large_allowance: u256 = 1000000000000000000000000000000; // 10^30
    let large_decrement: u256 = 500000000000000000000000000000; // 5 * 10^29

    // Configure controller-minter relationship and set allowance
    start_cheat_caller_address(contract_address, master_minter);
    minter_management_dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);
    minter_management_dispatcher.configure_minter(large_allowance);
    stop_cheat_caller_address(contract_address);

    // Decrement large amount
    test_dispatcher.test_decrement_minter_allowance(minter, large_decrement);

    // Verify allowance was decremented correctly
    let expected_allowance = large_allowance - large_decrement;
    assert!(
        minter_management_dispatcher.minter_allowance(minter) == expected_allowance,
        "Large value decrement should work correctly",
    );
}

// ================================
// INTEGRATION TESTS
// ================================

#[test]
fn test_complete_controller_minter_flow() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let allowance: u256 = 1000;
    let increment: u256 = 500;

    // Step 1: Configure controller (master minter action)
    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    // Step 2: Configure minter with allowance (controller action)
    start_cheat_caller_address(contract_address, controller);
    dispatcher.configure_minter(allowance);
    stop_cheat_caller_address(contract_address);

    // Verify state
    assert!(dispatcher.get_minter(controller) == minter, "Controller should have correct minter");
    assert!(dispatcher.is_minter(minter), "Address should be a minter");
    assert!(
        dispatcher.minter_allowance(minter) == allowance, "Minter should have correct allowance",
    );

    // Step 3: Increment allowance (controller action)
    start_cheat_caller_address(contract_address, controller);
    dispatcher.increment_minter_allowance(increment);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.minter_allowance(minter) == allowance + increment,
        "Allowance should be incremented",
    );

    // Step 4: Remove minter (controller action)
    start_cheat_caller_address(contract_address, controller);
    dispatcher.remove_minter();
    stop_cheat_caller_address(contract_address);

    assert!(!dispatcher.is_minter(minter), "Address should no longer be a minter");
    assert!(dispatcher.minter_allowance(minter) == 0, "Minter allowance should be zero");

    // Step 5: Remove controller (master minter action)
    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.remove_controller(controller);
    stop_cheat_caller_address(contract_address);

    let zero_address: ContractAddress = 0.try_into().unwrap();
    assert!(dispatcher.get_minter(controller) == zero_address, "Controller should be removed");
}

#[test]
fn test_master_minter_change_affects_permissions() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let (_, _, new_master_minter) = get_additional_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    // Configure controller with original master minter
    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    // Change master minter
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_master_minter(new_master_minter);
    stop_cheat_caller_address(contract_address);

    // New master minter should be able to configure controllers
    let (controller2, minter2, _) = get_additional_test_addresses();
    start_cheat_caller_address(contract_address, new_master_minter);
    dispatcher.configure_controller(controller2, minter2);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.get_minter(controller2) == minter2,
        "New master minter should be able to configure controllers",
    );
}

// ================================
// EDGE CASE TESTS
// ================================

#[test]
fn test_increment_from_zero_allowance() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };
    let increment: u256 = 100;

    // Configure controller-minter relationship
    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    // Configure minter with zero allowance first
    start_cheat_caller_address(contract_address, controller);
    dispatcher.configure_minter(0);

    // Increment allowance from zero
    dispatcher.increment_minter_allowance(increment);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.minter_allowance(minter) == increment,
        "Minter allowance should be incremented from zero",
    );
}

#[test]
fn test_multiple_increments() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    // Configure controller-minter relationship
    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller);

    // Configure minter with zero allowance first
    dispatcher.configure_minter(0);

    // Multiple increments
    dispatcher.increment_minter_allowance(100);
    dispatcher.increment_minter_allowance(200);
    dispatcher.increment_minter_allowance(300);

    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.minter_allowance(minter) == 600, "Multiple increments should accumulate");
}

#[test]
fn test_large_allowance_values() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    // Test with maximum u256 value
    let max_allowance: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    // Configure controller-minter relationship
    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(controller, minter);
    stop_cheat_caller_address(contract_address);

    // Set maximum allowance
    start_cheat_caller_address(contract_address, controller);
    dispatcher.configure_minter(max_allowance);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.minter_allowance(minter) == max_allowance,
        "Should handle maximum u256 allowance",
    );
}

#[test]
fn test_same_address_as_controller_and_minter() {
    let (owner, master_minter, _, _, _, pauser) = get_test_addresses();
    let same_address: ContractAddress = 'same_address'.try_into().unwrap();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    // Configure same address as both controller and minter
    start_cheat_caller_address(contract_address, master_minter);
    dispatcher.configure_controller(same_address, same_address);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.get_minter(same_address) == same_address,
        "Same address can be both controller and minter",
    );

    // Should be able to configure minter as itself
    start_cheat_caller_address(contract_address, same_address);
    dispatcher.configure_minter(1000);
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.is_minter(same_address), "Same address should be a minter");
    assert!(
        dispatcher.minter_allowance(same_address) == 1000, "Same address should have allowance",
    );
}

#[test]
fn test_multiple_controllers_same_minter() {
    let (owner, master_minter, controller, minter, _, pauser) = get_test_addresses();
    let (controller2, _, _) = get_additional_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser, master_minter);
    let dispatcher = IMinterManagementDispatcher { contract_address };

    start_cheat_caller_address(contract_address, master_minter);

    // Configure two controllers with the same minter
    dispatcher.configure_controller(controller, minter);
    dispatcher.configure_controller(controller2, minter);

    stop_cheat_caller_address(contract_address);

    // Both controllers should have the same minter
    assert!(dispatcher.get_minter(controller) == minter, "First controller should have minter");
    assert!(
        dispatcher.get_minter(controller2) == minter, "Second controller should have same minter",
    );

    // Both controllers should be able to configure the same minter
    start_cheat_caller_address(contract_address, controller);
    dispatcher.configure_minter(500);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller2);
    dispatcher.configure_minter(1000); // This should overwrite the previous allowance
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.minter_allowance(minter) == 1000, "Last configuration should win");
    assert!(dispatcher.is_minter(minter), "Minter should be active");

    // Test remove functionality with shared minter
    // First controller removes the minter
    start_cheat_caller_address(contract_address, controller);
    dispatcher.remove_minter();
    stop_cheat_caller_address(contract_address);

    // Minter should now be inactive and have zero allowance
    assert!(!dispatcher.is_minter(minter), "Minter should be inactive after removal");
    assert!(
        dispatcher.minter_allowance(minter) == 0, "Minter allowance should be zero after removal",
    );

    // Second controller should still have the same minter configured
    assert!(
        dispatcher.get_minter(controller2) == minter,
        "Second controller should still have same minter configured",
    );

    // Second controller should be able to reconfigure the minter
    start_cheat_caller_address(contract_address, controller2);
    dispatcher.configure_minter(2000);
    stop_cheat_caller_address(contract_address);

    // Minter should be active again with new allowance
    assert!(dispatcher.is_minter(minter), "Minter should be active again after reconfiguration");
    assert!(dispatcher.minter_allowance(minter) == 2000, "Minter should have new allowance");

    // Test that both controllers can still operate independently
    start_cheat_caller_address(contract_address, controller);
    dispatcher.configure_minter(1500); // First controller reconfigures
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, controller2);
    dispatcher.increment_minter_allowance(500); // Second controller increments
    stop_cheat_caller_address(contract_address);

    // Final allowance should be 1500 + 500 = 2000 (first controller set 1500, then second
    // incremented by 500)
    assert!(
        dispatcher.minter_allowance(minter) == 2000,
        "Both controllers should be able to operate on shared minter",
    );
}
