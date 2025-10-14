# Components Library

This library provides reusable smart contract components for Starknet applications. Each component implements specific functionality that can be composed together to build secure and feature-rich smart contracts.

## Available Components

| Component                                        | Description                                                   | Dependencies |
| ------------------------------------------------ | ------------------------------------------------------------- | ------------ |
| **[Blocklistable](src/blocklistable/README.md)** | Address blocking/unblocking functionality for compliance      | Ownable      |
| **[Denylistable](src/denylistable/README.md)**   | Address denying/allowing functionality for compliance         | Ownable      |
| **[Manageable](src/manageable/README.md)**       | Two-step admin transfer mechanism for secure admin management | None         |
| **[Ownable](src/ownable/README.md)**             | Two-step ownership transfer mechanism for secure ownership    | None         |
| **[Pausable](src/pausable/README.md)**           | Emergency pause/unpause functionality for circuit breakers    | Ownable      |
| **[Upgradeable](src/upgradeable/README.md)**     | Contract upgrade functionality with admin controls            | Manageable   |

## Component Architecture

The Components Library follows a modular architecture where each component encapsulates a specific piece of functionality that can be easily integrated into smart contracts. Components are designed to work together seamlessly while maintaining clean separation of concerns.

### Unified Structure

All components follow a consistent, modular structure for better maintainability and developer experience:

```
src/[component]/
├── README.md             # Component documentation and usage examples
├── [component].cairo     # Main component implementation
├── events.cairo          # Event struct definitions
├── errors.cairo          # Error constants
└── interface.cairo       # Component trait definition
```

## Security Considerations

- Always use two-step transfers for critical role changes
- Implement proper access controls for administrative functions
- Consider pause mechanisms for emergency situations
- Use blocklists/denylists for compliance requirements
- Ensure upgrade mechanisms are properly secured

## Contributing

When adding new components:

1. Follow the unified structure pattern
2. Include comprehensive documentation in README.md
3. Implement proper error handling and events
4. Add thorough test coverage
5. Consider security implications and access controls
