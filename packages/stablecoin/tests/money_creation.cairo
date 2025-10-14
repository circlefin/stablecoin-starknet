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
use components::pausable::IPausableDispatcherTrait;
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
};
use stablecoin::fiat_token::IFiatTokenDispatcherTrait;
use stablecoin::fiat_token::events::{Burn, Mint, Transfer};
use stablecoin::minter_management::IMinterManagementDispatcherTrait;
use starknet::ContractAddress;
use super::common::{deploy_fiat_token, deploy_fiat_token_with_controller, get_contract_addresses};

// ================================
// CORE FUNCTIONALITY TESTS
// ================================

#[test]
fn test_initial_state() {
    let addresses = get_contract_addresses();
    let (_, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    // Check initial state
    assert!(dispatcher.total_supply() == 0, "Initial total supply should be 0");
    assert!(dispatcher.totalSupply() == 0, "Initial total supply should be 0");
    assert!(dispatcher.balance_of(addresses.recipient_1) == 0, "Initial balance_of should be 0");
    assert!(dispatcher.balanceOf(addresses.recipient_1) == 0, "Initial balanceOf should be 0");
}

#[test]
fn test_mint_functionality() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let minter_management_dispatcher = dispatchers.minter_management_dispatcher;

    let amount: u256 = 1000;
    let minter_allowance = minter_management_dispatcher.minter_allowance(addresses.minter);

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens from authorized minter
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.recipient_1, amount);
    stop_cheat_caller_address(contract_address);

    // Check balances, supply, and allowance
    assert!(
        dispatcher.balance_of(addresses.recipient_1) == amount,
        "Recipient balance_of should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == amount,
        "Recipient balanceOf should have minted amount",
    );
    assert!(dispatcher.total_supply() == amount, "total_supply should equal minted amount");
    assert!(dispatcher.totalSupply() == amount, "totalSupply should equal minted amount");

    // Check that minter allowance has decreased
    let expected_remaining_allowance = minter_allowance
        - amount; // Initial allowance - minted amount
    assert!(
        minter_management_dispatcher
            .minter_allowance(addresses.minter) == expected_remaining_allowance,
        "Minter allowance should decrease after mint",
    );

    // Verify Mint event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Mint(
                        Mint { minter: addresses.minter, to: addresses.recipient_1, amount },
                    ),
                ),
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: 0.try_into().unwrap(), to: addresses.recipient_1, value: amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_mint_amount_equal_to_allowance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let minter_management_dispatcher = dispatchers.minter_management_dispatcher;
    let amount: u256 = 1000000000; // Exactly the allowance
    let minter_allowance = minter_management_dispatcher.minter_allowance(addresses.minter);

    // Mint tokens at exact allowance
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.recipient_1, amount);
    stop_cheat_caller_address(contract_address);

    // Should succeed
    assert!(
        dispatcher.balance_of(addresses.recipient_1) == amount,
        "balance_of recipient_1 should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == amount,
        "balanceOf recipient_1 should have minted amount",
    );
    assert!(dispatcher.total_supply() == amount, "Total supply should equal minted amount");
    assert!(dispatcher.totalSupply() == amount, "totalSupply should equal minted amount");

    // Check that minter allowance has decreased
    let expected_remaining_allowance = minter_allowance
        - amount; // Initial allowance - minted amount
    assert!(
        minter_management_dispatcher
            .minter_allowance(addresses.minter) == expected_remaining_allowance,
        "Minter allowance should decrease after mint",
    );
}


#[test]
fn test_mint_with_custom_allowance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let minter_management_dispatcher = dispatchers.minter_management_dispatcher;
    let mint_amount: u256 = 400; // Within 500 allowance

    // Configure minter with custom allowance (500)
    start_cheat_caller_address(contract_address, addresses.controller_1);
    minter_management_dispatcher.configure_minter(500);
    stop_cheat_caller_address(contract_address);

    // Test mint within custom allowance
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.recipient_1, mint_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.recipient_1) == mint_amount,
        "balance_of recipient_1 should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == mint_amount,
        "balanceOf recipient_1 should have minted amount",
    );
    assert!(dispatcher.total_supply() == mint_amount, "total_supply should equal minted amount");
    assert!(dispatcher.totalSupply() == mint_amount, "totalSupply should equal minted amount");
}

