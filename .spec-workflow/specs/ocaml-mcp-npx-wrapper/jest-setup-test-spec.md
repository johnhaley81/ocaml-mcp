# Test Specification: Jest Testing Framework Setup (Task 2)

## Overview

This specification defines the comprehensive test strategy for setting up Jest testing framework and configuration for the OCaml MCP NPX wrapper. The test setup must support Test-Driven Development (TDD) with failing tests written BEFORE implementation, extensive mocking capabilities, and strict coverage requirements.

## Requirements Coverage

### Primary Requirement Coverage
- **Non-Functional Requirement - Testing Requirements**: Unit test coverage minimum 90% for all modules
- **Non-Functional Requirement - Code Architecture**: Modular design with independently testable components
- **Non-Functional Requirement - Reliability**: Test all error scenarios and edge cases

### Functional Requirement Coverage (Future Tests Will Validate)
- **Requirement 1**: Zero-Configuration Installation → Tests for argument parsing, project detection, opam management
- **Requirement 2**: OCaml Project Detection → Tests for filesystem operations and environment validation
- **Requirement 3**: Custom Repository Support → Tests for URL parsing and validation
- **Requirement 4**: MCP Configuration Generation → Tests for JSON output formatting
- **Requirement 5**: Argument Forwarding → Tests for process execution and signal handling
- **Requirement 6**: Error Handling → Tests for error message formatting and recovery suggestions
- **Requirement 7**: Performance → Tests for timing and resource usage validation

## Test Framework Requirements

### Jest Configuration Requirements
1. **Test Environment**: Node.js environment with CommonJS and ES modules support
2. **Test File Patterns**: 
   - Unit tests: `lib/__tests__/**/*.test.js`
   - Integration tests: `__tests__/**/*.test.js`
3. **Coverage Thresholds**: 90% minimum for branches, functions, lines, statements
4. **Mock Capabilities**: 
   - File system operations (`fs`, `path`)
   - Process operations (`child_process`, `process`)
   - Network operations (`which`, `cross-spawn`)
5. **Test Timeout**: 30 seconds for integration tests, 5 seconds for unit tests
6. **Setup/Teardown**: Automated cleanup of test artifacts and mock state

### Code Quality Requirements
1. **ESLint Configuration**: Node.js best practices with strict error handling rules
2. **Prettier Integration**: Consistent code formatting across all test files
3. **Pre-commit Hooks**: Lint and format validation before commits

## Test Scenarios (GIVEN-WHEN-THEN Format)

### Scenario 1: Jest Configuration Validation
**GIVEN** a Jest configuration file exists  
**WHEN** Jest is executed with the configuration  
**THEN** it should successfully parse the configuration  
**AND** set up the correct test environment  
**AND** apply the specified coverage thresholds  

### Scenario 2: Mock Setup Validation
**GIVEN** filesystem operations need to be mocked  
**WHEN** a test requires mocking `fs.readdir` or `fs.existsSync`  
**THEN** Jest should provide clean mock implementations  
**AND** reset mocks between test runs  
**AND** allow spy verification on mock calls  

### Scenario 3: Process Mocking Validation
**GIVEN** child process spawning needs to be tested  
**WHEN** a test needs to mock `child_process.spawn`  
**THEN** Jest should provide controllable mock processes  
**AND** simulate exit codes and stdio streams  
**AND** allow verification of spawn arguments  

### Scenario 4: Async Testing Support
**GIVEN** the wrapper uses async/await patterns  
**WHEN** tests need to verify asynchronous behavior  
**THEN** Jest should support async test functions  
**AND** provide proper error handling for rejected promises  
**AND** allow testing of concurrent operations  

### Scenario 5: Coverage Threshold Enforcement
**GIVEN** code coverage requirements of 90%  
**WHEN** test coverage falls below the threshold  
**THEN** Jest should fail the test run  
**AND** provide detailed coverage reports  
**AND** identify specific uncovered lines  

### Scenario 6: ESLint Integration Validation
**GIVEN** ESLint configuration for Node.js best practices  
**WHEN** code violates linting rules  
**THEN** the linter should report specific violations  
**AND** suggest automatic fixes where possible  
**AND** enforce consistent error handling patterns  

## Test Implementation Tasks

### Phase 1: Jest Configuration
- [ ] **Task 2.1**: Create `jest.config.js` with Node.js environment and coverage settings
- [ ] **Task 2.2**: Configure test file patterns for unit and integration tests
- [ ] **Task 2.3**: Set up mock directories and manual mocks for external dependencies
- [ ] **Task 2.4**: Configure coverage thresholds (90% for all metrics)
- [ ] **Task 2.5**: Set up test timeout configurations for different test types

### Phase 2: ESLint and Prettier Configuration
- [ ] **Task 2.6**: Create `.eslintrc.js` with Node.js and Jest environments
- [ ] **Task 2.7**: Configure ESLint rules for error handling and async patterns
- [ ] **Task 2.8**: Set up Prettier integration with ESLint
- [ ] **Task 2.9**: Configure pre-commit hooks for automated linting

### Phase 3: Mock Framework Setup
- [ ] **Task 2.10**: Create filesystem mock utilities in `__mocks__/fs.js`
- [ ] **Task 2.11**: Create process mock utilities in `__mocks__/child_process.js`
- [ ] **Task 2.12**: Set up network operation mocks for `which` and external commands
- [ ] **Task 2.13**: Create test helpers for common mock scenarios

