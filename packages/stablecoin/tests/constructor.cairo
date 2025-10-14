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

use components::blocklistable::{IBlocklistableDispatcher, IBlocklistableDispatcherTrait};
use components::manageable::{IManageableDispatcher, IManageableDispatcherTrait};
use components::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait};
use components::pausable::{IPausableDispatcher, IPausableDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
};
use stablecoin::fiat_token::events::FiatTokenInitialized;
use stablecoin::fiat_token::{IFiatTokenDispatcher, IFiatTokenDispatcherTrait};
use stablecoin::metadata::{IMetadataDispatcher, IMetadataDispatcherTrait};
use stablecoin::minter_management::{IMinterManagementDispatcher, IMinterManagementDispatcherTrait};
use super::common::{get_contract_addresses, get_zero_address};

// ================================
// CORE FUNCTIONALITY TESTS
// ================================

#[test]
fn test_constructor_succeeds() {
    let addresses = get_contract_addresses();
    let contract = declare("FiatToken").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "USDC";
    let symbol: ByteArray = "USDC";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(6);
    constructor_calldata.append(addresses.master_minter.into());
    constructor_calldata.append(addresses.owner.into());
    constructor_calldata.append(addresses.pauser.into());
    constructor_calldata.append(addresses.blocklister.into());
    constructor_calldata.append(addresses.metadata_updater.into());
    constructor_calldata.append(addresses.admin.into());

    // This should succeed when deploying with valid addresses
    let mut spy = spy_events();
    let result = contract.deploy(@constructor_calldata);
    assert!(result.is_ok(), "Deploy should succeed with valid addresses");

    // Get the deployed contract address
    let (contract_address, _) = result.unwrap();

    let metadata_dispatcher = IMetadataDispatcher { contract_address };
    assert!(metadata_dispatcher.name() == "USDC", "Name should match");
    assert!(metadata_dispatcher.symbol() == "USDC", "Symbol should match");
    assert!(metadata_dispatcher.decimals() == 6, "Decimals should match");

    // Assert the master minter address is set correctly
    let master_minter = IMinterManagementDispatcher { contract_address }.master_minter();
    assert!(master_minter == addresses.master_minter, "Owner address should match");

    // Assert the owner address is set correctly
    let owner = IOwnableDispatcher { contract_address }.owner();
    assert!(owner == addresses.owner, "Owner should match");

    // Assert the pauser address is set correctly
    let pauser = IPausableDispatcher { contract_address }.pauser();
    assert!(pauser == addresses.pauser, "Pauser should match");

    // Assert the blocklister address is set correctly
    let blocklister = IBlocklistableDispatcher { contract_address }.blocklister();
    assert!(blocklister == addresses.blocklister, "Blocklister should match");

    // Assert the metadata updater address is set correctly
    let metadata_updater = IMetadataDispatcher { contract_address }.metadata_updater();
    assert!(metadata_updater == addresses.metadata_updater, "Metadata updater should match");

    // Assert the admin address is set correctly
    let admin = IManageableDispatcher { contract_address }.admin();
    assert!(admin == addresses.admin, "Admin should match");

    // Assert the fiat token state variables are set correctly
    let fiat_token = IFiatTokenDispatcher { contract_address };
    assert!(fiat_token.version() == 1, "Version should be 1");
    assert!(fiat_token.total_supply() == 0, "total_supply should be 0");
    assert!(fiat_token.totalSupply() == 0, "totalSupply should be 0");

    // Assert the fiat token is blocklisted
    let fiat_token_blocklist = IBlocklistableDispatcher { contract_address };
    assert!(
        fiat_token_blocklist.is_blocklisted(contract_address), "Fiat token should be blocklisted",
    );

    // Assert the FiatTokenInitialized event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    stablecoin::fiat_token::FiatToken::Event::FiatTokenInitialized(
                        FiatTokenInitialized { initialized_version: 1 },
                    ),
                ),
            ],
        );
}

// ================================
// ERROR HANDLING TESTS
// ================================