#[test]
fn test_mint_multiple_recipients() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let minter_management_dispatcher = dispatchers.minter_management_dispatcher;

    let amount1: u256 = 500;
    let amount2: u256 = 300;
    let minter_allowance = minter_management_dispatcher.minter_allowance(addresses.minter);

    start_cheat_caller_address(contract_address, addresses.minter);

    // Mint to first recipient
    dispatcher.mint(addresses.recipient_1, amount1);

    // Mint to second recipient
    dispatcher.mint(addresses.recipient_2, amount2);

    stop_cheat_caller_address(contract_address);

    // Check individual balances
    assert!(
        dispatcher.balance_of(addresses.recipient_1) == amount1,
        "First recipient balance_of incorrect",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == amount1,
        "First recipient balanceOf incorrect",
    );
    assert!(
        dispatcher.balance_of(addresses.recipient_2) == amount2,
        "Second recipient balance_of incorrect",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_2) == amount2,
        "Second recipient balanceOf incorrect",
    );

    // Check total supply
    let expected_total_supply = amount1 + amount2;
    assert!(
        dispatcher.total_supply() == expected_total_supply, "total_supply should be sum of mints",
    );
    assert!(
        dispatcher.totalSupply() == expected_total_supply, "totalSupply should be sum of mints",
    );

    // Check that minter allowance has decreased
    let expected_remaining_allowance = minter_allowance - amount1 - amount2;
    assert!(
        minter_management_dispatcher
            .minter_allowance(addresses.minter) == expected_remaining_allowance,
        "Minter allowance should decrease after mints",
    );
}

#[test]
fn test_mint_to_same_recipient_twice() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let minter_management_dispatcher = dispatchers.minter_management_dispatcher;

    let amount1: u256 = 500;
    let amount2: u256 = 300;
    let minter_allowance = minter_management_dispatcher.minter_allowance(addresses.minter);

    start_cheat_caller_address(contract_address, addresses.minter);

    // First mint
    dispatcher.mint(addresses.recipient_1, amount1);

    // Second mint to same recipient
    dispatcher.mint(addresses.recipient_1, amount2);

    stop_cheat_caller_address(contract_address);

    // Balance should be cumulative
    let expected_balance = amount1 + amount2;
    assert!(
        dispatcher.balance_of(addresses.recipient_1) == expected_balance,
        "balance_of recipient_1 should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == expected_balance,
        "balanceOf recipient_1 should have minted amount",
    );

    let expected_total_supply = amount1 + amount2;
    assert!(
        dispatcher.total_supply() == expected_total_supply, "total_supply should be cumulative",
    );
    assert!(dispatcher.totalSupply() == expected_total_supply, "totalSupply should be cumulative");

    // Check that minter allowance has decreased
    let expected_remaining_allowance = minter_allowance - amount1 - amount2;
    assert!(
        minter_management_dispatcher
            .minter_allowance(addresses.minter) == expected_remaining_allowance,
        "Minter allowance should decrease after mints",
    );
}

