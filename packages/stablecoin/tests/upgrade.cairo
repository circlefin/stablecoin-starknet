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

use components::blocklistable::IBlocklistableDispatcherTrait;
use components::manageable::IManageableDispatcherTrait;
use components::ownable::IOwnableDispatcherTrait;
use components::pausable::IPausableDispatcherTrait;
use components::upgradeable::IUpgradeableDispatcherTrait;
use mock_contracts::{IMockFiatTokenDispatcher, IMockFiatTokenDispatcherTrait};
use snforge_std::{
    DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use stablecoin::fiat_token::IFiatTokenDispatcherTrait;
use stablecoin::minter_management::IMinterManagementDispatcherTrait;
use super::common::{deploy_fiat_token, deploy_fiat_token_with_controller, get_contract_addresses};

// ================================
// COMPREHENSIVE UPGRADE WITH MOCK CONTRACT TESTS
// ================================

#[test]
fn test_upgrade_to_mock_contract_preserves_state_and_adds_functionality() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);

    // ================================
    // PHASE 1: Test original contract functionality and populate state
    // ================================

    // Mint some tokens to create state
    let mint_amount = 1000000;
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.recipient_1, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Create some approvals
    let approve_amount = 500000;
    start_cheat_caller_address(contract_address, addresses.recipient_1);
    dispatchers.fiat_token_dispatcher.approve(addresses.spender, approve_amount);
    stop_cheat_caller_address(contract_address);

    // Record initial state before upgrade
    let initial_total_supply = dispatchers.fiat_token_dispatcher.total_supply();
    let initial_balance = dispatchers.fiat_token_dispatcher.balance_of(addresses.recipient_1);
    let initial_allowance = dispatchers
        .fiat_token_dispatcher
        .allowance(addresses.recipient_1, addresses.spender);
    let initial_admin = dispatchers.manageable_dispatcher.admin();
    let initial_owner = dispatchers.ownable_dispatcher.owner();
    let initial_pauser = dispatchers.pausable_dispatcher.pauser();
    let initial_master_minter = dispatchers.minter_management_dispatcher.master_minter();

    // Verify initial state
    assert!(initial_total_supply == mint_amount, "Initial total supply should match minted amount");
    assert!(initial_balance == mint_amount, "Initial balance should match minted amount");
    assert!(initial_allowance == approve_amount, "Initial allowance should match approved amount");

    // ================================
    // PHASE 2: Upgrade to mock contract
    // ================================

    // Declare the mock contract
    let mock_class = declare("MockFiatToken").unwrap().contract_class();
    let mock_class_hash = *mock_class.class_hash;

    // Spy on events
    let mut spy = spy_events();

    // Perform upgrade
    start_cheat_caller_address(contract_address, addresses.admin);
    dispatchers.upgradeable_dispatcher.upgrade(mock_class_hash);
    stop_cheat_caller_address(contract_address);

    // Verify upgrade event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    components::upgradeable::UpgradeableComponent::Event::ContractUpgraded(
                        components::upgradeable::UpgradeableComponent::ContractUpgraded {
                            class_hash: mock_class_hash,
                        },
                    ),
                ),
            ],
        );

    // ================================
    // PHASE 3: Verify state preservation after upgrade
    // ================================

    // Create new dispatcher for mock contract
    let mock_dispatcher = IMockFiatTokenDispatcher { contract_address };

    // Verify all original state is preserved
    assert!(
        mock_dispatcher.total_supply() == initial_total_supply, "Total supply should be preserved",
    );
    assert!(
        mock_dispatcher.balance_of(addresses.recipient_1) == initial_balance,
        "Balance should be preserved",
    );
    assert!(
        mock_dispatcher.allowance(addresses.recipient_1, addresses.spender) == initial_allowance,
        "Allowance should be preserved",
    );
    assert!(
        dispatchers.manageable_dispatcher.admin() == initial_admin, "Admin should be preserved",
    );
    assert!(dispatchers.ownable_dispatcher.owner() == initial_owner, "Owner should be preserved");
    assert!(
        dispatchers.pausable_dispatcher.pauser() == initial_pauser, "Pauser should be preserved",
    );
    assert!(
        dispatchers.minter_management_dispatcher.master_minter() == initial_master_minter,
        "Master minter should be preserved",
    );

    // ================================
    // PHASE 4: Test original functionality still works
    // ================================

    // Test transfer functionality
    let transfer_amount = 100000;
    start_cheat_caller_address(contract_address, addresses.recipient_1);
    let transfer_result = mock_dispatcher.transfer(addresses.recipient_2, transfer_amount);
    stop_cheat_caller_address(contract_address);

    assert!(transfer_result == true, "Transfer should succeed");
    assert!(
        mock_dispatcher.balance_of(addresses.recipient_1) == initial_balance - transfer_amount,
        "Sender balance should decrease",
    );
    assert!(
        mock_dispatcher.balance_of(addresses.recipient_2) == transfer_amount,
        "Recipient balance should increase",
    );
    assert!(
        mock_dispatcher.total_supply() == initial_total_supply,
        "Total supply should remain unchanged",
    );

    // ================================
    // PHASE 5: Test new functionality
    // ================================

    // Test version function (new in mock contract)
    let version = mock_dispatcher.get_version_v2();
    assert!(version == 2, "Version should be 2 for mock contract");

    // Test mock storage functionality
    // Note: When upgrading an existing contract, new storage fields will be zero
    let initial_mock_value = mock_dispatcher.mock_storage_value();
    assert!(initial_mock_value == 0, "Initial mock storage value should be 0 after upgrade");

    // Test setting mock storage value
    let new_mock_value = 123;
    start_cheat_caller_address(contract_address, addresses.test_user);
    mock_dispatcher.set_mock_storage_value(new_mock_value);
    stop_cheat_caller_address(contract_address);

    assert!(
        mock_dispatcher.mock_storage_value() == new_mock_value,
        "Mock storage value should be updated",
    );

    // ================================
    // PHASE 6: Test that mint/burn still work after upgrade
    // ================================

    // Test minting after upgrade
    let post_upgrade_mint_amount = 500000;
    start_cheat_caller_address(contract_address, addresses.minter);
    mock_dispatcher.mint(addresses.recipient_2, post_upgrade_mint_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        mock_dispatcher.total_supply() == initial_total_supply + post_upgrade_mint_amount,
        "Total supply should increase after mint",
    );
    assert!(
        mock_dispatcher.balance_of(addresses.recipient_2) == transfer_amount
            + post_upgrade_mint_amount,
        "Recipient balance should include new mint",
    );

    // Test burning after upgrade - first mint to the minter account
    let mint_to_minter_amount = 100000;
    start_cheat_caller_address(contract_address, addresses.minter);
    mock_dispatcher.mint(addresses.minter, mint_to_minter_amount);

    // Now burn from the minter account
    let burn_amount = 50000;
    mock_dispatcher.burn(burn_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        mock_dispatcher.total_supply() == initial_total_supply
            + post_upgrade_mint_amount
            + mint_to_minter_amount
            - burn_amount,
        "Total supply should decrease after burn",
    );
}

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_upgrade_preserves_paused_state() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Pause the contract
    start_cheat_caller_address(contract_address, addresses.pauser);
    dispatchers.pausable_dispatcher.pause();
    stop_cheat_caller_address(contract_address);

    assert!(dispatchers.pausable_dispatcher.paused() == true, "Contract should be paused");

    // Upgrade to mock contract
    let mock_class = declare("MockFiatToken").unwrap().contract_class();
    start_cheat_caller_address(contract_address, addresses.admin);
    dispatchers.upgradeable_dispatcher.upgrade(*mock_class.class_hash);
    stop_cheat_caller_address(contract_address);

    // Verify paused state is preserved
    assert!(
        dispatchers.pausable_dispatcher.paused() == true,
        "Contract should remain paused after upgrade",
    );

    // Try to use new function while paused - should fail
    let mock_dispatcher = IMockFiatTokenDispatcher { contract_address };
    start_cheat_caller_address(contract_address, addresses.test_user);
    mock_dispatcher.set_mock_storage_value(123);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_upgrade_preserves_blocklist_state() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist a user
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.test_user);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatchers.blocklistable_dispatcher.is_blocklisted(addresses.test_user) == true,
        "User should be blocklisted",
    );

    // Upgrade to mock contract
    let mock_class = declare("MockFiatToken").unwrap().contract_class();
    start_cheat_caller_address(contract_address, addresses.admin);
    dispatchers.upgradeable_dispatcher.upgrade(*mock_class.class_hash);
    stop_cheat_caller_address(contract_address);

    // Verify blocklist state is preserved
    assert!(
        dispatchers.blocklistable_dispatcher.is_blocklisted(addresses.test_user) == true,
        "User should remain blocklisted after upgrade",
    );

    // Try to use new function as blocklisted user - should fail
    let mock_dispatcher = IMockFiatTokenDispatcher { contract_address };
    start_cheat_caller_address(contract_address, addresses.test_user);
    mock_dispatcher.set_mock_storage_value(123);
    stop_cheat_caller_address(contract_address);
}

