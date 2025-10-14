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
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use stablecoin::metadata::{IMetadataDispatcher, IMetadataDispatcherTrait, MetadataComponent};
use starknet::ContractAddress;

// Mock contract that uses both ownable and metadata components for testing
#[starknet::contract]
mod MockMetadataContract {
    use components::ownable::OwnableComponent;
    use core::num::traits::Zero;
    use stablecoin::metadata::MetadataComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: MetadataComponent, storage: metadata, event: MetadataEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::Ownable<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl MetadataImpl = MetadataComponent::Metadata<ContractState>;
    impl MetadataInternalImpl = MetadataComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        metadata: MetadataComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        MetadataEvent: MetadataComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        metadata_updater: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
    ) {
        if !owner.is_zero() {
            self.ownable.initializer(owner);
        }
        if !metadata_updater.is_zero() {
            self.metadata.initializer(metadata_updater, name, symbol, decimals);
        }
    }

    // Expose internal functions for testing
    #[abi(per_item)]
    #[generate_trait]
    impl TestHelperImpl of TestHelperTrait {
        #[external(v0)]
        fn test_metadata_initializer(
            ref self: ContractState,
            metadata_updater: ContractAddress,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8,
        ) {
            self.metadata.initializer(metadata_updater, name, symbol, decimals);
        }

        #[external(v0)]
        fn test_assert_only_metadata_updater(self: @ContractState) {
            self.metadata.assert_only_metadata_updater();
        }

        #[external(v0)]
        fn test_ownable_initializer(ref self: ContractState, owner: ContractAddress) {
            self.ownable.initializer(owner);
        }
    }
}

// Helper trait for accessing test functions
#[starknet::interface]
trait ITestHelper<TContractState> {
    fn test_metadata_initializer(
        ref self: TContractState,
        metadata_updater: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
    );
    fn test_assert_only_metadata_updater(self: @TContractState);
    fn test_ownable_initializer(ref self: TContractState, owner: ContractAddress);
}

