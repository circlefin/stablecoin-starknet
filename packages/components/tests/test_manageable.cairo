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

use components::manageable::{
    IManageableDispatcher, IManageableDispatcherTrait, ManageableComponent,
};
use mock_contracts::{IMockManageableContractDispatcher, IMockManageableContractDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;


fn deploy_mock_contract(admin: ContractAddress) -> ContractAddress {
    let contract = declare("MockManageableContract").unwrap().contract_class();
    let constructor_calldata = array![admin.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn deploy_uninitialized_contract() -> ContractAddress {
    let contract = declare("MockManageableContract").unwrap().contract_class();
    let zero_address: ContractAddress = 0.try_into().unwrap();
    let constructor_calldata = array![zero_address.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress) {
    let admin: ContractAddress = 123.try_into().unwrap();
    let new_admin: ContractAddress = 456.try_into().unwrap();
    let unauthorized: ContractAddress = 789.try_into().unwrap();
    (admin, new_admin, unauthorized)
}

// ================================
// CORE FUNCTIONALITY TESTS
// ================================

#[test]
fn test_initialized_contract_state() {
    let (admin, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let dispatcher = IManageableDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Check that admin is set correctly and pending admin is zero
    assert!(dispatcher.admin() == admin, "Admin should return the correct address");
    assert!(dispatcher.pending_admin() == zero_address, "Pending admin should be zero initially");
}

#[test]
fn test_uninitialized_contract_state() {
    let contract_address = deploy_uninitialized_contract();
    let dispatcher = IManageableDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Check that both admin and pending admin are zero when uninitialized
    assert!(dispatcher.admin() == zero_address, "Uninitialized admin should be zero address");
    assert!(dispatcher.pending_admin() == zero_address, "Pending admin should be zero initially");
}

#[test]
fn test_complete_admin_transfer_flow() {
    let (admin, new_admin, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let dispatcher = IManageableDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Spy on events
    let mut spy = spy_events();

    // Step 1: Transfer admin (sets pending admin)
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.pending_admin() == new_admin, "Pending admin should be set after transfer");
    assert!(dispatcher.admin() == admin, "Current admin should not change until accepted");

    // Verify AdminChangeStarted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    ManageableComponent::Event::AdminChangeStarted(
                        ManageableComponent::AdminChangeStarted {
                            old_admin: admin, new_admin: new_admin,
                        },
                    ),
                ),
            ],
        );

    // Step 2: Accept admin (completes transfer)
    start_cheat_caller_address(contract_address, new_admin);
    dispatcher.accept_admin();
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.admin() == new_admin, "Admin should be transferred");
    assert!(dispatcher.pending_admin() == zero_address, "Pending admin should be cleared");

    // Verify AdminChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    ManageableComponent::Event::AdminChanged(
                        ManageableComponent::AdminChanged {
                            old_admin: admin, new_admin: new_admin,
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
#[should_panic(expected: ('Admin cannot be zero address',))]
fn test_transfer_admin_rejects_zero_address() {
    let (admin, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let dispatcher = IManageableDispatcher { contract_address };

    let zero_address: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(zero_address);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not the admin',))]
fn test_transfer_admin_rejects_non_admin() {
    let (admin, new_admin, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let dispatcher = IManageableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('No pending admin',))]
fn test_accept_admin_rejects_when_no_pending_admin() {
    let (admin, new_admin, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let dispatcher = IManageableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, new_admin);
    dispatcher.accept_admin();
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not the pending admin',))]
fn test_accept_admin_rejects_wrong_caller() {
    let (admin, new_admin, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let dispatcher = IManageableDispatcher { contract_address };

    // Set up pending admin
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    // Try to accept as unauthorized user
    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.accept_admin();
    stop_cheat_caller_address(contract_address);
}

// ================================
// INTERNAL FUNCTIONS TESTS
// ================================

#[test]
fn test_initializer_functionality() {
    let (admin, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let manageable_dispatcher = IManageableDispatcher { contract_address };
    let test_dispatcher = IMockManageableContractDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Spy on events
    let mut spy = spy_events();

    // Initialize with admin
    test_dispatcher.test_initializer(admin);

    // Check that admin is set and pending admin is zero
    assert!(manageable_dispatcher.admin() == admin, "Initializer should set the admin");
    assert!(
        manageable_dispatcher.pending_admin() == zero_address,
        "Pending admin should be zero after initialization",
    );

    // Verify AdminChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    ManageableComponent::Event::AdminChanged(
                        ManageableComponent::AdminChanged {
                            old_admin: zero_address, new_admin: admin,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: ('Admin cannot be zero address',))]
fn test_initializer_rejects_zero_address() {
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = IMockManageableContractDispatcher { contract_address };

    let zero_address: ContractAddress = 0.try_into().unwrap();
    test_dispatcher.test_initializer(zero_address);
}

#[test]
#[should_panic(expected: ('Contract already initialized',))]
fn test_initializer_rejects_double_initialization() {
    let (admin, new_admin, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = IMockManageableContractDispatcher { contract_address };

    // First initialization should succeed
    test_dispatcher.test_initializer(admin);

    // Second initialization should panic
    test_dispatcher.test_initializer(new_admin);
}

#[test]
fn test_assert_only_admin_functionality() {
    let (admin, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let test_dispatcher = IMockManageableContractDispatcher { contract_address };

    // Should pass for admin
    start_cheat_caller_address(contract_address, admin);
    test_dispatcher.test_assert_only_admin();
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not the admin',))]
fn test_assert_only_admin_fails_for_non_admin() {
    let (admin, _, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let test_dispatcher = IMockManageableContractDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    test_dispatcher.test_assert_only_admin();
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_internal_admin_functions() {
    let (admin, new_admin, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let manageable_dispatcher = IManageableDispatcher { contract_address };
    let test_dispatcher = IMockManageableContractDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Spy on events
    let mut spy = spy_events();

    // Test internal propose function
    test_dispatcher.test_propose_admin_internal(new_admin);
    assert!(
        manageable_dispatcher.admin() == admin, "Internal propose should not change current admin",
    );
    assert!(
        manageable_dispatcher.pending_admin() == new_admin,
        "Internal propose should set pending admin",
    );

    // Verify AdminChangeStarted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    ManageableComponent::Event::AdminChangeStarted(
                        ManageableComponent::AdminChangeStarted {
                            old_admin: admin, new_admin: new_admin,
                        },
                    ),
                ),
            ],
        );

    // Test internal transfer function
    test_dispatcher.test_transfer_admin_internal(new_admin);
    assert!(
        manageable_dispatcher.admin() == new_admin,
        "Internal transfer should change admin immediately",
    );
    assert!(
        manageable_dispatcher.pending_admin() == zero_address, "Pending admin should be cleared",
    );

    // Verify AdminChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    ManageableComponent::Event::AdminChanged(
                        ManageableComponent::AdminChanged {
                            old_admin: admin, new_admin: new_admin,
                        },
                    ),
                ),
            ],
        );
}

// ================================
// EDGE CASE TESTS
// ================================

#[test]
fn test_multiple_pending_admin_transfers() {
    let (admin, new_admin, third_admin) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let dispatcher = IManageableDispatcher { contract_address };

    // First transfer proposal
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.pending_admin() == new_admin, "First pending admin should be set");

    // Second transfer proposal (should overwrite)
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(third_admin);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.pending_admin() == third_admin, "Second pending admin should overwrite first",
    );
    assert!(dispatcher.admin() == admin, "Current admin should remain unchanged");
}

#[test]
fn test_admin_transfer_to_self() {
    let (admin, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let dispatcher = IManageableDispatcher { contract_address };

    // Admin transfers to themselves
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(admin);
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.pending_admin() == admin, "Pending admin should be set to current admin");
    assert!(dispatcher.admin() == admin, "Current admin should remain unchanged");

    // Admin accepts their own transfer
    start_cheat_caller_address(contract_address, admin);
    dispatcher.accept_admin();
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.admin() == admin, "Admin should remain the same after self-transfer");
}

#[test]
fn test_transfer_cancellation_by_overwriting() {
    let (admin, new_admin, third_admin) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let dispatcher = IManageableDispatcher { contract_address };

    // First transfer proposal
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    // "Cancel" by proposing to different admin
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(third_admin);
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.pending_admin() == third_admin, "Only third admin should be pending");

    // Third admin should be able to accept
    start_cheat_caller_address(contract_address, third_admin);
    dispatcher.accept_admin();
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.admin() == third_admin, "Third admin should be the new admin");
}

#[test]
#[should_panic(expected: ('Caller is not the pending admin',))]
fn test_cancelled_pending_admin_cannot_accept() {
    let (admin, new_admin, third_admin) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let dispatcher = IManageableDispatcher { contract_address };

    // First transfer proposal
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    // Overwrite with third admin
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(third_admin);
    stop_cheat_caller_address(contract_address);

    // First pending admin should no longer be able to accept
    start_cheat_caller_address(contract_address, new_admin);
    dispatcher.accept_admin();
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not the admin',))]
fn test_pending_admin_cannot_transfer_before_accepting() {
    let (admin, new_admin, third_admin) = get_test_addresses();
    let contract_address = deploy_mock_contract(admin);
    let dispatcher = IManageableDispatcher { contract_address };

    // Admin proposes transfer
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    // Pending admin tries to transfer to someone else before accepting
    start_cheat_caller_address(contract_address, new_admin);
    dispatcher.transfer_admin(third_admin);
    stop_cheat_caller_address(contract_address);
}