#[test]
fn test_burn_functionality_with_minter_as_burner() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let mint_amount: u256 = 1000;
    let burn_amount: u256 = 300;

    // First mint some tokens
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.minter, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Spy on events for burn
    let mut spy = spy_events();

    // Now burn some tokens
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.burn(burn_amount);
    stop_cheat_caller_address(contract_address);

    // Check balances after burn
    let expected_balance = mint_amount - burn_amount;
    assert!(
        dispatcher.balance_of(addresses.minter) == expected_balance,
        "balance_of minter should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.minter) == expected_balance,
        "balanceOf minter should have minted amount",
    );

    let expected_total_supply = mint_amount - burn_amount;
    assert!(
        dispatcher.total_supply() == expected_total_supply,
        "total_supply should decrease by burn amount",
    );
    assert!(
        dispatcher.totalSupply() == expected_total_supply,
        "totalSupply should decrease by burn amount",
    );

    // Verify Burn event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Burn(
                        Burn { burner: addresses.minter, amount: burn_amount },
                    ),
                ),
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.minter, to: 0.try_into().unwrap(), value: burn_amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_burn_functionality_with_burner_as_burner() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let mint_amount: u256 = 1000;
    let burn_amount: u256 = 300;

    // First mint some tokens
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.burner, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Spy on events for burn
    let mut spy = spy_events();

    // Now burn some tokens
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatcher.burn(burn_amount);
    stop_cheat_caller_address(contract_address);

    // Check balances after burn
    let expected_balance = mint_amount - burn_amount;
    assert!(
        dispatcher.balance_of(addresses.burner) == expected_balance,
        "balance_of burner should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.burner) == expected_balance,
        "balanceOf burner should have minted amount",
    );

    let expected_total_supply = mint_amount - burn_amount;
    assert!(
        dispatcher.total_supply() == expected_total_supply,
        "total_supply should decrease by burn amount",
    );
    assert!(
        dispatcher.totalSupply() == expected_total_supply,
        "totalSupply should decrease by burn amount",
    );

    // Verify Burn event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Burn(
                        Burn { burner: addresses.burner, amount: burn_amount },
                    ),
                ),
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.burner, to: 0.try_into().unwrap(), value: burn_amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_multiple_burns_depletion() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    // First mint 15 tokens
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.burner, 15);
    stop_cheat_caller_address(contract_address);

    // Multiple burns
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatcher.burn(5);
    dispatcher.burn(4);
    dispatcher.burn(3);
    dispatcher.burn(2);
    dispatcher.burn(1);
    stop_cheat_caller_address(contract_address);

    // Should deplete to 0
    assert!(dispatcher.balance_of(addresses.burner) == 0, "Multiple burns should deplete");
    assert!(dispatcher.balanceOf(addresses.burner) == 0, "Multiple burns should deplete");
    assert!(dispatcher.total_supply() == 0, "total_supply should be 0");
    assert!(dispatcher.totalSupply() == 0, "totalSupply should be 0");
}

// ================================
// ERROR HANDLING TESTS
// ================================

#[test]
#[should_panic(expected: ('To address cannot be zero',))]
fn test_mint_rejects_zero_address() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let zero_address: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(zero_address, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not a minter',))]
fn test_mint_rejects_non_minter() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    // Minter is not configured
    start_cheat_caller_address(contract_address, addresses.recipient_1);
    dispatcher.mint(addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Mint amount must be > 0',))]
fn test_mint_rejects_zero_amount() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.recipient_1, 0);
}


#[test]
#[should_panic(expected: ('Mint amount exceeds allowance',))]
fn test_mint_exceeds_allowance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let amount: u256 = 1000000001; // More than 1000000000 allowance

    // Try to mint more than allowance
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.recipient_1, amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Mint amount exceeds allowance',))]
fn test_mint_with_zero_allowance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let amount: u256 = 1;

    // Try to mint with burner who has zero allowance
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatcher.mint(addresses.recipient_1, amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Mint amount exceeds allowance',))]
fn test_mint_exceeds_custom_allowance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let minter_management_dispatcher = dispatchers.minter_management_dispatcher;

    // Configure minter with custom allowance (500)
    start_cheat_caller_address(contract_address, addresses.controller_1);
    minter_management_dispatcher.configure_minter(500);
    stop_cheat_caller_address(contract_address);

    // Try to mint more than custom allowance
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.recipient_1, 600); // Exceeds 500 allowance
    stop_cheat_caller_address(contract_address);
}


#[should_panic(expected: ('Caller is not a minter',))]
fn test_burn_rejects_non_minter() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    // Burner is not configured
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatcher.burn(100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Burn amount must be > 0',))]
fn test_burn_rejects_zero_amount() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.burn(0);
}

#[test]
#[should_panic(expected: ('Burn amount exceeds balance',))]
fn test_burn_rejects_insufficient_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    // Mint 100 tokens
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);

    // Try to burn 200 tokens (more than balance)
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.burn(200);
}

#[test]
#[should_panic(expected: ('Burn amount exceeds balance',))]
fn test_burn_rejects_when_no_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    // Try to burn without having any tokens
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.burn(100);
}

