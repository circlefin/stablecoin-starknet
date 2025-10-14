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

/// Emitted when the metadata is updated
#[derive(Drop, starknet::Event)]
pub struct MetadataUpdated {
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub decimals: u8,
}

/// Emitted when the metadata updater is updated
#[derive(Drop, starknet::Event)]
pub struct MetadataUpgraderUpdated {
    #[key]
    pub old_metadata_updater: starknet::ContractAddress,
    #[key]
    pub new_metadata_updater: starknet::ContractAddress,
}
