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

// Re-export all mock contracts
pub mod mock_blocklistable_contract;
pub mod mock_denylistable_contract;
pub mod mock_fiat_token;
pub mod mock_manageable_contract;
pub mod mock_ownable_contract;
pub mod mock_pausable_contract;
pub mod mock_upgradeable_contract;
pub use mock_blocklistable_contract::{
    IMockBlocklistableContract, IMockBlocklistableContractDispatcher,
    IMockBlocklistableContractDispatcherTrait,
};
pub use mock_denylistable_contract::{
    IMockDenylistableContract, IMockDenylistableContractDispatcher,
    IMockDenylistableContractDispatcherTrait,
};
// Re-export main interfaces
pub use mock_fiat_token::{IMockFiatToken, IMockFiatTokenDispatcher, IMockFiatTokenDispatcherTrait};
pub use mock_manageable_contract::{
    IMockManageableContract, IMockManageableContractDispatcher,
    IMockManageableContractDispatcherTrait,
};

// Re-export component mock test helper interfaces and dispatchers
pub use mock_ownable_contract::{
    IMockOwnableContract, IMockOwnableContractDispatcher, IMockOwnableContractDispatcherTrait,
};
pub use mock_pausable_contract::{
    IMockPausableContract, IMockPausableContractDispatcher, IMockPausableContractDispatcherTrait,
};
