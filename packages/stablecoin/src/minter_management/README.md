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

# Minter Management Component

This component provides a hierarchical minting control system for managing token minting
operations. It implements a three-tier architecture:

1. **Owner**: Can update the master minter
2. **Master Minter**: Can configure and remove controllers
3. **Controllers**: Can configure, remove, and manage their assigned minters
4. **Minters**: Can mint tokens up to their allowance

The component integrates with the Ownable component to control master minter role management.

## Architecture

```
Owner
  └── Master Minter
      └── Controller 1 ──── Minter A (allowance: 1000)
      └── Controller 2 ──── Minter B (allowance: 2000)
      └── Controller 3 ──── Minter C (allowance: 500)
```

One minter can have many controllers, while a controller can only control one minter.

## Examples

```
#[starknet::contract]
mod MyContract {
    use stablecoin::minter_management::MinterManagementComponent;
    use components::ownable::OwnableComponent;

    component!(path: MinterManagementComponent, storage: minter_management, event: MinterManagementEvent);
    impl MinterManagementImpl = MinterManagementComponent::MinterManagement<ContractState>;

    #[external(v0)]
    fn setup_minting(ref self: ContractState, controller: ContractAddress, minter: ContractAddress) {
        self.minter_management.configure_controller(controller, minter);
    }
}
```