fn deploy_mock_contract(
    owner: ContractAddress,
    metadata_updater: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    decimals: u8,
) -> ContractAddress {
    let contract = declare("MockMetadataContract").unwrap().contract_class();
    let mut constructor_calldata = array![owner.into(), metadata_updater.into()];
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(decimals.into());
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn deploy_uninitialized_contract() -> ContractAddress {
    let contract = declare("MockMetadataContract").unwrap().contract_class();
    let zero_address: ContractAddress = 0.try_into().unwrap();
    let mut constructor_calldata = array![zero_address.into(), zero_address.into()];
    let empty_name: ByteArray = "";
    let empty_symbol: ByteArray = "";
    empty_name.serialize(ref constructor_calldata);
    empty_symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(0.into());
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let owner: ContractAddress = 123.try_into().unwrap();
    let metadata_updater: ContractAddress = 456.try_into().unwrap();
    let new_metadata_updater: ContractAddress = 789.try_into().unwrap();
    let unauthorized: ContractAddress = 999.try_into().unwrap();
    (owner, metadata_updater, new_metadata_updater, unauthorized)
}

// ================================
// CORE FUNCTIONALITY TESTS
// ================================

#[test]
fn test_initialized_contract_state() {
    let (owner, metadata_updater, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let dispatcher = IMetadataDispatcher { contract_address };

    // Check that metadata_updater is set correctly and contract starts unpaused
    assert!(
        dispatcher.metadata_updater() == metadata_updater,
        "Metadata Upgrader should return the correct address",
    );
    assert!(dispatcher.name() == "USDC", "Name should be USDC");
    assert!(dispatcher.symbol() == "USDC", "Symbol should be USDC");
    assert!(dispatcher.decimals() == 6, "Decimals should be 6");
}

#[test]
fn test_uninitialized_contract_state() {
    let contract_address = deploy_uninitialized_contract();
    let dispatcher = IMetadataDispatcher { contract_address };
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Check that metadata_updater is zero and contract is unpaused when uninitialized
    assert!(
        dispatcher.metadata_updater() == zero_address,
        "Uninitialized metadata_updater should be zero address",
    );
    assert!(dispatcher.name() == "", "Name should be empty");
    assert!(dispatcher.symbol() == "", "Symbol should be empty");
    assert!(dispatcher.decimals() == 0, "Decimals should be 0");
}

#[test]
fn test_update_metadata_updater_functionality() {
    let (owner, metadata_updater, new_metadata_updater, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let dispatcher = IMetadataDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Update metadata_updater as owner
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_metadata_updater(new_metadata_updater);
    stop_cheat_caller_address(contract_address);

    // Check that metadata_updater was updated
    assert!(
        dispatcher.metadata_updater() == new_metadata_updater,
        "Metadata Upgrader should be updated",
    );

    // Verify Metadata Upgrader Updated event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MetadataComponent::Event::MetadataUpgraderUpdated(
                        MetadataComponent::MetadataUpgraderUpdated {
                            old_metadata_updater: metadata_updater, new_metadata_updater,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_update_metadata_updater_to_current_owner() {
    let (owner, metadata_updater, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let metadata_dispatcher = IMetadataDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Update metadata updater to current owner
    start_cheat_caller_address(contract_address, owner);
    metadata_dispatcher.update_metadata_updater(owner);
    stop_cheat_caller_address(contract_address);

    assert!(metadata_dispatcher.metadata_updater() == owner, "Metadata updater should be owner");

    // Verify Metadata Upgrader Updated event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MetadataComponent::Event::MetadataUpgraderUpdated(
                        MetadataComponent::MetadataUpgraderUpdated {
                            old_metadata_updater: metadata_updater, new_metadata_updater: owner,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_update_metadata_updater_to_current_updater() {
    let (owner, metadata_updater, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let metadata_dispatcher = IMetadataDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Update metadata updater to current owner
    start_cheat_caller_address(contract_address, owner);
    metadata_dispatcher.update_metadata_updater(metadata_updater);
    stop_cheat_caller_address(contract_address);

    assert!(
        metadata_dispatcher.metadata_updater() == metadata_updater,
        "Metadata updater should be metadata_updater",
    );

    // Verify Metadata Upgrader Updated event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MetadataComponent::Event::MetadataUpgraderUpdated(
                        MetadataComponent::MetadataUpgraderUpdated {
                            old_metadata_updater: metadata_updater,
                            new_metadata_updater: metadata_updater,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_update_metadata_functionality() {
    let (owner, metadata_updater, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let dispatcher = IMetadataDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Update metadata
    start_cheat_caller_address(contract_address, metadata_updater);
    dispatcher.update_metadata("EURC", "EURC");
    stop_cheat_caller_address(contract_address);

    // Check that metadata was updated
    assert!(dispatcher.name() == "EURC", "Name should be EURC");
    assert!(dispatcher.symbol() == "EURC", "Symbol should be EURC");
    assert!(dispatcher.decimals() == 6, "Decimals should be 6");

    // Verify Metadata Updated event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MetadataComponent::Event::MetadataUpdated(
                        MetadataComponent::MetadataUpdated {
                            name: "EURC", symbol: "EURC", decimals: 6,
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
#[should_panic(expected: ('Caller is not the owner',))]
fn test_update_metadata_updater_rejects_non_owner() {
    let (owner, metadata_updater, new_metadata_updater, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let dispatcher = IMetadataDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.update_metadata_updater(new_metadata_updater);
}

#[test]
#[should_panic(expected: ('Metadata updater cannot be zero',))]
fn test_update_metadata_updater_rejects_zero_address() {
    let (owner, metadata_updater, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let dispatcher = IMetadataDispatcher { contract_address };

    let zero_address: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_metadata_updater(zero_address);
}

#[test]
#[should_panic(expected: ('Caller is not metadata updater',))]
fn test_update_metadata_rejects_non_metadata_updater() {
    let (owner, metadata_updater, _, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let dispatcher = IMetadataDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.update_metadata("EURC", "EURC");
}

#[test]
#[should_panic(expected: ('Caller is not metadata updater',))]
fn test_old_metadata_updater_invalidated_after_update() {
    let (owner, metadata_updater, new_metadata_updater, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let dispatcher = IMetadataDispatcher { contract_address };

    // Update metadata_updater as owner
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_metadata_updater(new_metadata_updater);
    stop_cheat_caller_address(contract_address);

    // Check that metadata_updater was updated
    assert!(
        dispatcher.metadata_updater() == new_metadata_updater,
        "Metadata Upgrader should be updated",
    );

    // Attempt to update metadata as old metadata updater
    start_cheat_caller_address(contract_address, metadata_updater);
    dispatcher.update_metadata("EURC", "EURC");
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Name must be non-empty',))]
fn test_update_metadata_rejects_invalid_name() {
    let (owner, metadata_updater, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let dispatcher = IMetadataDispatcher { contract_address };

    start_cheat_caller_address(contract_address, metadata_updater);
    dispatcher.update_metadata("", "EURC");
}

#[test]
#[should_panic(expected: ('Symbol must be non-empty',))]
fn test_update_metadata_rejects_invalid_symbol() {
    let (owner, metadata_updater, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let dispatcher = IMetadataDispatcher { contract_address };

    start_cheat_caller_address(contract_address, metadata_updater);
    dispatcher.update_metadata("EURC", "");
}

// ================================
// INTERNAL FUNCTIONS TESTS
// ================================

#[test]
fn test_initializer_functionality() {
    let (owner, metadata_updater, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let metadata_dispatcher = IMetadataDispatcher { contract_address };
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    // Initialize ownable first (required for metadata)
    test_dispatcher.test_ownable_initializer(owner);
    // Initialize metadata with metadata_updater
    test_dispatcher.test_metadata_initializer(metadata_updater, "USDC", "USDC", 6);

    // Check that metadata_updater is set and contract starts unpaused
    assert!(
        metadata_dispatcher.metadata_updater() == metadata_updater,
        "Initializer should set the metadata_updater",
    );
    assert!(metadata_dispatcher.name() == "USDC", "Name should be USDC");
    assert!(metadata_dispatcher.symbol() == "USDC", "Symbol should be USDC");
    assert!(metadata_dispatcher.decimals() == 6, "Decimals should be 6");
}

#[test]
#[should_panic(expected: ('Metadata updater cannot be zero',))]
fn test_initializer_rejects_zero_address() {
    let (owner, _, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    test_dispatcher.test_ownable_initializer(owner);
    let zero_address: ContractAddress = 0.try_into().unwrap();
    test_dispatcher.test_metadata_initializer(zero_address, "USDC", "USDC", 6);
}

#[test]
#[should_panic(expected: ('Contract already initialized',))]
fn test_initializer_rejects_already_initialized() {
    let (owner, metadata_updater, new_metadata_updater, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    test_dispatcher.test_ownable_initializer(owner);
    test_dispatcher.test_metadata_initializer(metadata_updater, "USDC", "USDC", 6);
    test_dispatcher.test_metadata_initializer(new_metadata_updater, "USDC", "USDC", 6);
}

#[test]
#[should_panic(expected: ('Name must be non-empty',))]
fn test_initializer_rejects_invalid_name() {
    let (owner, metadata_updater, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    test_dispatcher.test_ownable_initializer(owner);
    test_dispatcher.test_metadata_initializer(metadata_updater, "", "USDC", 6);
}

#[test]
#[should_panic(expected: ('Symbol must be non-empty',))]
fn test_initializer_rejects_invalid_symbol() {
    let (owner, metadata_updater, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    test_dispatcher.test_ownable_initializer(owner);
    test_dispatcher.test_metadata_initializer(metadata_updater, "USDC", "", 6);
}

#[test]
#[should_panic(expected: ('Decimals must be greater than 0',))]
fn test_initializer_rejects_invalid_decimals() {
    let (owner, metadata_updater, _, _) = get_test_addresses();
    let contract_address = deploy_uninitialized_contract();
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    test_dispatcher.test_ownable_initializer(owner);
    test_dispatcher.test_metadata_initializer(metadata_updater, "USDC", "USDC", 0);
}

#[test]
fn test_assert_only_metadata_updater_functionality() {
    let (owner, metadata_updater, _, _) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    // Should pass for metadata_updater
    start_cheat_caller_address(contract_address, metadata_updater);
    test_dispatcher.test_assert_only_metadata_updater();
}

#[test]
#[should_panic(expected: ('Caller is not metadata updater',))]
fn test_assert_only_metadata_updater_fails_for_non_metadata_updater() {
    let (owner, metadata_updater, _, unauthorized) = get_test_addresses();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let test_dispatcher = ITestHelperDispatcher { contract_address };

    start_cheat_caller_address(contract_address, unauthorized);
    test_dispatcher.test_assert_only_metadata_updater();
}
// ================================
// INTEGRATION WITH OWNABLE
// ================================

#[test]
fn test_metadata_operations_during_ownership_transfer() {
    let (owner, metadata_updater, new_metadata_updater, _) = get_test_addresses();
    let new_owner: ContractAddress = 'new_owner'.try_into().unwrap();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let ownable_dispatcher = IOwnableDispatcher { contract_address };
    let metadata_dispatcher = IMetadataDispatcher { contract_address };

    // Spy on events
    let mut spy = spy_events();

    // Initiate ownership transfer
    start_cheat_caller_address(contract_address, owner);
    ownable_dispatcher.transfer_ownership(new_owner);
    assert!(ownable_dispatcher.pending_owner() == new_owner, "Pending owner should be new_owner");
    stop_cheat_caller_address(contract_address);

    // Update metadata
    start_cheat_caller_address(contract_address, metadata_updater);
    metadata_dispatcher.update_metadata("EURC", "EURC");
    stop_cheat_caller_address(contract_address);
    assert!(metadata_dispatcher.name() == "EURC", "Name should be EURC");
    assert!(metadata_dispatcher.symbol() == "EURC", "Symbol should be EURC");
    assert!(metadata_dispatcher.decimals() == 6, "Decimals should be 6");

    // Update metadata updater
    start_cheat_caller_address(contract_address, owner);
    metadata_dispatcher.update_metadata_updater(new_metadata_updater);
    stop_cheat_caller_address(contract_address);
    assert!(
        metadata_dispatcher.metadata_updater() == new_metadata_updater,
        "Metadata updater should be updated",
    );

    // Accept ownership transfer
    start_cheat_caller_address(contract_address, new_owner);
    ownable_dispatcher.accept_ownership();
    stop_cheat_caller_address(contract_address);
    assert!(ownable_dispatcher.owner() == new_owner, "Owner should be new_owner");

    // Verify Metadata Updated event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MetadataComponent::Event::MetadataUpdated(
                        MetadataComponent::MetadataUpdated {
                            name: "EURC", symbol: "EURC", decimals: 6,
                        },
                    ),
                ),
                (
                    contract_address,
                    MetadataComponent::Event::MetadataUpgraderUpdated(
                        MetadataComponent::MetadataUpgraderUpdated {
                            old_metadata_updater: metadata_updater, new_metadata_updater,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_old_owner_cannot_update_metadata_updater_after_transfer() {
    let (owner, metadata_updater, new_metadata_updater, _) = get_test_addresses();
    let new_owner: ContractAddress = 'new_owner'.try_into().unwrap();
    let contract_address = deploy_mock_contract(owner, metadata_updater, "USDC", "USDC", 6);
    let ownable_dispatcher = IOwnableDispatcher { contract_address };
    let metadata_dispatcher = IMetadataDispatcher { contract_address };

    // Transfer ownership
    start_cheat_caller_address(contract_address, owner);
    ownable_dispatcher.transfer_ownership(new_owner);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, new_owner);
    ownable_dispatcher.accept_ownership();
    stop_cheat_caller_address(contract_address);

    // Old owner should not be able to update metadata_updater
    start_cheat_caller_address(contract_address, owner);
    metadata_dispatcher.update_metadata_updater(new_metadata_updater);
}
