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
use stablecoin::fiat_token::events::{Approval, Transfer};
use starknet::ContractAddress;
use super::common::{
    deploy_fiat_token, deploy_fiat_token_with_controller, get_contract_addresses, get_zero_address,
};

// ================================
// CORE FUNCTIONALITY TESTS
// ================================

#[test]
fn test_transfer_success() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let transfer_amount: u256 = 1000;
    let mint_amount: u256 = 1000000;

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens to spender
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.spender, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens to recipient_1
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer(addresses.recipient_1, transfer_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.recipient_1) == transfer_amount,
        "balance_of recipient_1 should have transferred amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == transfer_amount,
        "balanceOf recipient_1 should have transferred amount",
    );
    assert!(
        dispatcher.balance_of(addresses.spender) == mint_amount - transfer_amount,
        "balance_of spender should have minted amount minus transferred amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.spender) == mint_amount - transfer_amount,
        "balanceOf spender should have minted amount minus transferred amount",
    );

    // Verify Transfer event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.spender,
                            to: addresses.recipient_1,
                            value: transfer_amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_transfer_multiple_recipients() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let transfer_1_amount: u256 = 1000;
    let transfer_2_amount: u256 = 2000;
    let mint_amount: u256 = 1000000;

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens to spender
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.spender, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens to recipient_1 and recipient_2
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer(addresses.recipient_1, transfer_1_amount);
    dispatcher.transfer(addresses.recipient_2, transfer_2_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.recipient_1) == transfer_1_amount,
        "balance_of recipient_1 should have transfer_1_amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == transfer_1_amount,
        "balanceOf recipient_1 should have transfer_1_amount",
    );
    assert!(
        dispatcher.balance_of(addresses.recipient_2) == transfer_2_amount,
        "balance_of recipient_2 should have transfer_2_amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_2) == transfer_2_amount,
        "balanceOf recipient_2 should have transfer_2_amount",
    );
    let expected_balance = mint_amount - transfer_1_amount - transfer_2_amount;
    assert!(
        dispatcher.balance_of(addresses.spender) == expected_balance,
        "balance_of spender should have minted amount minus transferred amounts",
    );
    assert!(
        dispatcher.balanceOf(addresses.spender) == expected_balance,
        "balanceOf spender should have minted amount minus transferred amounts",
    );

    // Verify Transfer events were emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.spender,
                            to: addresses.recipient_1,
                            value: transfer_1_amount,
                        },
                    ),
                ),
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.spender,
                            to: addresses.recipient_2,
                            value: transfer_2_amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_approve_success() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let allowance: u256 = 12345;

    // Spy on events
    let mut spy = spy_events();

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == allowance,
        "Allowance should be set to the specified amount",
    );

    // Verify Approval event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Approval(
                        Approval {
                            owner: addresses.test_user,
                            spender: addresses.spender,
                            value: allowance,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_approve_multiple_spenders() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let spender_2: ContractAddress = 'spender_2'.try_into().unwrap();
    let allowance_1: u256 = 12345;
    let allowance_2: u256 = 54321;

    // Spy on events
    let mut spy = spy_events();

    // Approve allowance for spender and spender_2
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance_1);
    dispatcher.approve(spender_2, allowance_2);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == allowance_1,
        "Allowance for spendershould be set to the specified amount",
    );
    assert!(
        dispatcher.allowance(addresses.test_user, spender_2) == allowance_2,
        "Allowance for spender_2 should be set to the specified amount",
    );

    // Verify Approval event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Approval(
                        Approval {
                            owner: addresses.test_user,
                            spender: addresses.spender,
                            value: allowance_1,
                        },
                    ),
                ),
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Approval(
                        Approval {
                            owner: addresses.test_user, spender: spender_2, value: allowance_2,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_transfer_from_success() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let mint_amount: u256 = 1000000;
    let allowance: u256 = 12345;
    let transfer_amount: u256 = 1000;

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.test_user, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens from test_user to recipient_1
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer_from(addresses.test_user, addresses.recipient_1, transfer_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.recipient_1) == transfer_amount,
        "balance_of recipient_1 should have transferred amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == transfer_amount,
        "balanceOf recipient_1 should have transferred amount",
    );

    let expected_balance = mint_amount - transfer_amount;
    assert!(
        dispatcher.balance_of(addresses.test_user) == expected_balance,
        "balance_of test_user should have minted amount minus transferred amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.test_user) == expected_balance,
        "balanceOf test_user should have minted amount minus transferred amount",
    );
    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == allowance - transfer_amount,
        "Allowance should be decreased by the transferred amount",
    );

    // Verify Transfer event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.test_user,
                            to: addresses.recipient_1,
                            value: transfer_amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_transferFrom_success() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let mint_amount: u256 = 1000000;
    let allowance: u256 = 12345;
    let transfer_amount: u256 = 1000;

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.test_user, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens from test_user to recipient_1
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, transfer_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.recipient_1) == transfer_amount,
        "balance_of recipient_1 should have transferred amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == transfer_amount,
        "balanceOf recipient_1 should have transferred amount",
    );

    let expected_balance = mint_amount - transfer_amount;
    assert!(
        dispatcher.balance_of(addresses.test_user) == expected_balance,
        "balance_of test_user should have minted amount minus transferred amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.test_user) == expected_balance,
        "balanceOf test_user should have minted amount minus transferred amount",
    );
    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == allowance - transfer_amount,
        "Allowance should be decreased by the transferred amount",
    );

    // Verify Transfer event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.test_user,
                            to: addresses.recipient_1,
                            value: transfer_amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_transfer_from_multiple_recipients() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let mint_amount: u256 = 1000000;
    let allowance: u256 = 100000;
    let transfer_1_amount: u256 = 1000;
    let transfer_2_amount: u256 = 2000;

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.test_user, mint_amount);
    stop_cheat_caller_address(contract_address);

    // test_user approves allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens from test_user to recipient_1 and recipient_2
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer_from(addresses.test_user, addresses.recipient_1, transfer_1_amount);
    dispatcher.transfer_from(addresses.test_user, addresses.recipient_2, transfer_2_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.recipient_1) == transfer_1_amount,
        "balance_of recipient_1 should have transfer_1_amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == transfer_1_amount,
        "balanceOf recipient_1 should have transfer_1_amount",
    );
    assert!(
        dispatcher.balance_of(addresses.recipient_2) == transfer_2_amount,
        "balance_of recipient_2 should have transfer_2_amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_2) == transfer_2_amount,
        "balanceOf recipient_2 should have transfer_2_amount",
    );
    let expected_balance = mint_amount - transfer_1_amount - transfer_2_amount;
    assert!(
        dispatcher.balance_of(addresses.test_user) == expected_balance,
        "balance_of test_user should have minted amount minus transferred amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.test_user) == expected_balance,
        "balanceOf test_user should have minted amount minus transferred amount",
    );
    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == allowance
            - transfer_1_amount
            - transfer_2_amount,
        "Allowance should be decreased by the transferred amount",
    );

    // Verify Transfer events were emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.test_user,
                            to: addresses.recipient_1,
                            value: transfer_1_amount,
                        },
                    ),
                ),
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.test_user,
                            to: addresses.recipient_2,
                            value: transfer_2_amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_transferFrom_multiple_recipients() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let mint_amount: u256 = 1000000;
    let allowance: u256 = 100000;
    let transfer_1_amount: u256 = 1000;
    let transfer_2_amount: u256 = 2000;

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.test_user, mint_amount);
    stop_cheat_caller_address(contract_address);

    // test_user approves allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens from test_user to recipient_1 and recipient_2
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, transfer_1_amount);
    dispatcher.transferFrom(addresses.test_user, addresses.recipient_2, transfer_2_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.recipient_1) == transfer_1_amount,
        "balance_of recipient_1 should have transfer_1_amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == transfer_1_amount,
        "balanceOf recipient_1 should have transfer_1_amount",
    );
    assert!(
        dispatcher.balance_of(addresses.recipient_2) == transfer_2_amount,
        "balance_of recipient_2 should have transfer_2_amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_2) == transfer_2_amount,
        "balanceOf recipient_2 should have transfer_2_amount",
    );
    let expected_balance = mint_amount - transfer_1_amount - transfer_2_amount;
    assert!(
        dispatcher.balance_of(addresses.test_user) == expected_balance,
        "balance_of test_user should have minted amount minus transferred amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.test_user) == expected_balance,
        "balanceOf test_user should have minted amount minus transferred amount",
    );
    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == allowance
            - transfer_1_amount
            - transfer_2_amount,
        "Allowance should be decreased by the transferred amount",
    );

    // Verify Transfer events were emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.test_user,
                            to: addresses.recipient_1,
                            value: transfer_1_amount,
                        },
                    ),
                ),
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.test_user,
                            to: addresses.recipient_2,
                            value: transfer_2_amount,
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
#[should_panic(expected: ('From address cannot be zero',))]
fn test_transfer_rejects_zero_from_address() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let from_address = get_zero_address();
    let to_address = get_zero_address();
    let amount = 100;

    start_cheat_caller_address(contract_address, from_address);
    dispatcher.transfer(to_address, amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('To address cannot be zero',))]
