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

# Ownable Component

This component provides basic ownership functionality with a two-step ownership transfer
mechanism for enhanced security. The component ensures that ownership transfers are
intentional by requiring the new owner to accept the transfer.

# Examples

```
#[starknet::contract]
mod MyContract {
    use components::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    impl OwnableImpl = OwnableComponent::Ownable<ContractState>;

    #[external(v0)]
    fn initialize(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }
}
```
