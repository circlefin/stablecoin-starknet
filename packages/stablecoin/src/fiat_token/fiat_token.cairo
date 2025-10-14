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

#[starknet::contract]
pub mod FiatToken {
    use components::blocklistable::BlocklistableComponent;
    use components::manageable::ManageableComponent;
    use components::ownable::OwnableComponent;
    use components::pausable::PausableComponent;
    use components::upgradeable::UpgradeableComponent;
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::fiat_token::errors::Errors;
    // Re-export events for external access
    pub use crate::fiat_token::events::{Approval, Burn, FiatTokenInitialized, Mint, Transfer};
    use crate::fiat_token::interface::IFiatToken;
    use crate::metadata::MetadataComponent;
    use crate::minter_management::MinterManagementComponent;

    component!(path: BlocklistableComponent, storage: blocklistable, event: BlocklistableEvent);
    component!(
        path: MinterManagementComponent, storage: minter_management, event: MinterManagementEvent,
    );
    component!(path: ManageableComponent, storage: manageable, event: ManageableEvent);
    component!(path: MetadataComponent, storage: metadata, event: MetadataEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl BlocklistableImpl = BlocklistableComponent::Blocklistable<ContractState>;
    impl BlocklistableInternalImpl = BlocklistableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl MinterManagementImpl =
        MinterManagementComponent::MinterManagement<ContractState>;
    impl MinterManagementInternalImpl = MinterManagementComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ManageableImpl = ManageableComponent::Manageable<ContractState>;
    impl ManageableInternalImpl = ManageableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl MetadataImpl = MetadataComponent::Metadata<ContractState>;
    impl MetadataInternalImpl = MetadataComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::Ownable<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::Pausable<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl UpgradeableImpl = UpgradeableComponent::Upgradeable<ContractState>;

    #[storage]
    struct Storage {
        // === CORE TOKEN DATA ===
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowed: Map<(ContractAddress, ContractAddress), u256>,
        // === OWNERSHIP & ACCESS CONTROL ===
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        manageable: ManageableComponent::Storage,
        // === OPERATIONAL CONTROLS ===
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        blocklistable: BlocklistableComponent::Storage,
        // === TOKEN METADATA ===
        #[substorage(v0)]
        metadata: MetadataComponent::Storage,
        // === MINTING FUNCTIONALITY ===
        #[substorage(v0)]
        minter_management: MinterManagementComponent::Storage,
        // === UPGRADE MECHANISM ===
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // === VERSION TRACKING ===
        initialized_version: u8,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        BlocklistableEvent: BlocklistableComponent::Event,
        #[flat]
        MinterManagementEvent: MinterManagementComponent::Event,
        #[flat]
        ManageableEvent: ManageableComponent::Event,
        #[flat]
        MetadataEvent: MetadataComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        FiatTokenInitialized: FiatTokenInitialized,
        Mint: Mint,
        Burn: Burn,
        Transfer: Transfer,
        Approval: Approval,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        master_minter: ContractAddress,
        owner: ContractAddress,
        pauser: ContractAddress,
        blocklister: ContractAddress,
        metadata_updater: ContractAddress,
        admin: ContractAddress,
    ) {
        self.minter_management.initializer(master_minter);
        self.ownable.initializer(owner);
        self.pausable.initializer(pauser);
        self.blocklistable.initializer(blocklister);
        self.metadata.initializer(metadata_updater, name, symbol, decimals);
        self.manageable.initializer(admin);
        self.initialized_version.write(1);
        self.blocklistable._blocklist(get_contract_address());
        self.emit(FiatTokenInitialized { initialized_version: 1 });
    }

    #[abi(embed_v0)]
    impl FiatTokenImpl of IFiatToken<ContractState> {
        /// Returns the initialized version of the fiat token
        ///
        /// # Returns
        ///
        /// * The initialized version
        fn version(self: @ContractState) -> u8 {
            self.initialized_version.read()
        }

        /// Returns the total supply of the fiat token
        ///
        /// # Returns
        ///
        /// * The total supply
        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        /// Returns the total supply of the fiat token
        /// Implemented for backwards compatibility with older versions of SNIP-2:
        /// https://github.com/starknet-io/SNIPs/blob/main/SNIPS/snip-2.md#backwards-compatibility
        ///
        /// # Returns
        ///
        /// * The total supply
        fn totalSupply(self: @ContractState) -> u256 {
            self.total_supply()
        }

        /// Returns the balance of an account
        ///
        /// # Arguments
        ///
        /// * `account` - The account's address
        ///
        /// # Returns
        ///
        /// * The balance for the account
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        /// Returns the balance of an account
        /// Implemented for backwards compatibility with older versions of SNIP-2:
        /// https://github.com/starknet-io/SNIPs/blob/main/SNIPS/snip-2.md#backwards-compatibility
        ///
        /// # Arguments
        ///
        /// * `account` - The account's address
        ///
        /// # Returns
        ///
        /// * The balance for the account
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.balance_of(account)
        }

        /// Gets the remaining amount of fiat tokens that a spender is allowed to spend on behalf of
        /// the token owner
        ///
        /// # Arguments
        ///
        /// * `owner` - The token owner's address
        /// * `spender` - The address authorized to spend tokens
        ///
        /// # Returns
        ///
        /// * The remaining allowance
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.allowed.read((owner, spender))
        }