fn test_transfer_rejects_zero_to_address() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let from_address = addresses.test_user;
    let to_address = get_zero_address();
    let amount = 100;

    start_cheat_caller_address(contract_address, from_address);
    dispatcher.transfer(to_address, amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Transfer amount exceeds balance',))]
fn test_transfer_exceeds_zero_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let amount = 1000;

    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.transfer(addresses.recipient_1, amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Transfer amount exceeds balance',))]
fn test_transfer_exceeds_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let mint_amount: u256 = 100;
    let transfer_amount: u256 = 1000;

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.test_user, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer with insufficient balance
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.transfer(addresses.recipient_1, transfer_amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Transfer allowance exceeded',))]
fn test_transfer_from_exceeds_zero_allowance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let amount = 100;

    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer_from(addresses.spender, addresses.recipient_1, amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Transfer allowance exceeded',))]
fn test_transferFrom_exceeds_zero_allowance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let amount = 100;

    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transferFrom(addresses.spender, addresses.recipient_1, amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Transfer allowance exceeded',))]
fn test_transfer_from_exceeds_allowance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let allowance: u256 = 100;
    let amount: u256 = 1000;

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer with insufficient allowance
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer_from(addresses.test_user, addresses.recipient_1, amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Transfer allowance exceeded',))]
fn test_transferFrom_exceeds_allowance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let allowance: u256 = 100;
    let amount: u256 = 1000;

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer with insufficient allowance
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Transfer amount exceeds balance',))]
fn test_transfer_from_exceeds_zero_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let allowance: u256 = 10000;
    let transfer_amount: u256 = 1000;

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer with insufficient balance
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer_from(addresses.test_user, addresses.recipient_1, transfer_amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Transfer amount exceeds balance',))]
fn test_transferFrom_exceeds_zero_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let allowance: u256 = 10000;
    let transfer_amount: u256 = 1000;

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer with insufficient balance
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, transfer_amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Transfer amount exceeds balance',))]
fn test_transfer_from_exceeds_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let mint_amount: u256 = 100;
    let allowance: u256 = 1000;
    let transfer_amount: u256 = 1000;

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.test_user, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer with insufficient balance
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer_from(addresses.test_user, addresses.recipient_1, transfer_amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Transfer amount exceeds balance',))]
fn test_transferFrom_exceeds_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let mint_amount: u256 = 100;
    let allowance: u256 = 1000;
    let transfer_amount: u256 = 1000;

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.test_user, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer with insufficient balance
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, transfer_amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('From address cannot be zero',))]
fn test_approve_rejects_zero_from_address() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let from_address = get_zero_address();
    let spender_address = get_zero_address();
    let amount = 100;

    start_cheat_caller_address(contract_address, from_address);
    dispatcher.approve(spender_address, amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('To address cannot be zero',))]
fn test_approve_rejects_zero_spender_address() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let from_address = addresses.test_user;
    let spender_address = get_zero_address();
    let amount = 100;

    start_cheat_caller_address(contract_address, from_address);
    dispatcher.approve(spender_address, amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_transfer_rejects_when_paused() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let pausable_dispatcher = dispatchers.pausable_dispatcher;

    // Pause contract
    start_cheat_caller_address(contract_address, addresses.pauser);
    pausable_dispatcher.pause();
    stop_cheat_caller_address(contract_address);

    // Attempt transfer
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.transfer(addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_transfer_from_rejects_when_paused() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let pausable_dispatcher = dispatchers.pausable_dispatcher;

    // Pause contract
    start_cheat_caller_address(contract_address, addresses.pauser);
    pausable_dispatcher.pause();
    stop_cheat_caller_address(contract_address);

    // Attempt transfer_from
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer_from(addresses.test_user, addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_transferFrom_rejects_when_paused() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let pausable_dispatcher = dispatchers.pausable_dispatcher;

    // Pause contract
    start_cheat_caller_address(contract_address, addresses.pauser);
    pausable_dispatcher.pause();
    stop_cheat_caller_address(contract_address);

    // Attempt transferFrom
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Contract is paused',))]
fn test_approve_rejects_when_paused() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let pausable_dispatcher = dispatchers.pausable_dispatcher;

    // Pause contract
    start_cheat_caller_address(contract_address, addresses.pauser);
    pausable_dispatcher.pause();
    stop_cheat_caller_address(contract_address);

    // Attempt approve
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transfer_rejects_when_caller_blocklisted() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist caller
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.test_user);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatchers.fiat_token_dispatcher.transfer(addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transfer_rejects_when_to_address_blocklisted() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist recipient_1
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.recipient_1);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatchers.fiat_token_dispatcher.transfer(addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transfer_rejects_when_caller_blocklisted_after_transfer() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.test_user, 100);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatchers.fiat_token_dispatcher.transfer(addresses.recipient_1, 50);
    stop_cheat_caller_address(contract_address);

    // Blocklist caller
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.test_user);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatchers.fiat_token_dispatcher.transfer(addresses.recipient_1, 50);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transfer_rejects_when_to_address_blocklisted_after_transfer() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.test_user, 100);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatchers.fiat_token_dispatcher.transfer(addresses.recipient_1, 50);
    stop_cheat_caller_address(contract_address);

    // Blocklist recipient_1
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.recipient_1);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatchers.fiat_token_dispatcher.transfer(addresses.recipient_1, 50);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transfer_from_rejects_when_caller_blocklisted() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist caller
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.spender);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer_from
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers
        .fiat_token_dispatcher
        .transfer_from(addresses.test_user, addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transferFrom_rejects_when_caller_blocklisted() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist caller
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.spender);
    stop_cheat_caller_address(contract_address);

    // Attempt transferFrom
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transfer_from_rejects_when_from_address_blocklisted() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist test_user
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.test_user);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer_from
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers
        .fiat_token_dispatcher
        .transfer_from(addresses.test_user, addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transferFrom_rejects_when_from_address_blocklisted() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist test_user
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.test_user);
    stop_cheat_caller_address(contract_address);

    // Attempt transferFrom
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transfer_from_rejects_when_to_address_blocklisted() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist recipient_1
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.recipient_1);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer_from
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers
        .fiat_token_dispatcher
        .transfer_from(addresses.test_user, addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transferFrom_rejects_when_to_address_blocklisted() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Blocklist recipient_1
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.recipient_1);
    stop_cheat_caller_address(contract_address);

    // Attempt transferFrom
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transfer_from_rejects_when_caller_blocklisted_after_transfer_from() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.test_user, 100);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatchers.fiat_token_dispatcher.approve(addresses.spender, 100);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transfer_from(addresses.test_user, addresses.recipient_1, 50);
    stop_cheat_caller_address(contract_address);

    // Blocklist caller
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.spender);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer_from
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transfer_from(addresses.test_user, addresses.recipient_1, 50);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transferFrom_rejects_when_caller_blocklisted_after_transferFrom() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.test_user, 100);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatchers.fiat_token_dispatcher.approve(addresses.spender, 100);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, 50);
    stop_cheat_caller_address(contract_address);

    // Blocklist caller
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.spender);
    stop_cheat_caller_address(contract_address);

    // Attempt transferFrom
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, 50);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transfer_from_rejects_when_from_address_blocklisted_after_transfer_from() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.test_user, 100);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatchers.fiat_token_dispatcher.approve(addresses.spender, 100);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transfer_from(addresses.test_user, addresses.recipient_1, 50);
    stop_cheat_caller_address(contract_address);

    // Blocklist test_user
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.test_user);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer_from
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers
        .fiat_token_dispatcher
        .transfer_from(addresses.test_user, addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transferFrom_rejects_when_from_address_blocklisted_after_transferFrom() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.test_user, 100);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatchers.fiat_token_dispatcher.approve(addresses.spender, 100);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, 50);
    stop_cheat_caller_address(contract_address);

    // Blocklist test_user
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.test_user);
    stop_cheat_caller_address(contract_address);

    // Attempt transferFrom
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transfer_from_rejects_when_to_address_blocklisted_after_transfer_from() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.test_user, 100);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatchers.fiat_token_dispatcher.approve(addresses.spender, 100);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transfer_from(addresses.test_user, addresses.recipient_1, 50);
    stop_cheat_caller_address(contract_address);

    // Blocklist recipient_1
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.recipient_1);
    stop_cheat_caller_address(contract_address);

    // Attempt transfer_from
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers
        .fiat_token_dispatcher
        .transfer_from(addresses.test_user, addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Address is blocklisted',))]
fn test_transferFrom_rejects_when_to_address_blocklisted_after_transferFrom() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatchers.fiat_token_dispatcher.mint(addresses.test_user, 100);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatchers.fiat_token_dispatcher.approve(addresses.spender, 100);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, 50);
    stop_cheat_caller_address(contract_address);

    // Blocklist recipient_1
    start_cheat_caller_address(contract_address, addresses.blocklister);
    dispatchers.blocklistable_dispatcher.blocklist(addresses.recipient_1);
    stop_cheat_caller_address(contract_address);

    // Attempt transferFrom
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatchers.fiat_token_dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, 100);
    stop_cheat_caller_address(contract_address);
}

