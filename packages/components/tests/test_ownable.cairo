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

use components::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait, OwnableComponent};
use mock_contracts::{IMockOwnableContractDispatcher, IMockOwnableContractDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;


fn deploy_mock_contract(owner: ContractAddress) -> ContractAddress {
    let contract = declare("MockOwnableContract").unwrap().contract_class();
    let constructor_calldata = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn deploy_uninitialized_contract() -> ContractAddress {
    let contract = declare("MockOwnableContract").unwrap().contract_class();
    let zero_address: ContractAddress = 0.try_into().unwrap();
    let constructor_calldata = array![zero_address.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress) {
    let owner: ContractAddress = 123.try_into().unwrap();
    let new_owner: ContractAddress = 456.try_into().unwrap();
    let unauthorized: ContractAddress = 789.try_into().unwrap();
    (owner, new_owner, unauthorized)
}

// ================================
// CORE FUNCTIONALITY TESTS
// ================================

#[test]
fn test_initialized_contract_state() {
    let (owner, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner);
    let dispatcher = IOwnableDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Check that owner is set correctly and pending owner is zero
    assert!(dispatcher.owner() == owner, "Owner should return the correct address");
    assert!(dispatcher.pending_owner() == zero_address, "Pending owner should be zero initially");
}

#[test]
fn test_uninitialized_contract_state() {
    let contract_address = deploy_uninitialized_contract();
    let dispatcher = IOwnableDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Check that both owner and pending owner are zero when uninitialized
    assert!(dispatcher.owner() == zero_address, "Uninitialized owner should be zero address");
    assert!(dispatcher.pending_owner() == zero_address, "Pending owner should be zero initially");
}

#[test]
fn test_complete_ownership_transfer_flow() {
    let (owner, new_owner, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner);
    let dispatcher = IOwnableDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Spy on events
    let mut spy = spy_events();

    // Step 1: Transfer ownership (sets pending owner)
    start_cheat_caller_address(contract_address, owner);
    dispatcher.transfer_ownership(new_owner);
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.pending_owner() == new_owner, "Pending owner should be set after transfer");
    assert!(dispatcher.owner() == owner, "Current owner should not change until accepted");

    // Verify OwnershipTransferStarted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    OwnableComponent::Event::OwnershipTransferStarted(
                        OwnableComponent::OwnershipTransferStarted {
                            old_owner: owner, new_owner: new_owner,
                        },
                    ),
                ),
            ],
        );

    // Step 2: Accept ownership (completes transfer)
    start_cheat_caller_address(contract_address, new_owner);
    dispatcher.accept_ownership();
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.owner() == new_owner, "Ownership should be transferred");
    assert!(dispatcher.pending_owner() == zero_address, "Pending owner should be cleared");

    // Verify OwnershipTransferred event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    OwnableComponent::Event::OwnershipTransferred(
                        OwnableComponent::OwnershipTransferred {
                            old_owner: owner, new_owner: new_owner,
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
#[should_panic(expected: ('Owner cannot be zero address',))]
fn test_transfer_ownership_rejects_zero_address() {
    let (owner, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner);
    let dispatcher = IOwnableDispatcher { contract_address };

    let zero_address: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(contract_address, owner);
    dispatcher.transfer_ownership(zero_address);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_transfer_ownership_rejects_non_owner() {
    let (owner, new_owner, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner);
    let dispatcher = IOwnableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.transfer_ownership(new_owner);
}

#[test]
#[should_panic(expected: ('No pending owner',))]
fn test_accept_ownership_rejects_when_no_pending_owner() {
    let (owner, new_owner, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner);
    let dispatcher = IOwnableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, new_owner);
    dispatcher.accept_ownership();
}

#[test]
#[should_panic(expected: ('Caller is not the pending owner',))]
fn test_accept_ownership_rejects_wrong_caller() {
    let (owner, new_owner, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner);
    let dispatcher = IOwnableDispatcher { contract_address };

    // Set up pending owner
    start_cheat_caller_address(contract_address, owner);
    dispatcher.transfer_ownership(new_owner);
    stop_cheat_caller_address(contract_address);

    // Try to accept as unauthorized user
    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.accept_ownership();
}

// ================================
// INTERNAL FUNCTIONS TESTS
// ================================

#[test]
fn test_initializer_functionality() {
    let (owner, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let ownable_dispatcher = IOwnableDispatcher { contract_address };
    let test_dispatcher = IMockOwnableContractDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Spy on events
    let mut spy = spy_events();

    // Initialize with owner
    test_dispatcher.test_initializer(owner);

    // Check that owner is set and pending owner is zero
    assert!(ownable_dispatcher.owner() == owner, "Initializer should set the owner");
    assert!(
        ownable_dispatcher.pending_owner() == zero_address,
        "Pending owner should be zero after initialization",
    );

    // Verify OwnershipTransferred event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    OwnableComponent::Event::OwnershipTransferred(
                        OwnableComponent::OwnershipTransferred {
                            old_owner: zero_address, new_owner: owner,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: ('Owner cannot be zero address',))]
fn test_initializer_rejects_zero_address() {
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = IMockOwnableContractDispatcher { contract_address };

    let zero_address: ContractAddress = 0.try_into().unwrap();
    test_dispatcher.test_initializer(zero_address);
}

#[test]
#[should_panic(expected: ('Contract already initialized',))]
fn test_initializer_rejects_already_initialized() {
    let (owner, new_owner, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner);
    let test_dispatcher = IMockOwnableContractDispatcher { contract_address };

    test_dispatcher.test_initializer(owner);
    test_dispatcher.test_initializer(new_owner);
}

#[test]
fn test_assert_only_owner_functionality() {
    let (owner, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner);
    let test_dispatcher = IMockOwnableContractDispatcher { contract_address };

    // Should pass for owner
    start_cheat_caller_address(contract_address, owner);
    test_dispatcher.test_assert_only_owner();
    stop_cheat_caller_address(contract_address);
    // Should fail for non-owner (test in separate test due to panic)
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_assert_only_owner_fails_for_non_owner() {
    let (owner, _, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner);
    let test_dispatcher = IMockOwnableContractDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    test_dispatcher.test_assert_only_owner();
}

#[test]
fn test_internal_ownership_functions() {
    let (owner, new_owner, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner);
    let ownable_dispatcher = IOwnableDispatcher { contract_address };
    let test_dispatcher = IMockOwnableContractDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Spy on events
    let mut spy = spy_events();

    // Test internal propose function
    test_dispatcher.test_propose_owner_internal(new_owner);
    assert!(
        ownable_dispatcher.owner() == owner, "Internal propose should not change current owner",
    );
    assert!(
        ownable_dispatcher.pending_owner() == new_owner,
        "Internal propose should set pending owner",
    );

    // Verify OwnershipTransferStarted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    OwnableComponent::Event::OwnershipTransferStarted(
                        OwnableComponent::OwnershipTransferStarted {
                            old_owner: owner, new_owner: new_owner,
                        },
                    ),
                ),
            ],
        );

    // Test internal transfer function
    test_dispatcher.test_transfer_ownership_internal(new_owner);
    assert!(
        ownable_dispatcher.owner() == new_owner,
        "Internal transfer should change owner immediately",
    );
    assert!(ownable_dispatcher.pending_owner() == zero_address, "Pending owner should be cleared");

    // Verify OwnershipTransferred event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    OwnableComponent::Event::OwnershipTransferred(
                        OwnableComponent::OwnershipTransferred {
                            old_owner: owner, new_owner: new_owner,
                        },
                    ),
                ),
            ],
        );
}

