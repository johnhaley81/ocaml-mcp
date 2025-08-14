# Requirements Document

## Introduction

The OCaml MCP NPX Wrapper is a Node.js-based distribution mechanism that provides zero-configuration installation and execution of the ocaml-mcp-server for OCaml developers using AI coding assistants. This wrapper bridges the gap between the ubiquitous NPM ecosystem and the OCaml development environment, eliminating the complex manual setup currently required to integrate OCaml projects with AI assistants via the Model Context Protocol (MCP).

## Alignment with Product Vision

As outlined in our product steering, this feature directly supports our goal of making OCaml AI-assisted development as accessible as JavaScript or Python projects. The NPX wrapper embodies our core principles of zero configuration, developer familiarity, and graceful error handling, while providing the progressive enhancement that allows basic features to work everywhere with advanced capabilities when available.

## Requirements

### Requirement 1: Zero-Configuration Installation

**User Story:** As an OCaml developer, I want to run a single NPX command that automatically installs and executes the MCP server, so that I can start using AI assistance immediately without manual setup.

#### Acceptance Criteria

1. WHEN a user runs `npx @ocaml-mcp/server --root .` for the first time THEN the system SHALL automatically detect the absence of ocaml-mcp-server and initiate installation without user intervention
2. IF the user is in an OCaml project directory with an active opam switch THEN the system SHALL install ocaml-mcp-server into that switch via `opam pin add`
3. WHEN installation is in progress THEN the system SHALL operate silently unless an error occurs
4. IF installation completes successfully THEN the system SHALL immediately execute the server with the provided arguments
5. WHEN subsequent runs occur after installation THEN the system SHALL skip installation and execute directly in under 1 second

### Requirement 2: OCaml Project Detection and Validation

**User Story:** As an OCaml developer, I want the wrapper to automatically detect whether I'm in an OCaml project and validate the environment, so that I receive clear feedback if prerequisites are missing.

#### Acceptance Criteria

1. WHEN the wrapper starts THEN the system SHALL search for `dune-project` or `*.opam` files in the current directory and up to 2 levels deep
2. IF no OCaml project markers are found THEN the system SHALL exit with a clear error message explaining the requirement
3. WHEN checking for opam availability THEN the system SHALL verify opam is installed and accessible in PATH
4. IF opam is not available THEN the system SHALL provide installation instructions for the user's platform
5. WHEN validating the environment AND all prerequisites are met THEN the system SHALL proceed with installation or execution

### Requirement 3: Custom Repository Support

**User Story:** As an OCaml developer or contributor, I want to specify a custom git repository for installing ocaml-mcp-server, so that I can use forked versions or development branches.

#### Acceptance Criteria

1. WHEN a user provides `--repo <url>` argument THEN the system SHALL use that repository URL for opam pin instead of the default
2. IF the repository URL is invalid or inaccessible THEN the system SHALL fail with a clear error message about the repository issue
3. WHEN parsing arguments AND `--repo` is present THEN the system SHALL extract it and its value before forwarding remaining arguments to the server
4. IF multiple `--repo` arguments are provided THEN the system SHALL use the last one specified
5. WHEN the custom repository is used successfully THEN the system SHALL remember this for future operations in the same project

### Requirement 4: MCP Configuration Generation

**User Story:** As an AI tool user, I want to generate proper MCP configuration for my AI client, so that I can easily configure Claude Desktop or other MCP-compatible clients.

#### Acceptance Criteria

1. WHEN a user runs `npx @ocaml-mcp/server --print-config` THEN the system SHALL output valid MCP JSON configuration to stdout
2. IF `--print-config` is specified THEN the system SHALL not install or execute the server, only generate configuration
3. WHEN generating configuration THEN the system SHALL include the proper NPX command structure with workspace folder variables
4. IF custom repository was used for installation THEN the configuration SHALL include the `--repo` parameter
5. WHEN configuration is generated THEN it SHALL be properly formatted JSON that can be directly copied into MCP client configurations