#[test]
#[should_panic(expected: ('Burn amount exceeds balance',))]
fn test_burn_more_than_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let mint_amount: u256 = 500;
    let excessive_burn_amount: u256 = 750; // More than minted amount

    // First mint some tokens to the burner
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.burner, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Verify the burner has the expected balance
    assert!(
        dispatcher.balance_of(addresses.burner) == mint_amount, "Burner should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.burner) == mint_amount, "Burner should have minted amount",
    );

    // Try to burn more than the balance (should panic)
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatcher.burn(excessive_burn_amount); // This should panic
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_mint_rejects_when_paused() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let pausable_dispatcher = dispatchers.pausable_dispatcher;

    // Pause contract
    start_cheat_caller_address(contract_address, addresses.pauser);
    pausable_dispatcher.pause();
    stop_cheat_caller_address(contract_address);

    // Attempt mint
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_burn_rejects_when_paused() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let pausable_dispatcher = dispatchers.pausable_dispatcher;

    // Pause contract
    start_cheat_caller_address(contract_address, addresses.pauser);
    pausable_dispatcher.pause();
    stop_cheat_caller_address(contract_address);

    // Attempt burn
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatcher.burn(100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_mint_rejects_when_caller_blocklisted() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist caller
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.minter);
    stop_cheat_caller_address(contract_address);

    // Attempt mint
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_mint_rejects_when_to_address_blocklisted() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist recipient_1
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.recipient_1);
    stop_cheat_caller_address(contract_address);

    // Attempt mint
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_mint_rejects_when_minter_blocklisted_after_mint() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);

    // Mint tokens
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);

    // Blocklist minter
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.minter);
    stop_cheat_caller_address(contract_address);

    // Attempt additional mint
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_burn_rejects_when_caller_blocklisted() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist caller
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.burner);
    stop_cheat_caller_address(contract_address);

    // Attempt burn
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatchers.fiat_token_dispatcher.burn(100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_burn_rejects_when_burner_blocklisted_after_burn() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);

    // Mint to burner
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.burner, 1000);
    stop_cheat_caller_address(contract_address);

    // Burn tokens
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatchers.fiat_token_dispatcher.burn(500);
    stop_cheat_caller_address(contract_address);

    // Blocklist burner
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.burner);
    stop_cheat_caller_address(contract_address);

    // Attempt additional burn
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatchers.fiat_token_dispatcher.burn(500);
    stop_cheat_caller_address(contract_address);
}


// ================================
// EDGE CASE TESTS
// ================================

#[test]
fn test_burn_exact_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let amount: u256 = 1000;

    // Mint tokens
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.minter, amount);
    stop_cheat_caller_address(contract_address);

    // Burn exact balance
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.burn(amount);
    stop_cheat_caller_address(contract_address);

    // Should have zero balance and supply
    assert!(
        dispatcher.balance_of(addresses.minter) == 0,
        "balance_of minter should be zero after burning all",
    );
    assert!(
        dispatcher.balanceOf(addresses.minter) == 0,
        "balanceOf minter should be zero after burning all",
    );
    assert!(dispatcher.total_supply() == 0, "total_supply should be zero after burning all");
    assert!(dispatcher.totalSupply() == 0, "totalSupply should be zero after burning all");
}

