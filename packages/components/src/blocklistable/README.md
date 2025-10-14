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

# Blocklistable Component

This component provides Blocklist functionality allowing authorized users to
block specific addresses from interacting with the contract. This is essential
for compliance and security purposes in financial applications.

# Examples

```
#[starknet::contract]
mod MyContract {
    use components::blocklistable::BlocklistableComponent;
    use components::ownable::OwnableComponent;

    component!(path: BlocklistableComponent, storage: blocklistable, event: BlocklistableEvent);
    impl BlocklistableImpl = BlocklistableComponent::Blocklistable<ContractState>;

    #[external(v0)]
    fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) {
        self.blocklistable.assert_not_blocklisted(get_caller_address());
        // Transfer logic here
    }
}
```
