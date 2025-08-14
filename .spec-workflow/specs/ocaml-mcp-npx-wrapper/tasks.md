# Implementation Plan

## Task Overview

Implement the OCaml MCP NPX wrapper following Test-Driven Development (TDD) principles. Each task represents an atomic, testable unit of work that builds incrementally toward the complete solution. Tasks follow the red-green-refactor cycle: write failing tests first, then implement minimal code to pass, then refactor for quality.

## Tasks

### Phase 1: Project Setup and Test Infrastructure

- [x] 1. Initialize NPX wrapper package structure
  - File: npx-wrapper/package.json
  - Create package.json with name "@ocaml-mcp/server", version "0.1.0", and bin entry point
  - Set up minimal package metadata and Node.js engine requirements (>=14.0.0)
  - Purpose: Establish NPM package foundation with proper naming and structure
  - _Requirements: 1.1_

- [x] 2. Set up Jest testing framework and configuration
  - Files: npx-wrapper/jest.config.js, npx-wrapper/.eslintrc.js
  - Configure Jest for Node.js testing with coverage thresholds (90%)
  - Set up ESLint and Prettier for code quality
  - Purpose: Enable TDD with comprehensive test coverage tracking
  - _Requirements: Non-Functional - Testing Requirements_

- [x] 3. Create main entry point scaffold
  - File: npx-wrapper/bin/ocaml-mcp-server.js
  - Create executable script with shebang and basic structure
  - Set up async main function for orchestration
  - Purpose: Establish entry point for NPX execution
  - _Requirements: 1.1_

### Phase 2: TDD Implementation - Argument Parser

- [x] 4. Write failing tests for argument parser module
  - File: npx-wrapper/lib/__tests__/argument-parser.test.js
  - Test extraction of --repo parameter with various positions
  - Test detection of --print-config flag
  - Test forwarding of remaining arguments unchanged
  - Purpose: Define argument parsing behavior through tests
  - _Requirements: 3.1, 3.3, 4.1_

- [x] 5. Implement argument parser to pass tests
  - File: npx-wrapper/lib/argument-parser.js
  - Implement parseArgs function to extract wrapper-specific arguments
  - Handle --repo URL extraction and --print-config detection
  - Return parsed arguments object with repoUrl, printConfig, and serverArgs
  - Purpose: Parse command-line arguments for wrapper logic
  - _Requirements: 3.1, 3.3, 4.1_

### Phase 3: TDD Implementation - Project Detector

- [x] 6. Write failing tests for OCaml project detection
  - File: npx-wrapper/lib/__tests__/project-detector.test.js
  - Test detection of dune-project files
  - Test detection of *.opam files
  - Test failure when no OCaml markers present
  - Test opam availability checking
  - Purpose: Define project validation behavior through tests
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 7. Implement project detector to pass tests
  - File: npx-wrapper/lib/project-detector.js
  - Implement detectProject function to find OCaml project markers
  - Implement validateEnvironment to check opam availability
  - Return success/failure with appropriate error messages
  - Purpose: Validate OCaml project context before proceeding
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

### Phase 4: TDD Implementation - Opam Manager

- [x] 8. Write failing tests for opam installation management
  - File: npx-wrapper/lib/__tests__/opam-manager.test.js
  - Test checking if ocaml-mcp-server is installed
  - Test installation via opam pin with default repository
  - Test installation with custom repository URL
  - Test handling of installation failures
  - Purpose: Define opam integration behavior through tests
  - _Requirements: 1.2, 3.1, 3.2_

- [x] 9. Implement opam manager to pass tests
  - File: npx-wrapper/lib/opam-manager.js
  - Implement isServerInstalled using opam list or which
  - Implement installServer using opam pin add command
  - Handle silent installation with error capture
  - Purpose: Manage ocaml-mcp-server installation via opam
  - _Requirements: 1.2, 1.3, 3.1, 3.2_

### Phase 5: TDD Implementation - Binary Executor

- [x] 10. Write failing tests for binary execution
  - File: npx-wrapper/lib/__tests__/binary-executor.test.js
  - Test execution via opam exec with argument forwarding
  - Test exit code preservation
  - Test stdio stream inheritance
  - Test signal propagation (SIGINT/SIGTERM)
  - Purpose: Define process delegation behavior through tests
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [x] 11. Implement binary executor to pass tests
  - File: npx-wrapper/lib/binary-executor.js
  - Implement executeServer using child_process.spawn
  - Use opam exec -- ocaml-mcp-server for proper environment
  - Set stdio: 'inherit' for stream pass-through
  - Handle process exit and signal forwarding
  - Purpose: Delegate execution to actual ocaml-mcp-server binary
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