#[test]
fn test_mint_and_burn_large_amounts() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let minter_management_dispatcher = dispatchers.minter_management_dispatcher;

    // Test with large u256 amount
    let large_amount: u256 = 0xffffffffffffffffffffffffffffffff; // Large but valid u256

    // Configure minter with large allowance
    start_cheat_caller_address(contract_address, addresses.controller_1);
    minter_management_dispatcher.configure_minter(large_amount);
    stop_cheat_caller_address(contract_address);

    // Get minter allowance after configuration
    let minter_allowance = minter_management_dispatcher.minter_allowance(addresses.minter);

    // Mint large amount
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.burner, large_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.burner) == large_amount,
        "balance_of burner should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.burner) == large_amount,
        "balanceOf burner should have minted amount",
    );
    assert!(dispatcher.total_supply() == large_amount, "total_supply should match large amount");
    assert!(dispatcher.totalSupply() == large_amount, "totalSupply should match large amount");

    // Check that minter allowance has decreased
    let expected_remaining_allowance = minter_allowance - large_amount;
    assert!(
        minter_management_dispatcher
            .minter_allowance(addresses.minter) == expected_remaining_allowance,
        "Minter allowance should decrease after mint",
    );

    // Burn large amount
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatcher.burn(large_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.burner) == 0,
        "balance_of burner should be zero after burning all",
    );
    assert!(
        dispatcher.balanceOf(addresses.burner) == 0,
        "balanceOf burner should be zero after burning all",
    );
    assert!(dispatcher.total_supply() == 0, "total_supply should be zero after burning all");
    assert!(dispatcher.totalSupply() == 0, "totalSupply should be zero after burning all");
}

#[test]
fn test_mint_and_burn_maximum_u256() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let minter_management_dispatcher = dispatchers.minter_management_dispatcher;

    // Test with absolute maximum u256 value
    let max_u256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    // Configure minter with maximum u256 value
    start_cheat_caller_address(contract_address, addresses.controller_1);
    minter_management_dispatcher.configure_minter(max_u256);
    stop_cheat_caller_address(contract_address);

    // Get minter allowance after configuration
    let minter_allowance = minter_management_dispatcher.minter_allowance(addresses.minter);

    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.burner, max_u256);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.burner) == max_u256,
        "balance_of burner should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.burner) == max_u256,
        "balanceOf burner should have minted amount",
    );
    assert!(dispatcher.total_supply() == max_u256, "total_supply should be max u256");
    assert!(dispatcher.totalSupply() == max_u256, "totalSupply should be max u256");

    // Check that minter allowance has decreased to 0 (max_u256 - max_u256 = 0)
    let expected_remaining_allowance = minter_allowance - max_u256;
    assert!(
        minter_management_dispatcher
            .minter_allowance(addresses.minter) == expected_remaining_allowance,
        "Minter allowance should decrease after mint",
    );

    // Burn max u256
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatcher.burn(max_u256);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.burner) == 0,
        "balance_of burner should be zero after burning all",
    );
    assert!(
        dispatcher.balanceOf(addresses.burner) == 0,
        "balanceOf burner should be zero after burning all",
    );
    assert!(dispatcher.total_supply() == 0, "total_supply should be zero after burning all");
    assert!(dispatcher.totalSupply() == 0, "totalSupply should be zero after burning all");
}

#[test]
fn test_mint_burn_smallest_unit() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let minter_management_dispatcher = dispatchers.minter_management_dispatcher;
    let minter_allowance = minter_management_dispatcher.minter_allowance(addresses.minter);

    // Test with smallest possible non-zero amount (1 unit)
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.burner, 1);
    stop_cheat_caller_address(contract_address);

    // Verify balance
    assert!(
        dispatcher.balance_of(addresses.burner) == 1, "balance_of burner should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.burner) == 1, "balanceOf burner should have minted amount",
    );
    assert!(dispatcher.total_supply() == 1, "total_supply should be 1");
    assert!(dispatcher.totalSupply() == 1, "totalSupply should be 1");

    // Check that minter allowance has decreased
    let expected_remaining_allowance = minter_allowance - 1;
    assert!(
        minter_management_dispatcher
            .minter_allowance(addresses.minter) == expected_remaining_allowance,
        "Minter allowance should decrease after mint",
    );

    // Burn the 1 unit
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatcher.burn(1);
    stop_cheat_caller_address(contract_address);

    // Should be zero
    assert!(
        dispatcher.balance_of(addresses.burner) == 0,
        "balance_of burner should be zero after burning all",
    );
    assert!(
        dispatcher.balanceOf(addresses.burner) == 0,
        "balanceOf burner should be zero after burning all",
    );
    assert!(dispatcher.total_supply() == 0, "total_supply should be 0");
    assert!(dispatcher.totalSupply() == 0, "totalSupply should be 0");
}

