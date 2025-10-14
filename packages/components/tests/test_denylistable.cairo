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

use components::denylistable::{
    DenylistableComponent, IDenylistableDispatcher, IDenylistableDispatcherTrait,
};
use components::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait};
use mock_contracts::{IMockDenylistableContractDispatcher, IMockDenylistableContractDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;


fn deploy_mock_contract(owner: ContractAddress, denylister: ContractAddress) -> ContractAddress {
    let contract = declare("MockDenylistableContract").unwrap().contract_class();
    let constructor_calldata = array![owner.into(), denylister.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn deploy_uninitialized_contract() -> ContractAddress {
    let contract = declare("MockDenylistableContract").unwrap().contract_class();
    let zero_address: ContractAddress = 0.try_into().unwrap();
    let constructor_calldata = array![zero_address.into(), zero_address.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let owner: ContractAddress = 123.try_into().unwrap();
    let denylister: ContractAddress = 456.try_into().unwrap();
    let user: ContractAddress = 789.try_into().unwrap();
    let unauthorized: ContractAddress = 999.try_into().unwrap();
    (owner, denylister, user, unauthorized)
}

// ================================
// CORE FUNCTIONALITY TESTS
// ================================

#[test]
fn test_initialized_contract_state() {
    let (owner, denylister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // Check that denylister is set correctly and users are not denylisted initially
    assert!(dispatcher.denylister() == denylister, "Denylister should return the correct address");
    assert!(!dispatcher.is_denylisted(user), "User should not be denylisted initially");
}

#[test]
fn test_uninitialized_contract_state() {
    let contract_address = deploy_uninitialized_contract();
    let dispatcher = IDenylistableDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Check that denylister is zero when uninitialized
    assert!(
        dispatcher.denylister() == zero_address, "Uninitialized denylister should be zero address",
    );
}

#[test]
fn test_update_denylister_functionality() {
    let (owner, denylister, _, _) = get_test_addresses();
    let new_denylister: ContractAddress = 'new_denylister'.try_into().unwrap();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Update denylister as owner
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_denylister(new_denylister);
    stop_cheat_caller_address(contract_address);

    // Check that denylister was updated
    assert!(dispatcher.denylister() == new_denylister, "Denylister should be updated");

    // Verify DenylisterChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    DenylistableComponent::Event::DenylisterChanged(
                        DenylistableComponent::DenylisterChanged {
                            old_denylister: denylister, new_denylister: new_denylister,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_complete_denylist_undenylist_flow() {
    let (owner, denylister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // Start with user not denylisted
    assert!(!dispatcher.is_denylisted(user), "User should not be denylisted initially");

    // Spy on events
    let mut spy = spy_events();

    // Denylist user
    start_cheat_caller_address(contract_address, denylister);
    dispatcher.denylist(user);
    assert!(dispatcher.is_denylisted(user), "User should be denylisted after denylist()");

    // Verify Denylisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    DenylistableComponent::Event::Denylisted(
                        DenylistableComponent::Denylisted { address: user },
                    ),
                ),
            ],
        );

    // Undenylist user
    dispatcher.undenylist(user);
    stop_cheat_caller_address(contract_address);
    assert!(!dispatcher.is_denylisted(user), "User should not be denylisted after undenylist()");

    // Verify Undenylisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    DenylistableComponent::Event::Undenylisted(
                        DenylistableComponent::Undenylisted { address: user },
                    ),
                ),
            ],
        );
}

// ================================
// ERROR HANDLING TESTS
// ================================

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_update_denylister_rejects_non_owner() {
    let (owner, denylister, _, unauthorized) = get_test_addresses();
    let new_denylister: ContractAddress = 'new_denylister'.try_into().unwrap();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.update_denylister(new_denylister);
}

