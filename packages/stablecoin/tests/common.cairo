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

use components::blocklistable::IBlocklistableDispatcher;
use components::manageable::IManageableDispatcher;
use components::ownable::IOwnableDispatcher;
use components::pausable::IPausableDispatcher;
use components::upgradeable::IUpgradeableDispatcher;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use stablecoin::fiat_token::interface::IFiatTokenDispatcher;
use stablecoin::metadata::IMetadataDispatcher;
use stablecoin::minter_management::{IMinterManagementDispatcher, IMinterManagementDispatcherTrait};
use starknet::ContractAddress;

#[derive(Copy, Drop)]
pub struct ContractDispatchers {
    pub fiat_token_dispatcher: IFiatTokenDispatcher,
    pub ownable_dispatcher: IOwnableDispatcher,
    pub pausable_dispatcher: IPausableDispatcher,
    pub blocklistable_dispatcher: IBlocklistableDispatcher,
    pub minter_management_dispatcher: IMinterManagementDispatcher,
    pub metadata_dispatcher: IMetadataDispatcher,
    pub manageable_dispatcher: IManageableDispatcher,
    pub upgradeable_dispatcher: IUpgradeableDispatcher,
}

#[derive(Copy, Drop)]
pub struct ContractAddresses {
    pub admin: ContractAddress,
    pub burner: ContractAddress,
    pub controller_1: ContractAddress,
    pub controller_2: ContractAddress,
    pub master_minter: ContractAddress,
    pub minter: ContractAddress,
    pub owner: ContractAddress,
    pub pauser: ContractAddress,
    pub blocklister: ContractAddress,
    pub metadata_updater: ContractAddress,
    pub test_user: ContractAddress,
    pub spender: ContractAddress,
    pub recipient_1: ContractAddress,
    pub recipient_2: ContractAddress,
}

// Helper function to get constant contract addresses
pub fn get_contract_addresses() -> ContractAddresses {
    let admin: ContractAddress = 'admin'.try_into().unwrap();
    let burner: ContractAddress = 'burner'.try_into().unwrap();
    let controller_1: ContractAddress = 'controller_1'.try_into().unwrap();
    let controller_2: ContractAddress = 'controller_2'.try_into().unwrap();
    let master_minter: ContractAddress = 'master_minter'.try_into().unwrap();
    let minter: ContractAddress = 'minter'.try_into().unwrap();
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let pauser: ContractAddress = 'pauser'.try_into().unwrap();
    let blocklister: ContractAddress = 'blocklister'.try_into().unwrap();
    let metadata_updater: ContractAddress = 'metadata_updater'.try_into().unwrap();
    let test_user: ContractAddress = 'test_user'.try_into().unwrap();
    let spender: ContractAddress = 'spender'.try_into().unwrap();
    let recipient_1: ContractAddress = 'recipient_1'.try_into().unwrap();
    let recipient_2: ContractAddress = 'recipient_2'.try_into().unwrap();
    ContractAddresses {
        admin,
        burner,
        controller_1,
        controller_2,
        master_minter,
        minter,
        owner,
        pauser,
        blocklister,
        metadata_updater,
        test_user,
        spender,
        recipient_1,
        recipient_2,
    }
}

// Helper function to deploy FiatToken contract
pub fn deploy_fiat_token(
    contract_addresses: ContractAddresses,
) -> (ContractAddress, ContractDispatchers) {
    let contract = declare("FiatToken").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "USDC";
    let symbol: ByteArray = "USDC";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    constructor_calldata.append(6);
    constructor_calldata.append(contract_addresses.master_minter.into());
    constructor_calldata.append(contract_addresses.owner.into());
    constructor_calldata.append(contract_addresses.pauser.into());
    constructor_calldata.append(contract_addresses.blocklister.into());
    constructor_calldata.append(contract_addresses.metadata_updater.into());
    constructor_calldata.append(contract_addresses.admin.into());
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatchers = ContractDispatchers {
        fiat_token_dispatcher: IFiatTokenDispatcher { contract_address },
        ownable_dispatcher: IOwnableDispatcher { contract_address },
        pausable_dispatcher: IPausableDispatcher { contract_address },
        blocklistable_dispatcher: IBlocklistableDispatcher { contract_address },
        minter_management_dispatcher: IMinterManagementDispatcher { contract_address },
        metadata_dispatcher: IMetadataDispatcher { contract_address },
        manageable_dispatcher: IManageableDispatcher { contract_address },
        upgradeable_dispatcher: IUpgradeableDispatcher { contract_address },
    };
    (contract_address, dispatchers)
}

// Helper function to get zero address
pub fn get_zero_address() -> ContractAddress {
    let zero_address: ContractAddress = 0.try_into().unwrap();
    zero_address
}

// Helper function to deploy and initialize FiatToken contract with controller component
pub fn deploy_fiat_token_with_controller(
    addresses: ContractAddresses,
) -> (ContractAddress, ContractDispatchers) {
    let (contract_address, dispatchers) = deploy_fiat_token(addresses);

    // Configure controller-minter relationship
    start_cheat_caller_address(contract_address, addresses.master_minter);
    dispatchers
        .minter_management_dispatcher
        .configure_controller(addresses.controller_1, addresses.minter);
    dispatchers
        .minter_management_dispatcher
        .configure_controller(addresses.controller_2, addresses.burner);
    stop_cheat_caller_address(contract_address);

    // Configure minter with large allowance (controller action)
    start_cheat_caller_address(contract_address, addresses.controller_1);
    dispatchers
        .minter_management_dispatcher
        .configure_minter(1000000000); // Large allowance for testing
    stop_cheat_caller_address(contract_address);

    // Configure burner with 0 allowance (controller action)
    start_cheat_caller_address(contract_address, addresses.controller_2);
    dispatchers.minter_management_dispatcher.configure_minter(0);
    stop_cheat_caller_address(contract_address);

    (contract_address, dispatchers)
}
