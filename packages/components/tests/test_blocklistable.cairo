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

use components::blocklistable::{
    BlocklistableComponent, IBlocklistableDispatcher, IBlocklistableDispatcherTrait,
};
use components::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait};
use mock_contracts::{
    IMockBlocklistableContractDispatcher, IMockBlocklistableContractDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn deploy_mock_contract(owner: ContractAddress, blocklister: ContractAddress) -> ContractAddress {
    let contract = declare("MockBlocklistableContract").unwrap().contract_class();
    let constructor_calldata = array![owner.into(), blocklister.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn deploy_uninitialized_contract() -> ContractAddress {
    let contract = declare("MockBlocklistableContract").unwrap().contract_class();
    let zero_address: ContractAddress = 0.try_into().unwrap();
    let constructor_calldata = array![zero_address.into(), zero_address.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let owner: ContractAddress = 123.try_into().unwrap();
    let blocklister: ContractAddress = 456.try_into().unwrap();
    let user: ContractAddress = 789.try_into().unwrap();
    let unauthorized: ContractAddress = 999.try_into().unwrap();
    (owner, blocklister, user, unauthorized)
}

// ================================
// CORE FUNCTIONALITY TESTS
// ================================

#[test]
fn test_initialized_contract_state() {
    let (owner, blocklister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // Check that blocklister is set correctly and users are not blocklisted initially
    assert!(
        dispatcher.blocklister() == blocklister, "Blocklister should return the correct address",
    );
    assert!(!dispatcher.is_blocklisted(user), "User should not be blocklisted initially");
}

#[test]
fn test_uninitialized_contract_state() {
    let contract_address = deploy_uninitialized_contract();
    let dispatcher = IBlocklistableDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Check that blocklister is zero when uninitialized
    assert!(
        dispatcher.blocklister() == zero_address,
        "Uninitialized blocklister should be zero address",
    );
}

#[test]
fn test_update_blocklister_functionality() {
    let (owner, blocklister, _, _) = get_test_addresses();
    let new_blocklister: ContractAddress = 'new_blocklister'.try_into().unwrap();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Update blocklister as owner
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_blocklister(new_blocklister);
    stop_cheat_caller_address(contract_address);

    // Check that blocklister was updated
    assert!(dispatcher.blocklister() == new_blocklister, "Blocklister should be updated");

    // Verify BlocklisterChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    BlocklistableComponent::Event::BlocklisterChanged(
                        BlocklistableComponent::BlocklisterChanged {
                            old_blocklister: blocklister, new_blocklister: new_blocklister,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_complete_blocklist_unblocklist_flow() {
    let (owner, blocklister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // Start with user not blocklisted
    assert!(!dispatcher.is_blocklisted(user), "User should not be blocklisted initially");

    // Spy on events
    let mut spy = spy_events();

    // Blocklist user
    start_cheat_caller_address(contract_address, blocklister);
    dispatcher.blocklist(user);
    assert!(dispatcher.is_blocklisted(user), "User should be blocklisted after blocklist()");

    // Verify Blocklisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    BlocklistableComponent::Event::Blocklisted(
                        BlocklistableComponent::Blocklisted { address: user },
                    ),
                ),
            ],
        );

    // Unblocklist user
    dispatcher.unblocklist(user);
    stop_cheat_caller_address(contract_address);
    assert!(!dispatcher.is_blocklisted(user), "User should not be blocklisted after unblocklist()");

    // Verify Unblocklisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    BlocklistableComponent::Event::Unblocklisted(
                        BlocklistableComponent::Unblocklisted { address: user },
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
fn test_update_blocklister_rejects_non_owner() {
    let (owner, blocklister, _, unauthorized) = get_test_addresses();
    let new_blocklister: ContractAddress = 'new_blocklister'.try_into().unwrap();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.update_blocklister(new_blocklister);
}

#[test]
#[should_panic(expected: ('Blocklister cannot be zero',))]
fn test_update_blocklister_rejects_zero_address() {
    let (owner, blocklister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    let zero_address: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_blocklister(zero_address);
}

#[test]
#[should_panic(expected: ('Caller is not the blocklister',))]
fn test_blocklist_rejects_non_blocklister() {
    let (owner, blocklister, user, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.blocklist(user);
}

#[test]
#[should_panic(expected: ('Cannot blocklist zero address',))]
fn test_blocklist_rejects_zero_address() {
    let (owner, blocklister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    let zero_address: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(contract_address, blocklister);
    dispatcher.blocklist(zero_address);
}

#[test]
#[should_panic(expected: ('Caller is not the blocklister',))]
fn test_unblocklist_rejects_non_blocklister() {
    let (owner, blocklister, user, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // First blocklist the user
    start_cheat_caller_address(contract_address, blocklister);
    dispatcher.blocklist(user);
    stop_cheat_caller_address(contract_address);

    // Try to unblocklist as unauthorized user
    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.unblocklist(user);
}

#[test]
#[should_panic(expected: ('Caller is not the blocklister',))]
fn test_old_blocklister_cannot_operate_after_update() {
    let (owner, blocklister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // Update blocklister to new blocklister
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_blocklister(user);
    assert!(dispatcher.blocklister() == user, "Blocklister should be updated to user");
    stop_cheat_caller_address(contract_address);

    // Try to blocklist user from previous blocklister
    start_cheat_caller_address(contract_address, blocklister);
    dispatcher.blocklist(user);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Cannot blocklist zero address',))]
fn test_unblocklist_rejects_zero_address() {
    let (owner, blocklister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    let zero_address: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(contract_address, blocklister);
    dispatcher.unblocklist(zero_address);
}

// ================================
// EDGE CASES TESTS
// ================================

#[test]
fn test_blocklist_already_blocklisted_address() {
    let (owner, blocklister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Blocklist user multiple times
    start_cheat_caller_address(contract_address, blocklister);
    dispatcher.blocklist(user);
    assert!(dispatcher.is_blocklisted(user), "User should be blocklisted after blocklist()");
    dispatcher.blocklist(user);
    assert!(dispatcher.is_blocklisted(user), "User should be blocklisted after blocklist()");
    stop_cheat_caller_address(contract_address);

    // Verify Blocklisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    BlocklistableComponent::Event::Blocklisted(
                        BlocklistableComponent::Blocklisted { address: user },
                    ),
                ),
                (
                    contract_address,
                    BlocklistableComponent::Event::Blocklisted(
                        BlocklistableComponent::Blocklisted { address: user },
                    ),
                ),
            ],
        );
}

#[test]
fn test_unblocklist_already_unblocklisted_address() {
    let (owner, blocklister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Blocklist user
    start_cheat_caller_address(contract_address, blocklister);
    dispatcher.blocklist(user);
    assert!(dispatcher.is_blocklisted(user), "User should be blocklisted after blocklist()");

    // Unblocklist user multiple times
    dispatcher.unblocklist(user);
    assert!(!dispatcher.is_blocklisted(user), "User should not be blocklisted after unblocklist()");
    dispatcher.unblocklist(user);
    assert!(!dispatcher.is_blocklisted(user), "User should not be blocklisted after unblocklist()");
    stop_cheat_caller_address(contract_address);

    // Verify Blocklisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    BlocklistableComponent::Event::Blocklisted(
                        BlocklistableComponent::Blocklisted { address: user },
                    ),
                ),
                (
                    contract_address,
                    BlocklistableComponent::Event::Unblocklisted(
                        BlocklistableComponent::Unblocklisted { address: user },
                    ),
                ),
                (
                    contract_address,
                    BlocklistableComponent::Event::Unblocklisted(
                        BlocklistableComponent::Unblocklisted { address: user },
                    ),
                ),
            ],
        );
}

#[test]
fn test_unblocklist_never_blocklisted_address() {
    let (owner, blocklister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Unblocklist user
    start_cheat_caller_address(contract_address, blocklister);
    assert!(
        !dispatcher.is_blocklisted(user), "User should not be blocklisted before unblocklist()",
    );
    dispatcher.unblocklist(user);
    assert!(!dispatcher.is_blocklisted(user), "User should not be blocklisted after unblocklist()");
    stop_cheat_caller_address(contract_address);

    // Verify Blocklisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    BlocklistableComponent::Event::Unblocklisted(
                        BlocklistableComponent::Unblocklisted { address: user },
                    ),
                ),
            ],
        );
}

#[test]
fn test_blocklister_can_block_themselves() {
    let (owner, blocklister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Blocklist & unblocklist blocklister
    start_cheat_caller_address(contract_address, blocklister);
    dispatcher.blocklist(blocklister);
    assert!(
        dispatcher.is_blocklisted(blocklister),
        "Blocklister should be blocklisted after blocklist()",
    );
    dispatcher.unblocklist(blocklister);
    assert!(
        !dispatcher.is_blocklisted(blocklister),
        "Blocklister should not be blocklisted after unblocklist()",
    );
    stop_cheat_caller_address(contract_address);

    // Verify Blocklisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    BlocklistableComponent::Event::Blocklisted(
                        BlocklistableComponent::Blocklisted { address: blocklister },
                    ),
                ),
                (
                    contract_address,
                    BlocklistableComponent::Event::Unblocklisted(
                        BlocklistableComponent::Unblocklisted { address: blocklister },
                    ),
                ),
            ],
        );
}