#[test]
#[should_panic(expected: ('Denylister cannot be zero',))]
fn test_update_denylister_rejects_zero_address() {
    let (owner, denylister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    let zero_address: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_denylister(zero_address);
}

#[test]
#[should_panic(expected: ('Caller is not the denylister',))]
fn test_denylist_rejects_non_denylister() {
    let (owner, denylister, user, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.denylist(user);
}

#[test]
#[should_panic(expected: ('Cannot denylist zero address',))]
fn test_denylist_rejects_zero_address() {
    let (owner, denylister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    let zero_address: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(contract_address, denylister);
    dispatcher.denylist(zero_address);
}

#[test]
#[should_panic(expected: ('Caller is not the denylister',))]
fn test_undenylist_rejects_non_denylister() {
    let (owner, denylister, user, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // First denylist the user
    start_cheat_caller_address(contract_address, denylister);
    dispatcher.denylist(user);
    stop_cheat_caller_address(contract_address);

    // Try to undenylist as unauthorized user
    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.undenylist(user);
}

#[test]
#[should_panic(expected: ('Caller is not the denylister',))]
fn test_old_denylister_cannot_operate_after_update() {
    let (owner, denylister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // Update denylister to new denylister
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_denylister(user);
    assert!(dispatcher.denylister() == user, "Denylister should be updated to user");
    stop_cheat_caller_address(contract_address);

    // Try to denylist user from previous denylister
    start_cheat_caller_address(contract_address, denylister);
    dispatcher.denylist(user);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Cannot denylist zero address',))]
fn test_undenylist_rejects_zero_address() {
    let (owner, denylister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    let zero_address: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(contract_address, denylister);
    dispatcher.undenylist(zero_address);
}

// ================================
// EDGE CASES TESTS
// ================================

#[test]
fn test_denylist_already_denylisted_address() {
    let (owner, denylister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Denylist user multiple times
    start_cheat_caller_address(contract_address, denylister);
    dispatcher.denylist(user);
    assert!(dispatcher.is_denylisted(user), "User should be denylisted after denylist()");
    dispatcher.denylist(user);
    assert!(dispatcher.is_denylisted(user), "User should be denylisted after denylist()");
    stop_cheat_caller_address(contract_address);

    // Verify Denylisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    DenylistableComponent::Event::Denylisted(
                        DenylistableComponent::Denylisted { address: user },
                    ),
                ),
                (
                    contract_address,
                    DenylistableComponent::Event::Denylisted(
                        DenylistableComponent::Denylisted { address: user },
                    ),
                ),
            ],
        );
}

#[test]
fn test_undenylist_already_undenylisted_address() {
    let (owner, denylister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Denylist user
    start_cheat_caller_address(contract_address, denylister);
    dispatcher.denylist(user);
    assert!(dispatcher.is_denylisted(user), "User should be denylisted after denylist()");

    // Undenylist user multiple times
    dispatcher.undenylist(user);
    assert!(!dispatcher.is_denylisted(user), "User should not be denylisted after undenylist()");
    dispatcher.undenylist(user);
    assert!(!dispatcher.is_denylisted(user), "User should not be denylisted after undenylist()");
    stop_cheat_caller_address(contract_address);

    // Verify Denylisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    DenylistableComponent::Event::Denylisted(
                        DenylistableComponent::Denylisted { address: user },
                    ),
                ),
                (
                    contract_address,
                    DenylistableComponent::Event::Undenylisted(
                        DenylistableComponent::Undenylisted { address: user },
                    ),
                ),
                (
                    contract_address,
                    DenylistableComponent::Event::Undenylisted(
                        DenylistableComponent::Undenylisted { address: user },
                    ),
                ),
            ],
        );
}

#[test]
fn test_undenylist_never_denylisted_address() {
    let (owner, denylister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Undenylist user
    start_cheat_caller_address(contract_address, denylister);
    assert!(!dispatcher.is_denylisted(user), "User should not be denylisted before undenylist()");
    dispatcher.undenylist(user);
    assert!(!dispatcher.is_denylisted(user), "User should not be denylisted after undenylist()");
    stop_cheat_caller_address(contract_address);

    // Verify Denylisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    DenylistableComponent::Event::Undenylisted(
                        DenylistableComponent::Undenylisted { address: user },
                    ),
                ),
            ],
        );
}

#[test]
fn test_denylister_can_block_themselves() {
    let (owner, denylister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Denylist & undenylist denylister
    start_cheat_caller_address(contract_address, denylister);
    dispatcher.denylist(denylister);
    assert!(
        dispatcher.is_denylisted(denylister), "Denylister should be denylisted after denylist()",
    );
    dispatcher.undenylist(denylister);
    assert!(
        !dispatcher.is_denylisted(denylister),
        "Denylister should not be denylisted after undenylist()",
    );
    stop_cheat_caller_address(contract_address);

    // Verify Denylisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    DenylistableComponent::Event::Denylisted(
                        DenylistableComponent::Denylisted { address: denylister },
                    ),
                ),
                (
                    contract_address,
                    DenylistableComponent::Event::Undenylisted(
                        DenylistableComponent::Undenylisted { address: denylister },
                    ),
                ),
            ],
        );
}