### Requirement 5: Argument Forwarding and Process Delegation

**User Story:** As an OCaml developer, I want all server arguments to be properly forwarded to ocaml-mcp-server, so that I can use all available server features without wrapper interference.

#### Acceptance Criteria

1. WHEN arguments are provided after wrapper-specific flags THEN the system SHALL forward all non-wrapper arguments to ocaml-mcp-server unchanged
2. IF the server returns an exit code THEN the wrapper SHALL exit with the same code
3. WHEN the server outputs to stdout/stderr THEN the wrapper SHALL pass through all output without modification
4. IF the server is interrupted (SIGINT/SIGTERM) THEN the wrapper SHALL properly propagate the signal
5. WHEN executing the server THEN the wrapper SHALL use `opam exec -- ocaml-mcp-server` to ensure proper environment

### Requirement 6: Error Handling and Recovery

**User Story:** As an OCaml developer, I want clear error messages and recovery suggestions when something goes wrong, so that I can quickly resolve issues and continue working.

#### Acceptance Criteria

1. WHEN an error occurs THEN the system SHALL provide a clear, actionable error message explaining what went wrong
2. IF installation fails THEN the system SHALL suggest manual installation steps as a fallback
3. WHEN network issues prevent repository access THEN the system SHALL distinguish between network and repository errors
4. IF the opam pin command fails THEN the system SHALL check for common causes (switch issues, permissions) and provide specific guidance
5. WHEN any subprocess fails THEN the system SHALL preserve and display the original error output for debugging

### Requirement 7: Performance and Resource Management

**User Story:** As an OCaml developer, I want the wrapper to have minimal overhead and resource usage, so that it doesn't impact my development workflow or system performance.

#### Acceptance Criteria

1. WHEN checking for existing installation THEN the system SHALL complete the check in under 500ms
2. IF the server is already installed THEN the wrapper SHALL add no more than 100ms overhead to server startup
3. WHEN running the wrapper process THEN memory usage SHALL not exceed 50MB
4. IF installation is needed THEN the system SHALL complete within 3 minutes on typical internet connections
5. WHEN the wrapper exits THEN all resources SHALL be properly cleaned up with no orphaned processes

## Non-Functional Requirements

### Code Architecture and Modularity
- **Single Responsibility Principle**: Each JavaScript module shall handle one specific concern (argument parsing, project detection, opam management, etc.)
- **Modular Design**: Components shall be isolated and independently testable with clear interfaces
- **Dependency Management**: Minimize runtime dependencies to Node.js built-in modules only
- **Clear Interfaces**: Each module shall export a well-defined API with Result-style error handling

### Performance
- Cold start (first installation): < 2 minutes to complete installation (accounting for potential binary compilation)
- Warm start (already installed): < 1 second to server execution
- Memory footprint: < 50MB for wrapper process
- CPU usage: Minimal overhead during process delegation

### Security
- Validate all user inputs to prevent command injection
- Sanitize repository URLs before using in shell commands
- Never execute arbitrary code from untrusted sources
- Avoid exposing sensitive file paths in error messages
- Run with minimal required permissions

### Reliability
- Graceful handling of all error conditions
- Atomic operations where possible (all-or-nothing installation)
- Proper cleanup on failure or interruption
- Idempotent installation (can safely re-run)
- Compatible with different opam configurations

### Usability
- Single command execution: `npx @ocaml-mcp/server`
- No configuration files required
- Clear, actionable error messages
- Silent operation when successful
- Platform-agnostic command structure

### Testing Requirements
- Unit test coverage: minimum 90% for all modules
- Integration tests for complete workflows
- Mock all external dependencies in unit tests
- Test all error scenarios and edge cases
- Cross-platform testing on macOS, Linux, and Windows (WSL)

### Compatibility
- Node.js: Version 14.0.0 or higher
- OCaml: Any version supported by ocaml-mcp-server
- Opam: Version 2.0 or higher
- Platforms: macOS, Linux, Windows (via WSL)
- MCP Protocol: Current specification compliance