#[test]
fn test_owner_can_be_blocklisted() {
    let (owner, blocklister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Blocklist owner
    start_cheat_caller_address(contract_address, blocklister);
    dispatcher.blocklist(owner);
    assert!(dispatcher.is_blocklisted(owner), "Owner should be blocklisted after blocklist()");
    stop_cheat_caller_address(contract_address);

    // Verify Blocklisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    BlocklistableComponent::Event::Blocklisted(
                        BlocklistableComponent::Blocklisted { address: owner },
                    ),
                ),
            ],
        );
}

#[test]
fn test_update_blocklister_to_same_address() {
    let (owner, blocklister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Update blocklister to current blocklister address
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_blocklister(blocklister);
    stop_cheat_caller_address(contract_address);

    // Verify BlocklisterChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    BlocklistableComponent::Event::BlocklisterChanged(
                        BlocklistableComponent::BlocklisterChanged {
                            old_blocklister: blocklister, new_blocklister: blocklister,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_update_blocklister_to_current_owner() {
    let (owner, blocklister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Update blocklister to owner address
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_blocklister(owner);
    stop_cheat_caller_address(contract_address);

    // Verify BlocklisterChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    BlocklistableComponent::Event::BlocklisterChanged(
                        BlocklistableComponent::BlocklisterChanged {
                            old_blocklister: blocklister, new_blocklister: owner,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_update_blocklister_to_blocklisted_address() {
    let (owner, blocklister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let dispatcher = IBlocklistableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Blocklist user
    start_cheat_caller_address(contract_address, blocklister);
    dispatcher.blocklist(user);
    assert!(dispatcher.is_blocklisted(user), "User should be blocklisted after blocklist()");
    stop_cheat_caller_address(contract_address);

    // Update blocklister to blocklisted address
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_blocklister(user);
    assert!(
        dispatcher.blocklister() == user, "Blocklister should be updated to blocklisted address",
    );
    stop_cheat_caller_address(contract_address);

    // Verify BlocklisterChanged event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    BlocklistableComponent::Event::BlocklisterChanged(
                        BlocklistableComponent::BlocklisterChanged {
                            old_blocklister: blocklister, new_blocklister: user,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_blocklist_operations_during_ownership_transfer() {
    let (owner, blocklister, user1, user2) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let blocklistable_dispatcher = IBlocklistableDispatcher { contract_address };
    let ownable_dispatcher = IOwnableDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Initiate ownership transfer
    start_cheat_caller_address(contract_address, owner);
    ownable_dispatcher.transfer_ownership(user1);
    assert!(ownable_dispatcher.pending_owner() == user1, "Pending owner should be user1");
    stop_cheat_caller_address(contract_address);

    // Blocklist and unblocklist user2
    start_cheat_caller_address(contract_address, blocklister);
    blocklistable_dispatcher.blocklist(user2);
    assert!(
        blocklistable_dispatcher.is_blocklisted(user2),
        "User2 should be blocklisted after blocklist()",
    );
    blocklistable_dispatcher.unblocklist(user2);
    assert!(
        !blocklistable_dispatcher.is_blocklisted(user2),
        "User2 should not be blocklisted after unblocklist()",
    );
    stop_cheat_caller_address(contract_address);

    // Update blocklister to user2
    start_cheat_caller_address(contract_address, owner);
    blocklistable_dispatcher.update_blocklister(user2);
    assert!(
        blocklistable_dispatcher.blocklister() == user2, "Blocklister should be updated to user2",
    );
    stop_cheat_caller_address(contract_address);

    // Accept ownership transfer
    start_cheat_caller_address(contract_address, user1);
    ownable_dispatcher.accept_ownership();
    assert!(ownable_dispatcher.owner() == user1, "Owner should be user1");
    stop_cheat_caller_address(contract_address);

    // Verify Blocklisted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    BlocklistableComponent::Event::Blocklisted(
                        BlocklistableComponent::Blocklisted { address: user2 },
                    ),
                ),
                (
                    contract_address,
                    BlocklistableComponent::Event::Unblocklisted(
                        BlocklistableComponent::Unblocklisted { address: user2 },
                    ),
                ),
                (
                    contract_address,
                    BlocklistableComponent::Event::BlocklisterChanged(
                        BlocklistableComponent::BlocklisterChanged {
                            old_blocklister: blocklister, new_blocklister: user2,
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
    let (owner, blocklister, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let blocklistable_dispatcher = IBlocklistableDispatcher { contract_address };
    let test_dispatcher = IMockBlocklistableContractDispatcher { contract_address };

    // Initialize ownable first (required for blocklistable)
    test_dispatcher.test_ownable_initializer(owner);
    // Initialize blocklistable with blocklister
    test_dispatcher.test_blocklistable_initializer(blocklister);

    // Check that blocklister is set
    assert!(
        blocklistable_dispatcher.blocklister() == blocklister,
        "Initializer should set the blocklister",
    );
}

#[test]
#[should_panic(expected: ('Blocklister cannot be zero',))]
fn test_initializer_rejects_zero_address() {
    let (owner, _, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = IMockBlocklistableContractDispatcher { contract_address };

    test_dispatcher.test_ownable_initializer(owner);
    let zero_address: ContractAddress = 0.try_into().unwrap();
    test_dispatcher.test_blocklistable_initializer(zero_address);
}

#[test]
#[should_panic(expected: ('Contract already initialized',))]
fn test_initializer_rejects_already_initialized() {
    let (owner, blocklister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let test_dispatcher = IMockBlocklistableContractDispatcher { contract_address };

    test_dispatcher.test_ownable_initializer(owner);
    // Initialize blocklistable with blocklister
    test_dispatcher.test_blocklistable_initializer(blocklister);

    // should fail to initialize again
    test_dispatcher.test_blocklistable_initializer(blocklister);
}

#[test]
fn test_assert_only_blocklister_functionality() {
    let (owner, blocklister, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let test_dispatcher = IMockBlocklistableContractDispatcher { contract_address };

    // Should pass for blocklister
    start_cheat_caller_address(contract_address, blocklister);
    test_dispatcher.test_assert_only_blocklister();
}

#[test]
#[should_panic(expected: ('Caller is not the blocklister',))]
fn test_assert_only_blocklister_fails_for_non_blocklister() {
    let (owner, blocklister, _, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let test_dispatcher = IMockBlocklistableContractDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    test_dispatcher.test_assert_only_blocklister();
}

#[test]
fn test_assert_not_blocklisted_functionality() {
    let (owner, blocklister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let test_dispatcher = IMockBlocklistableContractDispatcher { contract_address };

    // Should pass when user is not blocklisted
    test_dispatcher.test_assert_not_blocklisted(user);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_assert_not_blocklisted_fails_for_blocklisted_address() {
    let (owner, blocklister, user, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let blocklistable_dispatcher = IBlocklistableDispatcher { contract_address };
    let test_dispatcher = IMockBlocklistableContractDispatcher { contract_address };

    // First blocklist the user
    start_cheat_caller_address(contract_address, blocklister);
    blocklistable_dispatcher.blocklist(user);
    stop_cheat_caller_address(contract_address);

    // Should panic when user is blocklisted
    test_dispatcher.test_assert_not_blocklisted(user);
}

// ================================
// INTEGRATION WITH OWNABLE
// ================================

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_old_owner_cannot_update_blocklister_after_transfer() {
    let (owner, blocklister, _, _) = get_test_addresses();
    let new_owner: ContractAddress = 'new_owner'.try_into().unwrap();
    let new_blocklister: ContractAddress = 'new_blocklister'.try_into().unwrap();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let ownable_dispatcher = IOwnableDispatcher { contract_address };
    let blocklistable_dispatcher = IBlocklistableDispatcher { contract_address };

    // Transfer ownership
    start_cheat_caller_address(contract_address, owner);
    ownable_dispatcher.transfer_ownership(new_owner);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, new_owner);
    ownable_dispatcher.accept_ownership();
    stop_cheat_caller_address(contract_address);

    // Old owner should not be able to update blocklister
    start_cheat_caller_address(contract_address, owner);
    blocklistable_dispatcher.update_blocklister(new_blocklister);
}

#[test]
fn test_blocklist_workflow() {
    let (owner, blocklister, user, _) = get_test_addresses();
    let new_blocklister: ContractAddress = 'new_blocklister'.try_into().unwrap();
    let contract_address = deploy_mock_contract(owner, blocklister);
    let blocklistable_dispatcher = IBlocklistableDispatcher { contract_address };

    // 1. Owner updates blocklister
    start_cheat_caller_address(contract_address, owner);
    blocklistable_dispatcher.update_blocklister(new_blocklister);
    stop_cheat_caller_address(contract_address);
    assert!(
        blocklistable_dispatcher.blocklister() == new_blocklister, "Blocklister should be updated",
    );

    // 2. New blocklister blocklists user
    start_cheat_caller_address(contract_address, new_blocklister);
    blocklistable_dispatcher.blocklist(user);
    assert!(blocklistable_dispatcher.is_blocklisted(user), "User should be blocklisted");

    // 3. New blocklister unblocklists user
    blocklistable_dispatcher.unblocklist(user);
    stop_cheat_caller_address(contract_address);
    assert!(!blocklistable_dispatcher.is_blocklisted(user), "User should not be blocklisted");
}