// ================================
// UPGRADE -> REVERT -> CHECK STATE TESTS
// ================================

#[test]
fn test_upgrade_to_mock_then_revert_to_original_preserves_state() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);

    // ================================
    // PHASE 1: Set up initial state in original contract
    // ================================

    // Mint tokens to establish state
    let mint_amount = 2000000;
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.recipient_1, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Create approvals
    let approve_amount = 750000;
    start_cheat_caller_address(contract_address, addresses.recipient_1);
    dispatchers.fiat_token_dispatcher.approve(addresses.spender, approve_amount);
    stop_cheat_caller_address(contract_address);

    // Make a transfer to create more complex state
    let initial_transfer_amount = 200000;
    start_cheat_caller_address(contract_address, addresses.recipient_1);
    dispatchers.fiat_token_dispatcher.transfer(addresses.recipient_2, initial_transfer_amount);
    stop_cheat_caller_address(contract_address);

    // Record state after initial operations
    let original_total_supply = dispatchers.fiat_token_dispatcher.total_supply();
    let original_balance_1 = dispatchers.fiat_token_dispatcher.balance_of(addresses.recipient_1);
    let original_balance_2 = dispatchers.fiat_token_dispatcher.balance_of(addresses.recipient_2);
    let original_allowance = dispatchers
        .fiat_token_dispatcher
        .allowance(addresses.recipient_1, addresses.spender);
    let original_admin = dispatchers.manageable_dispatcher.admin();
    let original_owner = dispatchers.ownable_dispatcher.owner();
    let original_pauser = dispatchers.pausable_dispatcher.pauser();
    let original_master_minter = dispatchers.minter_management_dispatcher.master_minter();

    // Verify initial state is as expected
    assert!(original_total_supply == mint_amount, "Original total supply should match mint amount");
    assert!(
        original_balance_1 == mint_amount - initial_transfer_amount,
        "Recipient 1 balance should be reduced by transfer",
    );
    assert!(
        original_balance_2 == initial_transfer_amount,
        "Recipient 2 balance should equal transfer amount",
    );
    assert!(
        original_allowance == approve_amount, "Original allowance should match approved amount",
    );

    // ================================
    // PHASE 2: Upgrade to mock contract and test new functionality
    // ================================

    // Declare and upgrade to mock contract
    let mock_class = declare("MockFiatToken").unwrap().contract_class();
    let mock_class_hash = *mock_class.class_hash;

    start_cheat_caller_address(contract_address, addresses.admin);
    dispatchers.upgradeable_dispatcher.upgrade(mock_class_hash);
    stop_cheat_caller_address(contract_address);

    // Create mock dispatcher and verify state preservation
    let mock_dispatcher = IMockFiatTokenDispatcher { contract_address };

    assert!(
        mock_dispatcher.total_supply() == original_total_supply,
        "Total supply should be preserved after upgrade",
    );
    assert!(
        mock_dispatcher.balance_of(addresses.recipient_1) == original_balance_1,
        "Recipient 1 balance should be preserved",
    );
    assert!(
        mock_dispatcher.balance_of(addresses.recipient_2) == original_balance_2,
        "Recipient 2 balance should be preserved",
    );
    assert!(
        mock_dispatcher.allowance(addresses.recipient_1, addresses.spender) == original_allowance,
        "Allowance should be preserved",
    );

    // Test new mock functionality
    let version = mock_dispatcher.get_version_v2();
    assert!(version == 2, "Version should be 2 for mock contract");

    // Test mock storage (starts at 0 after upgrade since it's a new field)
    let initial_mock_value = mock_dispatcher.mock_storage_value();
    assert!(initial_mock_value == 0, "Mock storage should start at 0 after upgrade");

    // Set mock storage value
    let test_mock_value = 999;
    start_cheat_caller_address(contract_address, addresses.test_user);
    mock_dispatcher.set_mock_storage_value(test_mock_value);
    stop_cheat_caller_address(contract_address);

    assert!(
        mock_dispatcher.mock_storage_value() == test_mock_value, "Mock storage should be updated",
    );

    // Test original functionality still works in mock contract
    let mock_transfer_amount = 50000;
    start_cheat_caller_address(contract_address, addresses.recipient_1);
    let transfer_result = mock_dispatcher.transfer(addresses.recipient_2, mock_transfer_amount);
    stop_cheat_caller_address(contract_address);

    assert!(transfer_result == true, "Transfer should work in mock contract");

    // Update balances after transfer in mock contract
    let post_mock_transfer_balance_1 = mock_dispatcher.balance_of(addresses.recipient_1);
    let post_mock_transfer_balance_2 = mock_dispatcher.balance_of(addresses.recipient_2);

    assert!(
        post_mock_transfer_balance_1 == original_balance_1 - mock_transfer_amount,
        "Sender balance should decrease",
    );
    assert!(
        post_mock_transfer_balance_2 == original_balance_2 + mock_transfer_amount,
        "Recipient balance should increase",
    );

    // ================================
    // PHASE 3: Revert to original FiatToken contract
    // ================================

    // Declare original FiatToken contract class
    let original_class = declare("FiatToken").unwrap().contract_class();
    let original_class_hash = *original_class.class_hash;

    start_cheat_caller_address(contract_address, addresses.admin);
    dispatchers.upgradeable_dispatcher.upgrade(original_class_hash);
    stop_cheat_caller_address(contract_address);

    // ================================
    // PHASE 4: Verify state preservation after revert
    // ================================

    // All the state should be preserved, including changes made in the mock contract
    assert!(
        dispatchers.fiat_token_dispatcher.total_supply() == original_total_supply,
        "Total supply should be preserved after revert",
    );
    assert!(
        dispatchers
            .fiat_token_dispatcher
            .balance_of(addresses.recipient_1) == post_mock_transfer_balance_1,
        "Recipient 1 balance should include mock contract changes",
    );
    assert!(
        dispatchers
            .fiat_token_dispatcher
            .balance_of(addresses.recipient_2) == post_mock_transfer_balance_2,
        "Recipient 2 balance should include mock contract changes",
    );
    assert!(
        dispatchers
            .fiat_token_dispatcher
            .allowance(addresses.recipient_1, addresses.spender) == original_allowance,
        "Allowance should be preserved after revert",
    );

    // Verify admin roles are preserved
    assert!(
        dispatchers.manageable_dispatcher.admin() == original_admin, "Admin should be preserved",
    );
    assert!(dispatchers.ownable_dispatcher.owner() == original_owner, "Owner should be preserved");
    assert!(
        dispatchers.pausable_dispatcher.pauser() == original_pauser, "Pauser should be preserved",
    );
    assert!(
        dispatchers.minter_management_dispatcher.master_minter() == original_master_minter,
        "Master minter should be preserved",
    );

    // ================================
    // PHASE 5: Test original functionality after revert
    // ================================

    // Test that original contract functionality works perfectly after revert
    let final_transfer_amount = 30000;
    start_cheat_caller_address(contract_address, addresses.recipient_2);
    let final_transfer_result = dispatchers
        .fiat_token_dispatcher
        .transfer(addresses.recipient_1, final_transfer_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        final_transfer_result == true, "Transfer should work in original contract after revert",
    );

    // Verify final balances
    let final_balance_1 = dispatchers.fiat_token_dispatcher.balance_of(addresses.recipient_1);
    let final_balance_2 = dispatchers.fiat_token_dispatcher.balance_of(addresses.recipient_2);

    assert!(
        final_balance_1 == post_mock_transfer_balance_1 + final_transfer_amount,
        "Final recipient 1 balance should include all transfers",
    );
    assert!(
        final_balance_2 == post_mock_transfer_balance_2 - final_transfer_amount,
        "Final recipient 2 balance should be reduced by final transfer",
    );

    // Test minting still works after revert
    let final_mint_amount = 100000;
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.recipient_1, final_mint_amount);
    stop_cheat_caller_address(contract_address);

    let final_total_supply = dispatchers.fiat_token_dispatcher.total_supply();
    assert!(
        final_total_supply == original_total_supply + final_mint_amount,
        "Total supply should increase after final mint",
    );

    let final_recipient_1_balance = dispatchers
        .fiat_token_dispatcher
        .balance_of(addresses.recipient_1);
    assert!(
        final_recipient_1_balance == final_balance_1 + final_mint_amount,
        "Recipient 1 should receive final mint",
    );

    // Test approval functionality after revert
    let new_approval_amount = 500000;
    start_cheat_caller_address(contract_address, addresses.recipient_1);
    let approval_result = dispatchers
        .fiat_token_dispatcher
        .approve(addresses.spender, new_approval_amount);
    stop_cheat_caller_address(contract_address);

    assert!(approval_result == true, "Approval should work after revert");

    let updated_allowance = dispatchers
        .fiat_token_dispatcher
        .allowance(addresses.recipient_1, addresses.spender);
    assert!(updated_allowance == new_approval_amount, "Allowance should be updated after revert");
}

// ================================
// EDGE CASE TESTS
// ================================

#[test]
fn test_upgrade_to_same_class_hash() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Get current class (same as what we're deploying)
    let current_class = declare("FiatToken").unwrap().contract_class();
    let current_class_hash = *current_class.class_hash;

    // Should be able to "upgrade" to the same class hash
    start_cheat_caller_address(contract_address, addresses.admin);
    dispatchers.upgradeable_dispatcher.upgrade(current_class_hash);
    stop_cheat_caller_address(contract_address);
}

// ================================
// INTEGRATION TESTS
// ================================

#[test]
fn test_upgrade_works_with_blocklisted_admin() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist the admin
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.admin);
    stop_cheat_caller_address(contract_address);

    // Upgrade should still work even if admin is blocklisted
    // (upgrade functionality is separate from token operations)
    let new_class = declare("FiatToken").unwrap().contract_class();
    start_cheat_caller_address(contract_address, addresses.admin);
    dispatchers.upgradeable_dispatcher.upgrade(*new_class.class_hash);
    stop_cheat_caller_address(contract_address);
}