        /// Mints new fiat tokens. The caller must be a minter.
        ///
        /// # Arguments
        ///
        /// * `to` - The address to mint tokens to
        /// * `amount` - The amount of tokens to mint
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.pausable.assert_not_paused();
            self.blocklistable.assert_not_blocklisted(get_caller_address());
            self.blocklistable.assert_not_blocklisted(to);
            self.minter_management.assert_only_minters();

            self._mint(get_caller_address(), to, amount);
        }

        /// Burns fiat tokens from the calling address. The caller must be a minter.
        ///
        /// # Arguments
        ///
        /// * `amount` - The amount of tokens to burn
        fn burn(ref self: ContractState, amount: u256) {
            self.pausable.assert_not_paused();

            let burner = get_caller_address();
            self.blocklistable.assert_not_blocklisted(burner);
            self.minter_management.assert_only_minters();

            self._burn(burner, amount);
        }

        /// Transfers tokens from the caller to a specified address
        ///
        /// # Arguments
        ///
        /// * `to` - The payee's address
        /// * `amount` - The amount of tokens to transfer
        ///
        /// # Returns
        ///
        /// * `true` if the transfer is successful, `false` otherwise
        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            self.pausable.assert_not_paused();

            let spender = get_caller_address();
            self.blocklistable.assert_not_blocklisted(spender);
            self.blocklistable.assert_not_blocklisted(to);

            self._transfer(spender, to, amount)
        }

        /// Transfers tokens from one address to another by calling the spender's allowance
        ///
        /// # Arguments
        ///
        /// * `from` - The payer's address
        /// * `to` - The payee's address
        /// * `amount` - The amount of tokens to transfer
        ///
        /// # Returns
        ///
        /// * `true` if the transfer is successful, `false` otherwise
        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            self.pausable.assert_not_paused();

            let spender = get_caller_address();
            self.blocklistable.assert_not_blocklisted(spender);
            self.blocklistable.assert_not_blocklisted(from);
            self.blocklistable.assert_not_blocklisted(to);

            self._transfer_from(spender, from, to, amount)
        }

        /// Transfers tokens from one address to another by calling the spender's allowance
        /// Implemented for backwards compatibility with older versions of SNIP-2:
        /// https://github.com/starknet-io/SNIPs/blob/main/SNIPS/snip-2.md#backwards-compatibility
        ///
        /// # Arguments
        ///
        /// * `from` - The payer's address
        /// * `to` - The payee's address
        /// * `amount` - The amount of tokens to transfer
        ///
        /// # Returns
        ///
        /// * `true` if the transfer is successful, `false` otherwise
        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            self.transfer_from(from, to, amount)
        }

        /// Approves a spender to spend a specified amount of tokens on behalf of the caller
        ///
        /// # Arguments
        ///
        /// * `spender` - The address authorized to spend tokens
        /// * `amount` - The maximum amount of tokens the spender is allowed to spend
        ///
        /// # Returns
        ///
        /// * `true` if the approval is successful, `false` otherwise
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.pausable.assert_not_paused();

            let owner = get_caller_address();
            self._approve(owner, spender, amount)
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        /// Internal function to mint tokens
        ///
        /// # Arguments
        ///
        /// * `minter` - The address minting the tokens
        /// * `to` - The address receiving the tokens
        /// * `amount` - The amount of tokens to mint
        fn _mint(
            ref self: ContractState, minter: ContractAddress, to: ContractAddress, amount: u256,
        ) {
            assert(!to.is_zero(), Errors::ZERO_TO_ADDRESS);
            assert(amount > 0, Errors::MINT_AMOUNT_NOT_GREATER_THAN_ZERO);
            assert(
                amount <= self.minter_management.minter_allowance(minter),
                Errors::MINT_AMOUNT_EXCEEDS_ALLOWANCE,
            );

            // Update total supply
            self.total_supply.write(self.total_supply.read() + amount);

            // Update recipient balance
            self.balances.write(to, self.balances.read(to) + amount);

            // Decrease minter allowance
            self.minter_management.decrement_minter_allowance(minter, amount);

            // Emit mint event
            self.emit(Mint { minter, to, amount });

            // Emit Transfer event from zero address (standard ERC20 mint pattern)
            self.emit(Transfer { from: Zero::zero(), to, value: amount });
        }

        /// Internal function to burn tokens
        ///
        /// # Arguments
        ///
        /// * `burner` - The address burning the tokens
        /// * `amount` - The amount of tokens to burn
        fn _burn(ref self: ContractState, burner: ContractAddress, amount: u256) {
            assert(amount > 0, Errors::BURN_AMOUNT_NOT_GREATER_THAN_ZERO);

            let balance = self.balances.read(burner);
            assert(amount <= balance, Errors::BURN_AMOUNT_EXCEEDS_BALANCE);

            // Update total supply
            self.total_supply.write(self.total_supply.read() - amount);

            // Update burner balance
            self.balances.write(burner, balance - amount);

            // Emit burn event
            self.emit(Burn { burner, amount });

            // Emit Transfer event to zero address (standard ERC20 burn pattern)
            self.emit(Transfer { from: burner, to: Zero::zero(), value: amount });
        }

        /// Internal function to transfer tokens from one address to another
        ///
        /// # Arguments
        ///
        /// * `from` - The payer's address
        /// * `to` - The payee's address
        /// * `amount` - The amount of tokens to transfer
        ///
        /// # Returns
        ///
        /// * `true` if the transfer is successful, `false` otherwise
        fn _transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            assert(!from.is_zero(), Errors::ZERO_FROM_ADDRESS);
            assert(!to.is_zero(), Errors::ZERO_TO_ADDRESS);

            let from_balance = self.balances.read(from);
            assert(amount <= from_balance, Errors::TRANSFER_AMOUNT_EXCEEDS_BALANCE);

            // Update account balances
            self.balances.write(from, from_balance - amount);
            self.balances.write(to, self.balances.read(to) + amount);

            // Emit transfer event
            self.emit(Transfer { from, to, value: amount });

            true
        }

        /// Internal function to transfer tokens from one address to another by calling the
        /// spender's allowance
        ///
        /// # Arguments
        ///
        /// * `spender` - The address authorized to spend tokens
        /// * `from` - The payer's address
        /// * `to` - The payee's address
        /// * `amount` - The amount of tokens to transfer
        ///
        /// # Returns
        ///
        /// * `true` if the transfer is successful, `false` otherwise
        fn _transfer_from(
            ref self: ContractState,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
        ) -> bool {
            let current_allowance = self.allowed.read((from, spender));
            assert(amount <= current_allowance, Errors::TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE);

            // Execute transfer
            self._transfer(from, to, amount);

            // Decrease the allowance
            self.allowed.write((from, spender), current_allowance - amount);

            true
        }

        /// Internal function to set an allowance for a spender to spend a specified amount of
        /// tokens on behalf of the caller
        ///
        /// # Arguments
        ///
        /// * `owner` - The token owner's address
        /// * `spender` - The address authorized to spend tokens
        /// * `amount` - The maximum amount of tokens the spender is allowed to spend
        ///
        /// # Returns
        ///
        /// * `true` if the approval is successful, `false` otherwise
        fn _approve(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256,
        ) -> bool {
            assert(!owner.is_zero(), Errors::ZERO_FROM_ADDRESS);
            assert(!spender.is_zero(), Errors::ZERO_TO_ADDRESS);

            // Set the allowance
            self.allowed.write((owner, spender), amount);

            // Emit approval event
            self.emit(Approval { owner, spender, value: amount });

            true
        }
    }
}
