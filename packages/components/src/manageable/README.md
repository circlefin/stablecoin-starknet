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

# Manageable Component

This component provides admin management functionality with a two-step
admin transfer mechanism. It allows secure admin role management with
a propose-and-accept pattern to prevent accidental admin transfers.

# Examples

```
#[starknet::contract]
mod MyContract {
    use components::manageable::ManageableComponent;

    component!(path: ManageableComponent, storage: manageable, event: ManageableEvent);
    impl ManageableImpl = ManageableComponent::Manageable<ContractState>;

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.manageable.initializer(admin);
    }
}
```