#[test]
#[should_panic(expected: ('Burn amount exceeds balance',))]
fn test_burn_one_more_than_smallest_unit() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let minter_management_dispatcher = dispatchers.minter_management_dispatcher;
    let minter_allowance = minter_management_dispatcher.minter_allowance(addresses.minter);

    // Mint exactly 1 unit (smallest possible)
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.burner, 1);
    stop_cheat_caller_address(contract_address);

    // Check that minter allowance has decreased
    let expected_remaining_allowance = minter_allowance - 1;
    assert!(
        minter_management_dispatcher
            .minter_allowance(addresses.minter) == expected_remaining_allowance,
        "Minter allowance should decrease after mint",
    );

    // Try to burn 2 units (1 more than balance)
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatcher.burn(2); // Should panic - trying to burn more than available
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_mint_and_burn_large_number_arithmetic() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let minter_management_dispatcher = dispatchers.minter_management_dispatcher;

    // Test with numbers near u256 boundaries
    let large_num1: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00;
    let large_num2: u256 = 0xff; // This should fit when added to large_num1
    let expected_total = large_num1 + large_num2;

    // Configure minter with large allowance
    start_cheat_caller_address(contract_address, addresses.controller_1);
    minter_management_dispatcher.configure_minter(expected_total);
    stop_cheat_caller_address(contract_address);

    // Get minter allowance after configuration
    let minter_allowance = minter_management_dispatcher.minter_allowance(addresses.minter);

    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.burner, large_num1);
    dispatcher.mint(addresses.burner, large_num2);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.burner) == expected_total,
        "balance_of burner should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.burner) == expected_total,
        "balanceOf burner should have minted amount",
    );
    assert!(dispatcher.total_supply() == expected_total, "total_supply should match large amount");
    assert!(dispatcher.totalSupply() == expected_total, "totalSupply should match large amount");

    // Check that minter allowance has decreased
    let expected_remaining_allowance = minter_allowance - expected_total;
    assert!(
        minter_management_dispatcher
            .minter_allowance(addresses.minter) == expected_remaining_allowance,
        "Minter allowance should decrease after mints",
    );

    // Burn large amount
    start_cheat_caller_address(contract_address, addresses.burner);
    dispatcher.burn(expected_total);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.burner) == 0,
        "balance_of burner should be zero after burning all",
    );
    assert!(
        dispatcher.balanceOf(addresses.burner) == 0,
        "balanceOf burner should be zero after burning all",
    );
    assert!(dispatcher.total_supply() == 0, "total_supply should match large amount");
    assert!(dispatcher.totalSupply() == 0, "totalSupply should match large amount");
}

#[test]
#[should_panic(expected: ('u256_add Overflow',))]
fn test_mint_causes_total_supply_integer_overflow() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let minter_management_dispatcher = dispatchers.minter_management_dispatcher;

    // Set up maximum u256 value as the base total supply
    let max_u256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    // Configure minter with maximum allowance to allow minting of max amounts
    start_cheat_caller_address(contract_address, addresses.controller_1);
    minter_management_dispatcher.configure_minter(max_u256);
    stop_cheat_caller_address(contract_address);

    // First, mint the maximum possible u256 value to set total_supply to max
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.recipient_1, max_u256);
    stop_cheat_caller_address(contract_address);

    // Verify that total supply is now at maximum
    assert!(
        dispatcher.balance_of(addresses.recipient_1) == max_u256,
        "balance_of recipient_1 should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == max_u256,
        "balanceOf recipient_1 should have minted amount",
    );
    assert!(dispatcher.total_supply() == max_u256, "total_supply should be at maximum u256");
    assert!(dispatcher.totalSupply() == max_u256, "totalSupply should be at maximum u256");

    // Configure the minter again to allow another mint (since allowance was depleted)
    start_cheat_caller_address(contract_address, addresses.controller_1);
    minter_management_dispatcher.configure_minter(1); // Even 1 token should cause overflow
    stop_cheat_caller_address(contract_address);

    // Now attempt to mint 1 more token, which should cause total_supply overflow
    // This should panic with integer overflow error
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.recipient_2, 1); // This should panic due to total_supply overflow
    stop_cheat_caller_address(contract_address);
}