#[test]
fn test_constructor_rejects_zero_master_minter() {
    let addresses = get_contract_addresses();
    let contract = declare("FiatToken").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "USDC";
    let symbol: ByteArray = "USDC";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(6);
    constructor_calldata.append(get_zero_address().into());
    constructor_calldata.append(addresses.owner.into());
    constructor_calldata.append(addresses.pauser.into());
    constructor_calldata.append(addresses.blocklister.into());
    constructor_calldata.append(addresses.metadata_updater.into());
    constructor_calldata.append(addresses.admin.into());

    // This should fail when deploying with zero master minter
    let result = contract.deploy(@constructor_calldata);
    assert!(result.is_err(), "Deploy should fail with zero master minter");

    // Check if the error contains the expected message
    let error_data = result.unwrap_err();
    assert!(
        *error_data.at(0) == 'Master Minter cannot be zero',
        "Expected 'Master Minter cannot be zero' error",
    );
}

#[test]
fn test_constructor_rejects_zero_owner() {
    let addresses = get_contract_addresses();
    let contract = declare("FiatToken").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "USDC";
    let symbol: ByteArray = "USDC";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(6);
    constructor_calldata.append(addresses.master_minter.into());
    constructor_calldata.append(get_zero_address().into());
    constructor_calldata.append(addresses.pauser.into());
    constructor_calldata.append(addresses.blocklister.into());
    constructor_calldata.append(addresses.metadata_updater.into());
    constructor_calldata.append(addresses.admin.into());

    // This should fail when deploying with zero owner
    let result = contract.deploy(@constructor_calldata);
    assert!(result.is_err(), "Deploy should fail with zero owner");

    // Check if the error contains the expected message
    let error_data = result.unwrap_err();
    assert!(
        *error_data.at(0) == 'Owner cannot be zero address',
        "Expected 'Owner cannot be zero address' error",
    );
}

#[test]
fn test_constructor_rejects_zero_pauser() {
    let addresses = get_contract_addresses();
    let contract = declare("FiatToken").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "USDC";
    let symbol: ByteArray = "USDC";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(6);
    constructor_calldata.append(addresses.master_minter.into());
    constructor_calldata.append(addresses.owner.into());
    constructor_calldata.append(get_zero_address().into());
    constructor_calldata.append(addresses.blocklister.into());
    constructor_calldata.append(addresses.metadata_updater.into());
    constructor_calldata.append(addresses.admin.into());

    // This should fail when deploying with zero pauser
    let result = contract.deploy(@constructor_calldata);
    assert!(result.is_err(), "Deploy should fail with zero pauser");

    // Check if the error contains the expected message
    let error_data = result.unwrap_err();
    assert!(
        *error_data.at(0) == 'Pauser cannot be zero address',
        "Expected 'Pauser cannot be zero address' error",
    );
}

#[test]
fn test_constructor_rejects_zero_blocklister() {
    let addresses = get_contract_addresses();
    let contract = declare("FiatToken").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "USDC";
    let symbol: ByteArray = "USDC";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(6);
    constructor_calldata.append(addresses.master_minter.into());
    constructor_calldata.append(addresses.owner.into());
    constructor_calldata.append(addresses.pauser.into());
    constructor_calldata.append(get_zero_address().into());
    constructor_calldata.append(addresses.metadata_updater.into());
    constructor_calldata.append(addresses.admin.into());

    // This should fail when deploying with zero blocklister
    let result = contract.deploy(@constructor_calldata);
    assert!(result.is_err(), "Deploy should fail with zero blocklister");

    // Check if the error contains the expected message
    let error_data = result.unwrap_err();
    assert!(
        *error_data.at(0) == 'Blocklister cannot be zero',
        "Expected 'Blocklister cannot be zero' error",
    );
}

#[test]
fn test_constructor_rejects_zero_metadata_updater() {
    let addresses = get_contract_addresses();
    let contract = declare("FiatToken").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "USDC";
    let symbol: ByteArray = "USDC";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(6);
    constructor_calldata.append(addresses.master_minter.into());
    constructor_calldata.append(addresses.owner.into());
    constructor_calldata.append(addresses.pauser.into());
    constructor_calldata.append(addresses.blocklister.into());
    constructor_calldata.append(get_zero_address().into());
    constructor_calldata.append(addresses.admin.into());

    // This should fail when deploying with zero metadata updater
    let result = contract.deploy(@constructor_calldata);
    assert!(result.is_err(), "Deploy should fail with zero metadata updater");

    // Check if the error contains the expected message
    let error_data = result.unwrap_err();
    assert!(
        *error_data.at(0) == 'Metadata updater cannot be zero',
        "Expected 'Metadata updater cannot be zero' error",
    );
}