### Phase 6: TDD Implementation - Config Generator

- [x] 12. Write failing tests for MCP configuration generation
  - File: npx-wrapper/lib/__tests__/config-generator.test.js
  - Test generation of valid MCP JSON structure
  - Test inclusion of workspace folder variables
  - Test optional --repo parameter in generated config
  - Purpose: Define configuration output format through tests
  - _Requirements: 4.1, 4.3, 4.4_

- [x] 13. Implement config generator to pass tests
  - File: npx-wrapper/lib/config-generator.js
  - Implement generateConfig function returning MCP JSON
  - Include proper NPX command structure
  - Support optional repository URL in arguments
  - Purpose: Generate MCP client configuration for AI tools
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

### Phase 7: TDD Implementation - Error Handler

- [x] 14. Write failing tests for error handling
  - File: npx-wrapper/lib/__tests__/error-handler.test.js
  - Test error message formatting for different error types
  - Test actionable suggestions for common failures
  - Test preservation of original error details
  - Purpose: Define error handling behavior through tests
  - _Requirements: 6.1, 6.2_

- [x] 15. Implement error handler to pass tests
  - File: npx-wrapper/lib/error-handler.js
  - Implement handleError with consistent message format
  - Provide platform-specific installation instructions
  - Include manual fallback commands for failures
  - Purpose: Provide clear, actionable error messages to users
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

### Phase 8: Integration - Main Orchestration

- [x] 16. Write integration tests for complete workflows
  - File: npx-wrapper/__tests__/integration.test.js
  - Test fresh installation workflow end-to-end
  - Test subsequent execution with cached installation
  - Test configuration generation workflow
  - Test error scenarios with proper error messages
  - Purpose: Validate complete user workflows work correctly
  - _Requirements: 1.1, 1.4, 1.5_

- [x] 17. Wire components together in main entry point
  - File: npx-wrapper/bin/ocaml-mcp-server.js
  - Import all component modules
  - Implement orchestration logic following design flow
  - Handle --print-config early exit
  - Coordinate installation check and execution
  - Purpose: Connect all components into working NPX wrapper
  - _Leverage: All components from tasks 5, 7, 9, 11, 13, 15_
  - _Requirements: All functional requirements_

### Phase 9: Cross-Platform Testing

- [x] 18. Test on macOS with real OCaml projects
  - Environment: macOS with opam installed
  - Test installation from official repository
  - Test execution with various server arguments
  - Verify MCP protocol communication works
  - Purpose: Validate macOS compatibility
  - _Requirements: Non-Functional - Compatibility_

- [ ] 19. Test on Linux with real OCaml projects
  - Environment: Ubuntu/Debian with opam installed
  - Test installation and execution workflows
  - Test custom repository installation
  - Verify signal handling works correctly
  - Purpose: Validate Linux compatibility
  - _Requirements: Non-Functional - Compatibility_

### Phase 10: Documentation and Publishing

- [x] 20. Create comprehensive README documentation
  - File: npx-wrapper/README.md
  - Document installation via NPX
  - Provide usage examples for all features
  - Include troubleshooting section
  - Add MCP client configuration examples
  - Purpose: Enable users to successfully use the wrapper
  - _Requirements: Non-Functional - Usability_

- [x] 21. Prepare package for NPM publishing
  - Files: npx-wrapper/.npmignore, npx-wrapper/LICENSE
  - Add appropriate .npmignore to exclude tests and dev files
  - Ensure LICENSE file is included
  - Verify package.json metadata is complete
  - Test local installation with npm pack
  - Purpose: Prepare for NPM registry publication
  - _Requirements: 1.1_

## Task Dependencies

- Tasks 1-3 must complete before any implementation begins (setup)
- Tasks 4-5, 6-7, 8-9, 10-11, 12-13, 14-15 are paired TDD cycles (test then implement)
- Task 17 requires tasks 5, 7, 9, 11, 13, 15 to be complete (integration)
- Tasks 18-19 require task 17 to be complete (platform testing)
- Tasks 20-21 can proceed after task 17 (documentation)

## Success Criteria

- All unit tests pass with 90%+ code coverage
- Integration tests validate complete workflows
- Platform testing confirms cross-platform compatibility (macOS and Linux)
- NPX command works with zero configuration
- Documentation enables successful user adoption