# stablecoin-starknet

Source repository for smart contracts used by Circle's stablecoins on Starknet blockchain

## Getting Started

### Prerequisites

Before you can start working with the contracts in this repository, make sure to setup your local environment using the script below.

```
make setup
```

### IDE Configuration

The recommended IDE for this repository is VSCode. To set up your IDE:

1. Install the recommended extensions in VSCode
2. Enter `@recommended` into the search bar in the Extensions panel
3. Install each of the recommended extensions

### Build and Test Contracts

1. Compile Cairo contracts from the project root (see [Build Profiles](#build-profiles) for details):

```
scarb build
```

2. Run the tests:

```
make test-forge
```

### Generate Test Coverage Report

To generate a comprehensive test coverage report:

```bash
make coverage
```

## Project Structure

- `packages/` - Cairo smart contracts
  - `stablecoin/` - Main stablecoin contract implementation
  - `components/` - Reusable contract components
  - `mock_contracts/` - Mock contracts used within unit tests
- `scripts/` - Utility scripts

## Build Profiles

The project supports different build profiles for different environments:

- **Dev build** (`scarb build`): Generates unoptimized contracts in `target/dev/`
- **Release build** (`scarb --release build`): Generates optimized contracts in `target/release/`

Use the appropriate profile based on your testing needs:

- Use `dev` profile for local testing and development
- Use `release` profile for production deployments and final testing
