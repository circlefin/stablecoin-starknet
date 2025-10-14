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

# Upgradeable Component

This component provides contract upgradeability functionality with admin access control.
It integrates with the Manageable component to control admin role management.

# Examples

```
#[starknet::contract]
mod MyContract {
    use components::upgradeable::UpgradeableComponent;
    use components::manageable::ManageableComponent;

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: ManageableComponent, storage: manageable, event: ManageableEvent);

    impl UpgradeableImpl = UpgradeableComponent::Upgradeable<ContractState>;
    impl ManageableImpl = ManageableComponent::Upgradeable<ContractState>;

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.manageable.initializer(admin);
    }

    #[external(v0)]
    fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
        self.upgradeable.upgrade(new_class_hash);
    }
}
```