### Phase 4: Failing Test Templates
- [ ] **Task 2.14**: Write failing test for argument parser module (template)
- [ ] **Task 2.15**: Write failing test for project detector module (template)  
- [ ] **Task 2.16**: Write failing test for opam manager module (template)
- [ ] **Task 2.17**: Write failing test for binary executor module (template)
- [ ] **Task 2.18**: Write failing test for config generator module (template)
- [ ] **Task 2.19**: Write failing test for error handler module (template)

## Mock Strategy Specifications

### Filesystem Mocking Pattern
```javascript
// Mock filesystem operations to simulate different project structures
jest.mock('fs', () => ({
  existsSync: jest.fn(),
  readdir: jest.fn(),
  promises: {
    readdir: jest.fn(),
    stat: jest.fn()
  }
}));
```

### Process Mocking Pattern
```javascript
// Mock child_process to simulate opam and server execution
jest.mock('child_process', () => ({
  spawn: jest.fn(() => ({
    on: jest.fn(),
    stdout: { on: jest.fn() },
    stderr: { on: jest.fn() },
    kill: jest.fn()
  }))
}));
```

### External Command Mocking Pattern
```javascript
// Mock external utilities like 'which' to control environment detection
jest.mock('which', () => ({
  sync: jest.fn()
}));
```

## Test File Organization Structure

```
npx-wrapper/
├── jest.config.js                          # Main Jest configuration
├── .eslintrc.js                           # ESLint configuration  
├── __mocks__/                             # Manual mocks directory
│   ├── fs.js                             # Filesystem mocks
│   ├── child_process.js                  # Process mocks
│   └── which.js                          # External command mocks
├── lib/                                   # Source code modules
│   └── __tests__/                        # Unit tests directory
│       ├── argument-parser.test.js       # Argument parsing tests
│       ├── project-detector.test.js      # Project detection tests
│       ├── opam-manager.test.js          # Opam management tests
│       ├── binary-executor.test.js       # Process execution tests
│       ├── config-generator.test.js      # Config generation tests
│       └── error-handler.test.js         # Error handling tests
└── __tests__/                            # Integration tests directory
    ├── integration.test.js               # End-to-end workflow tests
    └── helpers/                          # Test utility functions
        ├── mock-helpers.js               # Common mock setups
        └── test-fixtures.js              # Test data and scenarios
```

## Coverage Requirements by Module

### Minimum Coverage Targets (90% Each)
- **argument-parser.js**: 90% branches, functions, lines, statements
- **project-detector.js**: 90% coverage including error paths
- **opam-manager.js**: 90% coverage including installation failures  
- **binary-executor.js**: 90% coverage including signal handling
- **config-generator.js**: 90% coverage including optional parameters
- **error-handler.js**: 90% coverage across all error types

### Coverage Exclusions
- Test files themselves (*.test.js)
- Mock implementations (__mocks__/*)
- Configuration files (jest.config.js, .eslintrc.js)

## TDD Cycle Validation Requirements

### Red Phase Validation (Failing Tests)
1. **Test Must Fail**: Each test MUST fail when first written
2. **Clear Failure Messages**: Failure should indicate missing functionality
3. **One Behavior Per Test**: Each test focuses on single behavior
4. **Descriptive Test Names**: Test names describe expected behavior clearly

### Green Phase Validation (Passing Tests)  
1. **Minimal Implementation**: Write only enough code to make test pass
2. **No Over-Engineering**: Avoid implementing untested functionality
3. **Preserve Existing Tests**: New code doesn't break existing tests

### Refactor Phase Validation (Code Quality)
1. **Maintain Test Coverage**: Refactoring must not reduce coverage
2. **Improve Code Quality**: ESLint should show improvements
3. **Performance Maintenance**: No significant performance regression

## Acceptance Criteria

### Configuration Validation
- [ ] Jest configuration successfully loads and runs tests
- [ ] Coverage thresholds are enforced and cause build failures when not met
- [ ] ESLint catches common Node.js and async/await issues
- [ ] Prettier formats all code consistently

### Mock System Validation  
- [ ] Filesystem operations can be completely mocked and controlled
- [ ] Process spawning can be simulated with controllable behavior
- [ ] External command dependencies can be mocked reliably
- [ ] Mocks reset cleanly between test runs

### Test Framework Validation
- [ ] Async tests run reliably with proper timeout handling
- [ ] Error scenarios can be tested comprehensively
- [ ] Test isolation prevents cross-test interference
- [ ] Coverage reports provide actionable feedback

### TDD Workflow Validation
- [ ] Initial template tests fail with clear, informative messages
- [ ] Test structure guides implementation design effectively
- [ ] Red-Green-Refactor cycle is supported and enforced
- [ ] Test-first development is the natural workflow

## Success Metrics

1. **Coverage Achievement**: All modules achieve 90%+ coverage
2. **Test Reliability**: All tests pass consistently across runs
3. **Mock Effectiveness**: Mocks accurately simulate real dependencies
4. **Development Velocity**: TDD cycle runs quickly (< 10 seconds for unit tests)
5. **Error Detection**: Configuration catches common coding mistakes early
6. **Maintainability**: Test code is as clean and readable as production code

## Implementation Order (TDD Phases)

1. **Setup Phase**: Create configuration files (jest.config.js, .eslintrc.js)
2. **Mock Phase**: Implement mock framework and helpers
3. **Template Phase**: Write failing test templates for each module
4. **Validation Phase**: Verify all systems work together correctly
5. **Documentation Phase**: Document test patterns and best practices

This specification ensures that our Jest setup not only meets the basic requirements but establishes a robust foundation for comprehensive TDD throughout the project lifecycle.