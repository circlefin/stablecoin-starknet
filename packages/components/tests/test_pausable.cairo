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

use components::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait};
use components::pausable::{IPausableDispatcher, IPausableDispatcherTrait, PausableComponent};
use mock_contracts::{IMockPausableContractDispatcher, IMockPausableContractDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;


fn deploy_mock_contract(owner: ContractAddress, pauser: ContractAddress) -> ContractAddress {
    let contract = declare("MockPausableContract").unwrap().contract_class();
    let constructor_calldata = array![owner.into(), pauser.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn deploy_uninitialized_contract() -> ContractAddress {
    let contract = declare("MockPausableContract").unwrap().contract_class();
    let zero_address: ContractAddress = 0.try_into().unwrap();
    let constructor_calldata = array![zero_address.into(), zero_address.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let owner: ContractAddress = 123.try_into().unwrap();
    let pauser: ContractAddress = 456.try_into().unwrap();
    let new_pauser: ContractAddress = 789.try_into().unwrap();
    let unauthorized: ContractAddress = 999.try_into().unwrap();
    (owner, pauser, new_pauser, unauthorized)
}

// ================================
// CORE FUNCTIONALITY TESTS
// ================================

#[test]
fn test_initialized_contract_state() {
    let (owner, pauser, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser);
    let dispatcher = IPausableDispatcher { contract_address };

    // Check that pauser is set correctly and contract starts unpaused
    assert!(dispatcher.pauser() == pauser, "Pauser should return the correct address");
    assert!(!dispatcher.paused(), "Contract should be unpaused initially");
}

#[test]
fn test_uninitialized_contract_state() {
    let contract_address = deploy_uninitialized_contract();
    let dispatcher = IPausableDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Check that pauser is zero and contract is unpaused when uninitialized
    assert!(dispatcher.pauser() == zero_address, "Uninitialized pauser should be zero address");
    assert!(!dispatcher.paused(), "Contract should be unpaused initially");
}

#[test]
fn test_update_pauser_functionality() {
    let (owner, pauser, new_pauser, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser);
    let dispatcher = IPausableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Update pauser as owner
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_pauser(new_pauser);
    stop_cheat_caller_address(contract_address);

    // Check that pauser was updated
    assert!(dispatcher.pauser() == new_pauser, "Pauser should be updated");

    // Verify PauserChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    PausableComponent::Event::PauserChanged(
                        PausableComponent::PauserChanged {
                            old_pauser: pauser, new_pauser: new_pauser,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_update_pauser_when_paused() {
    let (owner, pauser, new_pauser, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser);
    let dispatcher = IPausableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // pause the contract
    start_cheat_caller_address(contract_address, pauser);
    dispatcher.pause();
    assert!(dispatcher.paused(), "Contract should be paused after pause()");
    stop_cheat_caller_address(contract_address);

    // update pauser as owner
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_pauser(new_pauser);
    stop_cheat_caller_address(contract_address);

    // Check that pauser was updated
    assert!(dispatcher.pauser() == new_pauser, "Pauser should be updated");

    // Verify PauserChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    PausableComponent::Event::PauserChanged(
                        PausableComponent::PauserChanged {
                            old_pauser: pauser, new_pauser: new_pauser,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_complete_pause_unpause_flow() {
    let (owner, pauser, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser);
    let dispatcher = IPausableDispatcher { contract_address };

    // Start unpaused
    assert!(!dispatcher.paused(), "Contract should start unpaused");

    // Spy on events
    let mut spy = spy_events();

    // Pause the contract
    start_cheat_caller_address(contract_address, pauser);
    dispatcher.pause();
    assert!(dispatcher.paused(), "Contract should be paused after pause()");

    // Verify Paused event was emitted
    spy
        .assert_emitted(
            @array![
                (contract_address, PausableComponent::Event::Paused(PausableComponent::Paused {})),
            ],
        );

    // Unpause the contract
    dispatcher.unpause();
    stop_cheat_caller_address(contract_address);
    assert!(!dispatcher.paused(), "Contract should be unpaused after unpause()");

    // Verify Unpaused event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    PausableComponent::Event::Unpaused(PausableComponent::Unpaused {}),
                ),
            ],
        );
}

// ================================
// ERROR HANDLING TESTS
// ================================

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_update_pauser_rejects_non_owner() {
    let (owner, pauser, new_pauser, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser);
    let dispatcher = IPausableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.update_pauser(new_pauser);
}

#[test]
#[should_panic(expected: ('Pauser cannot be zero address',))]
fn test_update_pauser_rejects_zero_address() {
    let (owner, pauser, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser);
    let dispatcher = IPausableDispatcher { contract_address };

    let zero_address: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_pauser(zero_address);
}

#[test]
#[should_panic(expected: ('Caller is not the pauser',))]
fn test_pause_rejects_non_pauser() {
    let (owner, pauser, _, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser);
    let dispatcher = IPausableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.pause();
}

#[test]
#[should_panic(expected: ('Caller is not the pauser',))]
fn test_unpause_rejects_non_pauser() {
    let (owner, pauser, _, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser);
    let dispatcher = IPausableDispatcher { contract_address };

    // First pause the contract
    start_cheat_caller_address(contract_address, pauser);
    dispatcher.pause();
    stop_cheat_caller_address(contract_address);

    // Try to unpause as unauthorized user
    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.unpause();
}

// ================================
// INTERNAL FUNCTIONS TESTS
// ================================

#[test]
fn test_initializer_functionality() {
    let (owner, pauser, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let pausable_dispatcher = IPausableDispatcher { contract_address };
    let test_dispatcher = IMockPausableContractDispatcher { contract_address };

    // Initialize ownable first (required for pausable)
    test_dispatcher.test_ownable_initializer(owner);
    // Initialize pausable with pauser
    test_dispatcher.test_pausable_initializer(pauser);

    // Check that pauser is set and contract starts unpaused
    assert!(pausable_dispatcher.pauser() == pauser, "Initializer should set the pauser");
    assert!(!pausable_dispatcher.paused(), "Contract should start unpaused after initialization");
}

#[test]
#[should_panic(expected: ('Pauser cannot be zero address',))]
fn test_initializer_rejects_zero_address() {
    let (owner, _, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = IMockPausableContractDispatcher { contract_address };

    test_dispatcher.test_ownable_initializer(owner);
    let zero_address: ContractAddress = 0.try_into().unwrap();
    test_dispatcher.test_pausable_initializer(zero_address);
}

#[test]
#[should_panic(expected: ('Contract already initialized',))]
fn test_initializer_rejects_already_initialized() {
    let (_, pauser, new_pauser, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = IMockPausableContractDispatcher { contract_address };

    test_dispatcher.test_pausable_initializer(pauser);
    test_dispatcher.test_pausable_initializer(new_pauser);
}

#[test]
fn test_assert_only_pauser_functionality() {
    let (owner, pauser, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser);
    let test_dispatcher = IMockPausableContractDispatcher { contract_address };

    // Should pass for pauser
    start_cheat_caller_address(contract_address, pauser);
    test_dispatcher.test_assert_only_pauser();
}

#[test]
#[should_panic(expected: ('Caller is not the pauser',))]
fn test_assert_only_pauser_fails_for_non_pauser() {
    let (owner, pauser, _, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser);
    let test_dispatcher = IMockPausableContractDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    test_dispatcher.test_assert_only_pauser();
}

#[test]
fn test_assert_not_paused_functionality() {
    let (owner, pauser, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser);
    let test_dispatcher = IMockPausableContractDispatcher { contract_address };

    // Should pass when unpaused
    test_dispatcher.test_assert_not_paused();
    // Pause contract and test should fail (in separate test due to panic)
}

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_assert_not_paused_fails_when_paused() {
    let (owner, pauser, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, pauser);
    let pausable_dispatcher = IPausableDispatcher { contract_address };
    let test_dispatcher = IMockPausableContractDispatcher { contract_address };

    // First pause the contract
    start_cheat_caller_address(contract_address, pauser);
    pausable_dispatcher.pause();
    stop_cheat_caller_address(contract_address);

    // Should panic when contract is paused
    test_dispatcher.test_assert_not_paused();
}

// ================================
// INTEGRATION WITH OWNABLE
// ================================

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_old_owner_cannot_update_pauser_after_transfer() {
    let (owner, pauser, new_pauser, _) = get_test_addresses();
    let new_owner: ContractAddress = 'new_owner'.try_into().unwrap();
    let contract_address = deploy_mock_contract(owner, pauser);
    let ownable_dispatcher = IOwnableDispatcher { contract_address };
    let pausable_dispatcher = IPausableDispatcher { contract_address };

    // Transfer ownership
    start_cheat_caller_address(contract_address, owner);
    ownable_dispatcher.transfer_ownership(new_owner);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, new_owner);
    ownable_dispatcher.accept_ownership();
    stop_cheat_caller_address(contract_address);

    // Old owner should not be able to update pauser
    start_cheat_caller_address(contract_address, owner);
    pausable_dispatcher.update_pauser(new_pauser);
}
