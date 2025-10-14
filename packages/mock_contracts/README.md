# Mock Contract Package

This package contains the `MockFiatToken` contract for testing stablecoin functionality.

## Contracts

### MockFiatToken

A mock implementation of the FiatToken contract that extends the original functionality with additional testing features:

- All original FiatToken functions
- Additional mock functions for testing upgrades:
  - `get_version()` - Returns a version number for upgrade testing
  - `mock_storage_value()` - Returns a test storage value
  - `set_mock_storage_value(value)` - Sets a test storage value

## Building

```bash
# Build dev version (with debug info)
scarb build --package mock_contract

# Build optimized release version
scarb -P release build --package mock_contract
```

## Generated Files

The package generates both Sierra and CASM files:

- **Sierra file**: `target/dev/mock_contract_MockFiatToken.contract_class.json` (6.4MB dev, ~650KB release)
- **CASM file**: `target/dev/mock_contract_MockFiatToken.compiled_contract_class.json` (461KB dev, ~700KB release)

## Usage in Tests

Import the mock contract in your test files:

```cairo
use mock_contract::{IMockFiatTokenDispatcher, IMockFiatTokenDispatcherTrait};

// In your test
let mock_class = declare("MockFiatToken").unwrap().contract_class();
let mock_dispatcher = IMockFiatTokenDispatcher { contract_address };
```

## Class Hash

- **Dev build**: `0x4675037e57e891432be3a977aeea155b44e0bc5409caf4ec80da5729b8e6b0e`
- **Release build**: Different hash due to optimizations

## Purpose

This package was created to enable proper deployment capabilities for mock contracts while maintaining clean separation from the main stablecoin contracts. By having mock contracts in their own package, they can generate both Sierra and CASM files, making them suitable for actual deployment and comprehensive testing scenarios.
