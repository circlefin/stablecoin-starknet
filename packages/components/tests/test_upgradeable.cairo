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

use components::manageable::{IManageableDispatcher, IManageableDispatcherTrait};
use components::upgradeable::{
    IUpgradeableDispatcher, IUpgradeableDispatcherTrait, UpgradeableComponent,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ClassHash, ContractAddress};


fn deploy_test_contract(admin: ContractAddress) -> ContractAddress {
    let contract = declare("MockUpgradeableContract").unwrap().contract_class();
    let constructor_calldata = array![admin.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn get_test_addresses() -> (ContractAddress, ContractAddress, ContractAddress) {
    let admin: ContractAddress = 123.try_into().unwrap();
    let new_admin: ContractAddress = 456.try_into().unwrap();
    let unauthorized: ContractAddress = 789.try_into().unwrap();
    (admin, new_admin, unauthorized)
}

fn get_test_class_hash() -> ClassHash {
    let contract = declare("MockUpgradeableContract").unwrap().contract_class();
    contract.class_hash.clone()
}

// ================================
// UPGRADE FUNCTIONALITY TESTS
// ================================

#[test]
fn test_upgrade_with_admin() {
    let (admin, _, _) = get_test_addresses();
    let contract_address = deploy_test_contract(admin);
    let dispatcher = IUpgradeableDispatcher { contract_address };
    let new_class_hash = get_test_class_hash();

    // Spy on events
    let mut spy = spy_events();

    // Admin should be able to upgrade
    start_cheat_caller_address(contract_address, admin);
    dispatcher.upgrade(new_class_hash);
    stop_cheat_caller_address(contract_address);

    // Verify ContractUpgraded event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    UpgradeableComponent::Event::ContractUpgraded(
                        UpgradeableComponent::ContractUpgraded { class_hash: new_class_hash },
                    ),
                ),
            ],
        );
}

#[test]
fn test_multiple_upgrades() {
    let (admin, _, _) = get_test_addresses();
    let contract_address = deploy_test_contract(admin);
    let dispatcher = IUpgradeableDispatcher { contract_address };
    let class_hash = get_test_class_hash();

    // Spy on events
    let mut spy = spy_events();

    // Perform multiple upgrades
    start_cheat_caller_address(contract_address, admin);
    dispatcher.upgrade(class_hash);
    dispatcher.upgrade(class_hash);
    stop_cheat_caller_address(contract_address);

    // Verify both events were emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    UpgradeableComponent::Event::ContractUpgraded(
                        UpgradeableComponent::ContractUpgraded { class_hash: class_hash },
                    ),
                ),
                (
                    contract_address,
                    UpgradeableComponent::Event::ContractUpgraded(
                        UpgradeableComponent::ContractUpgraded { class_hash: class_hash },
                    ),
                ),
            ],
        );
}

// ================================
// ERROR HANDLING TESTS
// ================================

#[test]
#[should_panic(expected: ('Caller is not the admin',))]
fn test_upgrade_rejects_non_admin() {
    let (admin, _, unauthorized) = get_test_addresses();
    let contract_address = deploy_test_contract(admin);
    let dispatcher = IUpgradeableDispatcher { contract_address };
    let new_class_hash = get_test_class_hash();

    start_cheat_caller_address(contract_address, unauthorized);
    dispatcher.upgrade(new_class_hash);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Class hash cannot be zero',))]
fn test_upgrade_rejects_zero_class_hash() {
    let (admin, _, _) = get_test_addresses();
    let contract_address = deploy_test_contract(admin);
    let dispatcher = IUpgradeableDispatcher { contract_address };

    let zero_class_hash: ClassHash = 0.try_into().unwrap();
    start_cheat_caller_address(contract_address, admin);
    dispatcher.upgrade(zero_class_hash);
    stop_cheat_caller_address(contract_address);
}

// ================================
// ADMIN INTEGRATION TESTS
// ================================

#[test]
fn test_upgrade_during_admin_transfer() {
    let (admin, new_admin, _) = get_test_addresses();
    let contract_address = deploy_test_contract(admin);
    let upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
    let manageable_dispatcher = IManageableDispatcher { contract_address };
    let class_hash = get_test_class_hash();

    // Start admin transfer
    start_cheat_caller_address(contract_address, admin);
    manageable_dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    // Current admin should still be able to upgrade during pending transfer
    start_cheat_caller_address(contract_address, admin);
    upgrade_dispatcher.upgrade(class_hash);
    stop_cheat_caller_address(contract_address);

    // Verify admin state
    assert!(manageable_dispatcher.admin() == admin, "Admin should still be current");
    assert!(manageable_dispatcher.pending_admin() == new_admin, "Pending admin should be set");
}

#[test]
#[should_panic(expected: ('Caller is not the admin',))]
fn test_pending_admin_cannot_upgrade() {
    let (admin, new_admin, _) = get_test_addresses();
    let contract_address = deploy_test_contract(admin);
    let upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
    let manageable_dispatcher = IManageableDispatcher { contract_address };
    let class_hash = get_test_class_hash();

    // Start admin transfer
    start_cheat_caller_address(contract_address, admin);
    manageable_dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    // Pending admin should not be able to upgrade yet
    start_cheat_caller_address(contract_address, new_admin);
    upgrade_dispatcher.upgrade(class_hash);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_new_admin_can_upgrade_after_accepting() {
    let (admin, new_admin, _) = get_test_addresses();
    let contract_address = deploy_test_contract(admin);
    let upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
    let manageable_dispatcher = IManageableDispatcher { contract_address };
    let class_hash = get_test_class_hash();

    // Complete admin transfer
    start_cheat_caller_address(contract_address, admin);
    manageable_dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, new_admin);
    manageable_dispatcher.accept_admin();
    stop_cheat_caller_address(contract_address);

    // New admin should be able to upgrade
    start_cheat_caller_address(contract_address, new_admin);
    upgrade_dispatcher.upgrade(class_hash);
    stop_cheat_caller_address(contract_address);

    // Verify admin changed
    assert!(manageable_dispatcher.admin() == new_admin, "New admin should be current");
}

#[test]
#[should_panic(expected: ('Caller is not the admin',))]
fn test_old_admin_cannot_upgrade_after_transfer() {
    let (admin, new_admin, _) = get_test_addresses();
    let contract_address = deploy_test_contract(admin);
    let upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
    let manageable_dispatcher = IManageableDispatcher { contract_address };
    let class_hash = get_test_class_hash();

    // Complete admin transfer
    start_cheat_caller_address(contract_address, admin);
    manageable_dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, new_admin);
    manageable_dispatcher.accept_admin();
    stop_cheat_caller_address(contract_address);

    // Old admin should no longer be able to upgrade
    start_cheat_caller_address(contract_address, admin);
    upgrade_dispatcher.upgrade(class_hash);
    stop_cheat_caller_address(contract_address);
}