#[test]
fn test_owner_can_be_denylisted() {
    let (owner, denylister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Denylist owner
    start_cheat_caller_address(contract_address, denylister);
    dispatcher.denylist(owner);
    assert!(dispatcher.is_denylisted(owner), "Owner should be denylisted after denylist()");
    stop_cheat_caller_address(contract_address);

    // Verify Denylisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    DenylistableComponent::Event::Denylisted(
                        DenylistableComponent::Denylisted { address: owner },
                    ),
                ),
            ],
        );
}

#[test]
fn test_update_denylister_to_same_address() {
    let (owner, denylister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Update denylister to current denylister address
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_denylister(denylister);
    stop_cheat_caller_address(contract_address);

    // Verify DenylisterChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    DenylistableComponent::Event::DenylisterChanged(
                        DenylistableComponent::DenylisterChanged {
                            old_denylister: denylister, new_denylister: denylister,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_update_denylister_to_current_owner() {
    let (owner, denylister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Update denylister to owner address
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_denylister(owner);
    stop_cheat_caller_address(contract_address);

    // Verify DenylisterChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    DenylistableComponent::Event::DenylisterChanged(
                        DenylistableComponent::DenylisterChanged {
                            old_denylister: denylister, new_denylister: owner,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_update_denylister_to_denylisted_address() {
    let (owner, denylister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let dispatcher = IDenylistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Denylist user
    start_cheat_caller_address(contract_address, denylister);
    dispatcher.denylist(user);
    assert!(dispatcher.is_denylisted(user), "User should be denylisted after denylist()");
    stop_cheat_caller_address(contract_address);

    // Update denylister to denylisted address
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_denylister(user);
    assert!(dispatcher.denylister() == user, "Denylister should be updated to denylisted address");
    stop_cheat_caller_address(contract_address);

    // Verify DenylisterChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    DenylistableComponent::Event::DenylisterChanged(
                        DenylistableComponent::DenylisterChanged {
                            old_denylister: denylister, new_denylister: user,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_denylist_operations_during_ownership_transfer() {
    let (owner, denylister, user1, user2) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let denylistable_dispatcher = IDenylistableDispatcher { contract_address };
    let ownable_dispatcher = IOwnableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Initiate ownership transfer
    start_cheat_caller_address(contract_address, owner);
    ownable_dispatcher.transfer_ownership(user1);
    assert!(ownable_dispatcher.pending_owner() == user1, "Pending owner should be user1");
    stop_cheat_caller_address(contract_address);

    // Denylist and undenylist user2
    start_cheat_caller_address(contract_address, denylister);
    denylistable_dispatcher.denylist(user2);
    assert!(
        denylistable_dispatcher.is_denylisted(user2), "User2 should be denylisted after denylist()",
    );
    denylistable_dispatcher.undenylist(user2);
    assert!(
        !denylistable_dispatcher.is_denylisted(user2),
        "User2 should not be denylisted after undenylist()",
    );
    stop_cheat_caller_address(contract_address);

    // Update denylister to user2
    start_cheat_caller_address(contract_address, owner);
    denylistable_dispatcher.update_denylister(user2);
    assert!(denylistable_dispatcher.denylister() == user2, "Denylister should be updated to user2");
    stop_cheat_caller_address(contract_address);

    // Accept ownership transfer
    start_cheat_caller_address(contract_address, user1);
    ownable_dispatcher.accept_ownership();
    assert!(ownable_dispatcher.owner() == user1, "Owner should be user1");
    stop_cheat_caller_address(contract_address);

    // Verify Denylisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    DenylistableComponent::Event::Denylisted(
                        DenylistableComponent::Denylisted { address: user2 },
                    ),
                ),
                (
                    contract_address,
                    DenylistableComponent::Event::Undenylisted(
                        DenylistableComponent::Undenylisted { address: user2 },
                    ),
                ),
                (
                    contract_address,
                    DenylistableComponent::Event::DenylisterChanged(
                        DenylistableComponent::DenylisterChanged {
                            old_denylister: denylister, new_denylister: user2,
                        },
                    ),
                ),
            ],
        );
}

// ================================
// INTERNAL FUNCTIONS TESTS
// ================================

#[test]
fn test_initializer_functionality() {
    let (owner, denylister, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let denylistable_dispatcher = IDenylistableDispatcher { contract_address };
    let test_dispatcher = IMockDenylistableContractDispatcher { contract_address };

    // Initialize ownable first (required for denylistable)
    test_dispatcher.test_ownable_initializer(owner);
    // Initialize denylistable with denylister
    test_dispatcher.test_denylistable_initializer(denylister);

    // Check that denylister is set
    assert!(
        denylistable_dispatcher.denylister() == denylister, "Initializer should set the denylister",
    );
}

#[test]
#[should_panic(expected: ('Denylister cannot be zero',))]
fn test_initializer_rejects_zero_address() {
    let (owner, _, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = IMockDenylistableContractDispatcher { contract_address };

    test_dispatcher.test_ownable_initializer(owner);
    let zero_address: ContractAddress = 0.try_into().unwrap();
    test_dispatcher.test_denylistable_initializer(zero_address);
}

#[test]
#[should_panic(expected: ('Contract already initialized',))]
fn test_initializer_rejects_already_initialized() {
    let (owner, denylister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let test_dispatcher = IMockDenylistableContractDispatcher { contract_address };

    test_dispatcher.test_ownable_initializer(owner);
    // Initialize denylistable with denylister
    test_dispatcher.test_denylistable_initializer(denylister);

    // should fail to initialize again
    test_dispatcher.test_denylistable_initializer(denylister);
}

#[test]
fn test_assert_only_denylister_functionality() {
    let (owner, denylister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let test_dispatcher = IMockDenylistableContractDispatcher { contract_address };

    // Should pass for denylister
    start_cheat_caller_address(contract_address, denylister);
    test_dispatcher.test_assert_only_denylister();
}

#[test]
#[should_panic(expected: ('Caller is not the denylister',))]
fn test_assert_only_denylister_fails_for_non_denylister() {
    let (owner, denylister, _, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let test_dispatcher = IMockDenylistableContractDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    test_dispatcher.test_assert_only_denylister();
}

#[test]
fn test_assert_not_denylisted_functionality() {
    let (owner, denylister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let test_dispatcher = IMockDenylistableContractDispatcher { contract_address };

    // Should pass when user is not denylisted
    test_dispatcher.test_assert_not_denylisted(user);
}

#[test]
#[should_panic(expected: ('Address is denylisted',))]
fn test_assert_not_denylisted_fails_for_denylisted_address() {
    let (owner, denylister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, denylister);
    let denylistable_dispatcher = IDenylistableDispatcher { contract_address };
    let test_dispatcher = IMockDenylistableContractDispatcher { contract_address };

    // First denylist the user
    start_cheat_caller_address(contract_address, denylister);
    denylistable_dispatcher.denylist(user);
    stop_cheat_caller_address(contract_address);

    // Should panic when user is denylisted
    test_dispatcher.test_assert_not_denylisted(user);
}

// ================================
// INTEGRATION WITH OWNABLE
// ================================

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_old_owner_cannot_update_denylister_after_transfer() {
    let (owner, denylister, _, _) = get_test_addresses();
    let new_owner: ContractAddress = 'new_owner'.try_into().unwrap();
    let new_denylister: ContractAddress = 'new_denylister'.try_into().unwrap();
    let contract_address = deploy_mock_contract(owner, denylister);
    let ownable_dispatcher = IOwnableDispatcher { contract_address };
    let denylistable_dispatcher = IDenylistableDispatcher { contract_address };

    // Transfer ownership
    start_cheat_caller_address(contract_address, owner);
    ownable_dispatcher.transfer_ownership(new_owner);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, new_owner);
    ownable_dispatcher.accept_ownership();
    stop_cheat_caller_address(contract_address);

    // Old owner should not be able to update denylister
    start_cheat_caller_address(contract_address, owner);
    denylistable_dispatcher.update_denylister(new_denylister);
}

#[test]
fn test_denylist_workflow() {
    let (owner, denylister, user, _) = get_test_addresses();
    let new_denylister: ContractAddress = 'new_denylister'.try_into().unwrap();
    let contract_address = deploy_mock_contract(owner, denylister);
    let denylistable_dispatcher = IDenylistableDispatcher { contract_address };

    // 1. Owner updates denylister
    start_cheat_caller_address(contract_address, owner);
    denylistable_dispatcher.update_denylister(new_denylister);
    stop_cheat_caller_address(contract_address);
    assert!(denylistable_dispatcher.denylister() == new_denylister, "Denylister should be updated");

    // 2. New denylister denylists user
    start_cheat_caller_address(contract_address, new_denylister);
    denylistable_dispatcher.denylist(user);
    assert!(denylistable_dispatcher.is_denylisted(user), "User should be denylisted");

    // 3. New denylister undenylists user
    denylistable_dispatcher.undenylist(user);
    stop_cheat_caller_address(contract_address);
    assert!(!denylistable_dispatcher.is_denylisted(user), "User should not be denylisted");
}
