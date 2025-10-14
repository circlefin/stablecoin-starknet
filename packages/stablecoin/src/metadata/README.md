<!--
 Copyright 2025 Circle Internet Group, Inc. All rights reserved.

 SPDX-License-Identifier: Apache-2.0

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-->

# Metadata Component

This component provides metadata functionality allowing authorized users
to update the metadata of the fiat token. The component integrates with the
Ownable component to control metadata updater role management.

# Examples

```
#[starknet::contract]
mod MyContract {
    use components::ownable::OwnableComponent;
    use stablecoin::metadata::MetadataComponent;

    component!(path: MetadataComponent, storage: metadata, event: MetadataEvent);
    impl MetadataImpl = MetadataComponent::Metadata<ContractState>;

    #[external(v0)]
    fn update_metadata(ref self: ContractState, name: ByteArray, symbol: ByteArray) {
        self.metadata.assert_only_metadata_updater();
        // Update logic
    }
}
```
