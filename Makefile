# Copyright 2025 Circle Internet Group, Inc. All rights reserved.
# 
# SPDX-License-Identifier: Apache-2.0
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

setup:
	@bash scripts/shell/setup.sh

start-network: stop-network
	@bash scripts/shell/start_network.sh

stop-network:
	@bash scripts/shell/stop_network.sh

test-forge:
	@echo "Running Starknet Foundry tests..."
	@if command -v snforge >/dev/null 2>&1; then \
		echo "Found snforge, running tests..."; \
		snforge test -w; \
	else \
		echo "ERROR: snforge command not found in PATH"; \
		exit 1; \
	fi

coverage:
	@echo "Running coverage..."
	@bash scripts/shell/coverage.sh

.PHONY: setup start-network stop-network test-forge coverage