// ================================
// EDGE CASE TESTS
// ================================

#[test]
fn test_transfer_zero_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let mint_amount: u256 = 1000000;
    let transfer_amount: u256 = 0;

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens to spender
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.spender, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens to recipient_1
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer(addresses.recipient_1, transfer_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.spender) == mint_amount,
        "balance_of spender should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.spender) == mint_amount,
        "balanceOf spender should have minted amount",
    );
    assert!(
        dispatcher.balance_of(addresses.recipient_1) == 0,
        "balance_of recipient_1 should have 0 balance",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == 0,
        "balanceOf recipient_1 should have 0 balance",
    );

    // Verify Transfer event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.spender,
                            to: addresses.recipient_1,
                            value: transfer_amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_transfer_exact_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let mint_amount: u256 = 1000000;

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens to spender
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.spender, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens to recipient_1
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer(addresses.recipient_1, mint_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.recipient_1) == mint_amount,
        "balance_of recipient_1 should have minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == mint_amount,
        "balanceOf recipient_1 should have minted amount",
    );
    assert!(
        dispatcher.balance_of(addresses.spender) == 0, "balance_of spender should have 0 balance",
    );
    assert!(
        dispatcher.balanceOf(addresses.spender) == 0, "balanceOf spender should have 0 balance",
    );

    // Verify Transfer event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.spender, to: addresses.recipient_1, value: mint_amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_approve_zero_allowance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let allowance: u256 = 0;

    // Spy on events
    let mut spy = spy_events();

    // Approve zero allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == 0,
        "Allowance should be set to 0",
    );

    // Verify Approval event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Approval(
                        Approval {
                            owner: addresses.test_user,
                            spender: addresses.spender,
                            value: allowance,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_approve_spender_multiple_times() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let allowance_1: u256 = 12345;
    let allowance_2: u256 = 54321;
    let allowance_3: u256 = 100;
    let allowance_4: u256 = 0;

    // Spy on events
    let mut spy = spy_events();

    // Approve allowance for spender multiple times
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance_1);
    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == allowance_1,
        "Allowance should be set to allowance_1",
    );
    dispatcher.approve(addresses.spender, allowance_2);
    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == allowance_2,
        "Allowance should be set to allowance_2",
    );
    dispatcher.approve(addresses.spender, allowance_3);
    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == allowance_3,
        "Allowance should be set to allowance_3",
    );
    dispatcher.approve(addresses.spender, allowance_4);
    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == allowance_4,
        "Allowance should be set to allowance_4",
    );
    stop_cheat_caller_address(contract_address);

    // Verify Approval event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Approval(
                        Approval {
                            owner: addresses.test_user,
                            spender: addresses.spender,
                            value: allowance_1,
                        },
                    ),
                ),
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Approval(
                        Approval {
                            owner: addresses.test_user,
                            spender: addresses.spender,
                            value: allowance_2,
                        },
                    ),
                ),
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Approval(
                        Approval {
                            owner: addresses.test_user,
                            spender: addresses.spender,
                            value: allowance_3,
                        },
                    ),
                ),
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Approval(
                        Approval {
                            owner: addresses.test_user,
                            spender: addresses.spender,
                            value: allowance_4,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_transfer_from_exact_allowance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let mint_amount: u256 = 1000000;
    let allowance: u256 = 12345;

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.test_user, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens from test_user to recipient_1
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer_from(addresses.test_user, addresses.recipient_1, allowance);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.recipient_1) == allowance,
        "balance_of recipient_1 should have received the allowance amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == allowance,
        "balanceOf recipient_1 should have received the allowance amount",
    );
    assert!(
        dispatcher.balance_of(addresses.test_user) == mint_amount - allowance,
        "balance_of test_user should have minted amount minus allowance amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.test_user) == mint_amount - allowance,
        "balanceOf test_user should have minted amount minus allowance amount",
    );
    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == 0, "Allowance should be 0",
    );

    // Verify Transfer event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.test_user, to: addresses.recipient_1, value: allowance,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_transferFrom_exact_allowance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;

    let mint_amount: u256 = 1000000;
    let allowance: u256 = 12345;

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.test_user, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, allowance);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens from test_user to recipient_1
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, allowance);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.recipient_1) == allowance,
        "balance_of recipient_1 should have received the allowance amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == allowance,
        "balanceOf recipient_1 should have received the allowance amount",
    );
    assert!(
        dispatcher.balance_of(addresses.test_user) == mint_amount - allowance,
        "balance_of test_user should have minted amount minus allowance amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.test_user) == mint_amount - allowance,
        "balanceOf test_user should have minted amount minus allowance amount",
    );
    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == 0, "Allowance should be 0",
    );

    // Verify Transfer event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.test_user, to: addresses.recipient_1, value: allowance,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_transfer_from_exact_allowance_and_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let mint_amount: u256 = 1000000;

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.test_user, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens from test_user to recipient_1
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transfer_from(addresses.test_user, addresses.recipient_1, mint_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.recipient_1) == mint_amount,
        "balance_of recipient_1 should have received the minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == mint_amount,
        "balanceOf recipient_1 should have received the minted amount",
    );
    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == 0, "Allowance should be 0",
    );

    // Verify Transfer event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.test_user,
                            to: addresses.recipient_1,
                            value: mint_amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_transferFrom_exact_allowance_and_balance() {
    let addresses = get_contract_addresses();
    let (contract_address, dispatchers) = deploy_fiat_token_with_controller(addresses);
    let dispatcher = dispatchers.fiat_token_dispatcher;
    let mint_amount: u256 = 1000000;

    // Spy on events
    let mut spy = spy_events();

    // Mint tokens to test_user
    start_cheat_caller_address(contract_address, addresses.minter);
    dispatcher.mint(addresses.test_user, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Approve allowance for spender
    start_cheat_caller_address(contract_address, addresses.test_user);
    dispatcher.approve(addresses.spender, mint_amount);
    stop_cheat_caller_address(contract_address);

    // Transfer tokens from test_user to recipient_1
    start_cheat_caller_address(contract_address, addresses.spender);
    dispatcher.transferFrom(addresses.test_user, addresses.recipient_1, mint_amount);
    stop_cheat_caller_address(contract_address);

    assert!(
        dispatcher.balance_of(addresses.recipient_1) == mint_amount,
        "balance_of recipient_1 should have received the minted amount",
    );
    assert!(
        dispatcher.balanceOf(addresses.recipient_1) == mint_amount,
        "balanceOf recipient_1 should have received the minted amount",
    );
    assert!(
        dispatcher.allowance(addresses.test_user, addresses.spender) == 0, "Allowance should be 0",
    );

    // Verify Transfer event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::Transfer(
                        Transfer {
                            from: addresses.test_user,
                            to: addresses.recipient_1,
                            value: mint_amount,
                        },
                    ),
                ),
            ],
        );
}