#[test]
fn test_constructor_rejects_invalid_name() {
    let addresses = get_contract_addresses();
    let contract = declare("FiatToken").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "";
    let symbol: ByteArray = "USDC";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(6);
    constructor_calldata.append(addresses.master_minter.into());
    constructor_calldata.append(addresses.owner.into());
    constructor_calldata.append(addresses.pauser.into());
    constructor_calldata.append(addresses.blocklister.into());
    constructor_calldata.append(addresses.metadata_updater.into());
    constructor_calldata.append(addresses.admin.into());

    // This should fail when deploying with invalid name
    let result = contract.deploy(@constructor_calldata);
    assert!(result.is_err(), "Deploy should fail with invalid name");

    // Check if the error contains the expected message
    let error_data = result.unwrap_err();
    assert!(
        *error_data.at(0) == 'Name must be non-empty', "Expected 'Name must be non-empty' error",
    );
}

#[test]
fn test_constructor_rejects_invalid_symbol() {
    let addresses = get_contract_addresses();
    let contract = declare("FiatToken").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "USDC";
    let symbol: ByteArray = "";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(6);
    constructor_calldata.append(addresses.master_minter.into());
    constructor_calldata.append(addresses.owner.into());
    constructor_calldata.append(addresses.pauser.into());
    constructor_calldata.append(addresses.blocklister.into());
    constructor_calldata.append(addresses.metadata_updater.into());
    constructor_calldata.append(addresses.admin.into());

    // This should fail when deploying with invalid name
    let result = contract.deploy(@constructor_calldata);
    assert!(result.is_err(), "Deploy should fail with invalid symbol");

    // Check if the error contains the expected message
    let error_data = result.unwrap_err();
    assert!(
        *error_data.at(0) == 'Symbol must be non-empty',
        "Expected 'Symbol must be non-empty' error",
    );
}

#[test]
fn test_constructor_rejects_invalid_decimals() {
    let addresses = get_contract_addresses();
    let contract = declare("FiatToken").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "USDC";
    let symbol: ByteArray = "USDC";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(0);
    constructor_calldata.append(addresses.master_minter.into());
    constructor_calldata.append(addresses.owner.into());
    constructor_calldata.append(addresses.pauser.into());
    constructor_calldata.append(addresses.blocklister.into());
    constructor_calldata.append(addresses.metadata_updater.into());
    constructor_calldata.append(addresses.admin.into());

    // This should fail when deploying with invalid decimals
    let result = contract.deploy(@constructor_calldata);
    assert!(result.is_err(), "Deploy should fail with invalid decimals");

    // Check if the error contains the expected message
    let error_data = result.unwrap_err();
    assert!(
        *error_data.at(0) == 'Decimals must be greater than 0',
        "Expected 'Decimals must be greater than 0' error",
    );
}

#[test]
fn test_constructor_rejects_zero_admin() {
    let addresses = get_contract_addresses();
    let contract = declare("FiatToken").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "USDC";
    let symbol: ByteArray = "USDC";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(6);
    constructor_calldata.append(addresses.master_minter.into());
    constructor_calldata.append(addresses.owner.into());
    constructor_calldata.append(addresses.pauser.into());
    constructor_calldata.append(addresses.blocklister.into());
    constructor_calldata.append(addresses.metadata_updater.into());
    constructor_calldata.append(get_zero_address().into());

    // This should fail when deploying with zero admin
    let result = contract.deploy(@constructor_calldata);
    assert!(result.is_err(), "Deploy should fail with zero admin");

    // Check if the error contains the expected message
    let error_data = result.unwrap_err();
    assert!(
        *error_data.at(0) == 'Admin cannot be zero address',
        "Expected 'Admin cannot be zero address' error",
    );
}
