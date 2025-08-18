/**
 * Error Handler - Test-Driven Development
 *
 * TEST SPECIFICATION:
 * ===================
 * Component: ErrorHandler
 * Interface: 
 *   - handleError(error: Error | string, context?: string): string
 *
 * REQUIREMENTS COVERAGE:
 * - Req 6.1: Error Message Formatting - Consistent format with clear problem description
 * - Req 6.2: Actionable Suggestions - Provide specific next steps for common failures
 * - Req 6.3: Error Type Handling - Handle different error categories appropriately
 * - Req 6.4: Context Integration - Include operational context in error messages
 * - Req 6.5: Error Preservation - Maintain original error details for debugging
 *
 * TEST SCENARIOS:
 * 1. Error Message Structure and Formatting
 *    - Consistent format across all error types
 *    - Clear problem statement with user-friendly language
 *    - Include original error information
 *    - Professional, helpful tone in all messages
 *
 * 2. OCaml Project Detection Failures
 *    - No dune-project file found
 *    - No .opam files detected
 *    - Invalid project structure
 *    - Permission issues accessing project files
 *    - Actionable suggestions for each scenario
 *
 * 3. Opam Installation Errors
 *    - Opam not available/installed (exit code 127)
 *    - Repository access issues (exit code 5)
 *    - Dependency resolution failures (exit code 20)
 *    - Package unavailable errors (exit code 30)
 *    - Installation conflicts (exit code 31)
 *    - Network connectivity issues (exit code 40)
 *    - Specific manual commands for each error type
 *
 * 4. Network and Connectivity Issues
 *    - DNS resolution failures
 *    - Connection timeout errors
 *    - Certificate/SSL errors
 *    - Proxy configuration issues
 *    - Platform-specific networking guidance
 *
 * 5. Permission and Access Errors
 *    - Permission denied on file operations
 *    - Directory access restrictions
 *    - Sudo/elevated permissions needed
 *    - File system read-only errors
 *    - Platform-specific permission guidance
 *
 * 6. Binary Execution Failures
 *    - Binary not found errors
 *    - Architecture incompatibility
 *    - Missing shared libraries
 *    - Execution timeout scenarios
 *    - Manual fallback options
 *
 * 7. Context Integration
 *    - Include context parameter in error messages
 *    - Handle missing/null context gracefully
 *    - Context helps users understand failed operation
 *    - Different contexts produce appropriate messaging
 *
 * 8. Error Input Handling
 *    - Handle Error objects vs string messages
 *    - Null/undefined error inputs
 *    - Very long error messages
 *    - Error messages with special characters
 *    - Nested error objects and stack traces
 *
 * 9. Actionable Suggestion Generation
 *    - Platform-specific instructions (macOS/Linux)
 *    - Manual command alternatives
 *    - Links to documentation resources
 *    - Step-by-step troubleshooting guides
 *    - Fallback options when automation fails
 *
 * 10. Error Code and Technical Detail Preservation
 *     - Preserve original error codes for debugging
 *     - Include technical details without overwhelming users
 *     - Maintain error stack traces when available
 *     - Support both user-friendly and developer debugging needs
 *
 * IMPLEMENTATION TASKS:
 * - [ ] Write failing tests for error message structure validation
 * - [ ] Write failing tests for OCaml project detection error scenarios
 * - [ ] Write failing tests for opam installation error handling
 * - [ ] Write failing tests for network connectivity error messages
 * - [ ] Write failing tests for permission and access error handling
 * - [ ] Write failing tests for binary execution failure scenarios
 * - [ ] Write failing tests for context integration functionality
 * - [ ] Write failing tests for error input edge cases
 * - [ ] Write failing tests for actionable suggestion generation
 * - [ ] Write failing tests for technical detail preservation
 *
 * Following TDD Red-Green-Refactor cycle:
 * RED: All tests below MUST FAIL initially (ErrorHandler doesn't exist)
 * GREEN: Write minimal code to make tests pass
 * REFACTOR: Improve code while keeping tests green
 */

import { jest } from '@jest/globals';
import { ErrorHandler } from '../error-handler.js';

describe('ErrorHandler - TDD Specification', () => {
  let errorHandler;

  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
    
    // Initialize ErrorHandler instance
    errorHandler = new ErrorHandler();
  });

  describe('Error Message Structure and Formatting', () => {
    test('should_format_error_with_consistent_structure', () => {
      // GIVEN: A basic error message
      const error = 'Something went wrong';
      const context = 'project detection';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should return formatted error message with consistent structure
      expect(result).toBeDefined();
      expect(typeof result).toBe('string');
      expect(result.length).toBeGreaterThan(0);
      expect(result).toContain('Error');
      expect(result).toContain(context);
    });

    test('should_include_clear_problem_statement', () => {
      // GIVEN: Error during opam installation
      const error = new Error('Command failed with exit code 5');
      const context = 'opam installation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should include clear problem statement
      expect(result).toContain('failed');
      expect(result).toContain('opam installation');
      expect(result).not.toMatch(/^Error:/); // Should not start with raw "Error:"
      expect(result).toMatch(/problem|issue|failed/i); // Should describe the problem
    });

    test('should_use_user_friendly_language', () => {
      // GIVEN: Technical error with jargon
      const error = 'ENOENT: no such file or directory, open \'/path/dune-project\'';
      const context = 'project detection';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should use user-friendly language
      expect(result).not.toContain('ENOENT'); // Should not expose technical error codes
      expect(result).toMatch(/could not find|missing|not found/i);
      expect(result).toMatch(/file|directory/i);
    });

    test('should_maintain_professional_helpful_tone', () => {
      // GIVEN: Various error scenarios
      const testCases = [
        { error: 'Permission denied', context: 'file access' },
        { error: 'Network timeout', context: 'package installation' },
        { error: 'Binary not found', context: 'execution' }
      ];
      
      // WHEN/THEN: Each error should maintain professional tone
      testCases.forEach(({ error, context }) => {
        const result = errorHandler.handleError(error, context);
        
        // Should avoid negative language
        expect(result).not.toMatch(/failed|error|wrong|bad/i);
        // Should use constructive language
        expect(result).toMatch(/try|check|ensure|verify/i);
        // Should provide guidance
        expect(result).toMatch(/you can|to resolve|next steps/i);
      });
    });

    test('should_preserve_original_error_information', () => {
      // GIVEN: Error with specific details
      const originalMessage = 'Package ocaml-base-compiler.4.14.0 not available';
      const error = new Error(originalMessage);
      const context = 'package installation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should preserve key error details
      expect(result).toContain('ocaml-base-compiler');
      expect(result).toContain('4.14.0');
      expect(result).toContain('not available');
    });

    test('should_handle_error_objects_vs_strings', () => {
      // GIVEN: Both Error objects and string messages
      const errorObject = new Error('Test error message');
      const errorString = 'Test error message';
      const context = 'testing';
      
      // WHEN: Handling both types
      const resultFromObject = errorHandler.handleError(errorObject, context);
      const resultFromString = errorHandler.handleError(errorString, context);

      // THEN: Should handle both consistently
      expect(typeof resultFromObject).toBe('string');
      expect(typeof resultFromString).toBe('string');
      expect(resultFromObject).toContain('Test error message');
      expect(resultFromString).toContain('Test error message');
    });
  });

  describe('OCaml Project Detection Failures', () => {
    test('should_handle_missing_dune_project_file', () => {
      // GIVEN: No dune-project file found error
      const error = 'ENOENT: no such file or directory, open \'dune-project\'';
      const context = 'OCaml project detection';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide specific guidance for dune-project
      expect(result).toMatch(/dune-project/i);
      expect(result).toMatch(/OCaml project/i);
      expect(result).toContain('dune init');
      expect(result).toMatch(/create|initialize/i);
    });

    test('should_handle_missing_opam_files', () => {
      // GIVEN: No .opam files detected error
      const error = 'No .opam files found in project directory';
      const context = 'project structure validation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide .opam file creation guidance
      expect(result).toMatch(/\.opam/);
      expect(result).toContain('opam init');
      expect(result).toMatch(/package definition|project metadata/i);
      expect(result).toMatch(/create|generate/i);
    });

    test('should_handle_invalid_project_structure', () => {
      // GIVEN: Invalid OCaml project structure
      const error = 'Invalid OCaml project structure detected';
      const context = 'project validation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should suggest project structure fixes
      expect(result).toMatch(/project structure/i);
      expect(result).toContain('dune init');
      expect(result).toMatch(/lib|bin|test/); // Common OCaml directories
      expect(result).toMatch(/reorganize|restructure/i);
    });

    test('should_handle_project_detection_permission_issues', () => {
      // GIVEN: Permission denied during project detection
      const error = 'EACCES: permission denied, scandir \'/project\'';
      const context = 'project scanning';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide permission troubleshooting
      expect(result).toMatch(/permission/i);
      expect(result).toMatch(/access/i);
      expect(result).toContain('chmod');
      expect(result).toMatch(/check.*permissions/i);
    });

    test('should_provide_manual_project_setup_commands', () => {
      // GIVEN: Project detection failure requiring manual setup
      const error = 'Could not detect valid OCaml project';
      const context = 'automatic project detection';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should include manual setup commands
      expect(result).toContain('dune init project');
      expect(result).toMatch(/opam.*init/);
      expect(result).toMatch(/cd.*&&.*dune/);
      expect(result).toMatch(/step.*by.*step|manual.*setup/i);
    });
  });

  describe('Opam Installation Errors', () => {
    test('should_handle_opam_not_installed', () => {
      // GIVEN: Opam command not found (exit code 127)
      const error = new Error('Command \'opam\' not found');
      error.code = 127;
      const context = 'opam availability check';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide opam installation instructions
      expect(result).toMatch(/opam.*not.*installed/i);
      expect(result).toContain('brew install opam'); // macOS
      expect(result).toContain('apt-get install opam'); // Ubuntu/Debian
      expect(result).toMatch(/package.*manager/i);
    });

    test('should_handle_repository_access_issues', () => {
      // GIVEN: Repository access error (exit code 5)
      const error = new Error('Cannot access opam repository');
      error.code = 5;
      const context = 'opam repository update';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide repository troubleshooting
      expect(result).toMatch(/repository/i);
      expect(result).toContain('opam update');
      expect(result).toContain('opam repository');
      expect(result).toMatch(/network|connectivity/i);
    });

    test('should_handle_dependency_resolution_failures', () => {
      // GIVEN: Dependency resolution error (exit code 20)
      const error = new Error('Dependency resolution failed');
      error.code = 20;
      const context = 'package dependency resolution';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide dependency troubleshooting
      expect(result).toMatch(/dependency|dependencies/i);
      expect(result).toContain('opam install --deps-only');
      expect(result).toContain('opam depext');
      expect(result).toMatch(/conflict|resolution/i);
    });

    test('should_handle_package_unavailable_errors', () => {
      // GIVEN: Package not available error (exit code 30)
      const error = new Error('Package not available in current switch');
      error.code = 30;
      const context = 'package installation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide package availability guidance
      expect(result).toMatch(/package.*not.*available/i);
      expect(result).toContain('opam search');
      expect(result).toContain('opam switch');
      expect(result).toMatch(/switch|version/i);
    });

    test('should_handle_installation_conflicts', () => {
      // GIVEN: Installation conflict error (exit code 31)
      const error = new Error('Installation conflicts detected');
      error.code = 31;
      const context = 'package installation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide conflict resolution guidance
      expect(result).toMatch(/conflict/i);
      expect(result).toContain('opam remove');
      expect(result).toContain('opam reinstall');
      expect(result).toMatch(/clean.*install/i);
    });

    test('should_handle_network_connectivity_issues', () => {
      // GIVEN: Network error during opam operations (exit code 40)
      const error = new Error('Network connection failed');
      error.code = 40;
      const context = 'opam package download';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide network troubleshooting
      expect(result).toMatch(/network|connection/i);
      expect(result).toMatch(/internet.*connection/i);
      expect(result).toContain('ping');
      expect(result).toMatch(/firewall|proxy/i);
    });

    test('should_provide_platform_specific_opam_guidance', () => {
      // GIVEN: Various opam installation errors
      const testCases = [
        { error: 'opam: command not found', platform: 'macOS' },
        { error: 'opam: command not found', platform: 'Linux' }
      ];
      
      // WHEN/THEN: Should provide platform-specific guidance
      testCases.forEach(({ error, platform }) => {
        const result = errorHandler.handleError(error, 'opam installation');
        
        if (platform === 'macOS') {
          expect(result).toContain('brew install opam');
          expect(result).toContain('Homebrew');
        }
        expect(result).toMatch(/apt-get|yum|dnf|pacman/); // Various Linux package managers
      });
    });
  });

  describe('Network and Connectivity Issues', () => {
    test('should_handle_dns_resolution_failures', () => {
      // GIVEN: DNS resolution error
      const error = 'ENOTFOUND: getaddrinfo ENOTFOUND opam.ocaml.org';
      const context = 'package repository access';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide DNS troubleshooting guidance
      expect(result).toMatch(/DNS|domain.*name/i);
      expect(result).toContain('nslookup');
      expect(result).toContain('8.8.8.8'); // Google DNS
      expect(result).toMatch(/network.*settings/i);
    });

    test('should_handle_connection_timeout_errors', () => {
      // GIVEN: Connection timeout error
      const error = 'ETIMEDOUT: connection timed out';
      const context = 'package download';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide timeout troubleshooting
      expect(result).toMatch(/timeout|timed.*out/i);
      expect(result).toMatch(/slow.*connection/i);
      expect(result).toContain('--timeout');
      expect(result).toMatch(/retry|try.*again/i);
    });

    test('should_handle_ssl_certificate_errors', () => {
      // GIVEN: SSL certificate error
      const error = 'CERT_UNTRUSTED: certificate verify failed';
      const context = 'secure package download';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide SSL troubleshooting
      expect(result).toMatch(/certificate|SSL|TLS/i);
      expect(result).toMatch(/security|trust/i);
      expect(result).toContain('--insecure');
      expect(result).toMatch(/certificate.*bundle/i);
    });

    test('should_handle_proxy_configuration_issues', () => {
      // GIVEN: Proxy-related connection error
      const error = 'Proxy connection failed';
      const context = 'network connection through proxy';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide proxy troubleshooting
      expect(result).toMatch(/proxy/i);
      expect(result).toContain('HTTP_PROXY');
      expect(result).toContain('HTTPS_PROXY');
      expect(result).toMatch(/proxy.*settings/i);
    });

    test('should_provide_network_diagnostic_commands', () => {
      // GIVEN: General network connectivity issue
      const error = 'Network unreachable';
      const context = 'internet connectivity';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should include network diagnostic commands
      expect(result).toContain('ping google.com');
      expect(result).toContain('curl -I');
      expect(result).toMatch(/traceroute|tracert/);
      expect(result).toContain('netstat');
    });
  });

  describe('Permission and Access Errors', () => {
    test('should_handle_permission_denied_file_operations', () => {
      // GIVEN: Permission denied on file operation
      const error = 'EACCES: permission denied, open \'/usr/local/bin/binary\'';
      const context = 'binary installation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide permission troubleshooting
      expect(result).toMatch(/permission.*denied/i);
      expect(result).toContain('sudo');
      expect(result).toContain('chmod');
      expect(result).toMatch(/administrator.*privileges/i);
    });

    test('should_handle_directory_access_restrictions', () => {
      // GIVEN: Directory access restriction
      const error = 'EACCES: permission denied, scandir \'/root/project\'';
      const context = 'project directory access';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide directory access guidance
      expect(result).toMatch(/directory.*access/i);
      expect(result).toContain('ls -la');
      expect(result).toContain('chown');
      expect(result).toMatch(/user.*permissions/i);
    });

    test('should_handle_elevated_permissions_requirements', () => {
      // GIVEN: Operation requiring elevated permissions
      const error = 'Operation requires administrator privileges';
      const context = 'system package installation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should guide on using elevated permissions
      expect(result).toMatch(/administrator|elevated/i);
      expect(result).toContain('sudo');
      expect(result).toMatch(/run.*as.*administrator/i);
      expect(result).toMatch(/root.*access/i);
    });

    test('should_handle_readonly_filesystem_errors', () => {
      // GIVEN: Read-only file system error
      const error = 'EROFS: read-only file system, mkdir \'/install/path\'';
      const context = 'installation directory creation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide read-only filesystem guidance
      expect(result).toMatch(/read.*only|readonly/i);
      expect(result).toMatch(/filesystem|file.*system/i);
      expect(result).toContain('mount');
      expect(result).toMatch(/alternate.*location/i);
    });

    test('should_provide_permission_diagnostic_commands', () => {
      // GIVEN: Generic permission issue
      const error = 'Access denied';
      const context = 'file system operation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should include permission diagnostic commands
      expect(result).toContain('ls -la');
      expect(result).toContain('whoami');
      expect(result).toContain('id');
      expect(result).toMatch(/check.*permissions/i);
    });
  });

  describe('Binary Execution Failures', () => {
    test('should_handle_binary_not_found_errors', () => {
      // GIVEN: Binary not found error
      const error = 'ENOENT: no such file or directory, spawn \'ocaml-mcp-server\'';
      const context = 'MCP server execution';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide binary location guidance
      expect(result).toMatch(/binary.*not.*found|command.*not.*found/i);
      expect(result).toContain('which');
      expect(result).toContain('PATH');
      expect(result).toMatch(/install|installation/i);
    });

    test('should_handle_architecture_incompatibility', () => {
      // GIVEN: Architecture mismatch error
      const error = 'cannot execute binary file: Exec format error';
      const context = 'binary execution';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide architecture guidance
      expect(result).toMatch(/architecture|platform/i);
      expect(result).toContain('uname -m');
      expect(result).toMatch(/compatible.*binary/i);
      expect(result).toMatch(/x86|arm|aarch64/i);
    });

    test('should_handle_missing_shared_libraries', () => {
      // GIVEN: Missing shared library error
      const error = 'error while loading shared libraries: libssl.so.1.1: cannot open shared object file';
      const context = 'binary startup';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide library installation guidance
      expect(result).toMatch(/shared.*libraries|dependencies/i);
      expect(result).toContain('ldd');
      expect(result).toMatch(/install.*libraries/i);
      expect(result).toMatch(/libssl|openssl/i);
    });

    test('should_handle_execution_timeout_scenarios', () => {
      // GIVEN: Binary execution timeout
      const error = 'Process timed out after 30000ms';
      const context = 'MCP server startup';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide timeout troubleshooting
      expect(result).toMatch(/timeout|timed.*out/i);
      expect(result).toMatch(/taking.*too.*long/i);
      expect(result).toContain('--timeout');
      expect(result).toMatch(/increase.*timeout/i);
    });

    test('should_provide_manual_binary_execution_fallback', () => {
      // GIVEN: Automated execution failure
      const error = 'Automatic binary execution failed';
      const context = 'automated MCP server launch';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide manual execution commands
      expect(result).toMatch(/manual|manually/i);
      expect(result).toContain('./ocaml-mcp-server');
      expect(result).toMatch(/command.*line/i);
      expect(result).toMatch(/directly.*run/i);
    });
  });

  describe('Context Integration', () => {
    test('should_include_context_in_error_messages', () => {
      // GIVEN: Error with specific context
      const error = 'Operation failed';
      const context = 'package dependency resolution';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should include context in the message
      expect(result).toContain('package dependency resolution');
      expect(result).toMatch(/during.*package.*dependency.*resolution/i);
    });

    test('should_handle_missing_context_gracefully', () => {
      // GIVEN: Error without context
      const error = 'Something went wrong';
      const context = null;
      
      // WHEN: Handling the error without context
      const result = errorHandler.handleError(error, context);

      // THEN: Should handle gracefully without context
      expect(result).toBeDefined();
      expect(typeof result).toBe('string');
      expect(result.length).toBeGreaterThan(0);
      expect(result).toContain('Something went wrong');
    });

    test('should_handle_undefined_context', () => {
      // GIVEN: Error with undefined context
      const error = 'Test error';
      const context = undefined;
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should work without context parameter
      expect(result).toBeDefined();
      expect(result).toContain('Test error');
    });

    test('should_adapt_suggestions_based_on_context', () => {
      // GIVEN: Same error in different contexts
      const error = 'Permission denied';
      const contexts = [
        'file reading',
        'directory creation',
        'binary execution'
      ];
      
      // WHEN/THEN: Should provide context-appropriate suggestions
      contexts.forEach(context => {
        const result = errorHandler.handleError(error, context);
        
        if (context === 'file reading') {
          expect(result).toMatch(/read.*permission/i);
        } else if (context === 'directory creation') {
          expect(result).toMatch(/write.*permission/i);
        } else if (context === 'binary execution') {
          expect(result).toMatch(/execute.*permission/i);
        }
      });
    });

    test('should_use_context_to_enhance_problem_description', () => {
      // GIVEN: Generic error with specific context
      const error = 'Not found';
      const context = 'OCaml compiler binary lookup';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should enhance description using context
      expect(result).toMatch(/OCaml.*compiler/i);
      expect(result).toMatch(/binary.*not.*found/i);
      expect(result).toMatch(/compiler.*installation/i);
    });
  });

  describe('Error Input Edge Cases', () => {
    test('should_handle_null_error_input', () => {
      // GIVEN: Null error input
      const error = null;
      const context = 'testing';
      
      // WHEN: Handling null error
      const result = errorHandler.handleError(error, context);

      // THEN: Should handle gracefully
      expect(result).toBeDefined();
      expect(typeof result).toBe('string');
      expect(result.length).toBeGreaterThan(0);
      expect(result).toMatch(/unknown.*error|unexpected.*error/i);
    });

    test('should_handle_undefined_error_input', () => {
      // GIVEN: Undefined error input
      const error = undefined;
      const context = 'testing';
      
      // WHEN: Handling undefined error
      const result = errorHandler.handleError(error, context);

      // THEN: Should handle gracefully
      expect(result).toBeDefined();
      expect(result).toMatch(/unknown.*error|unexpected.*error/i);
    });

    test('should_handle_very_long_error_messages', () => {
      // GIVEN: Very long error message
      const longMessage = 'Error: ' + 'a'.repeat(5000);
      const context = 'testing';
      
      // WHEN: Handling long error
      const result = errorHandler.handleError(longMessage, context);

      // THEN: Should handle without truncating important information
      expect(result).toBeDefined();
      expect(result.length).toBeGreaterThan(100); // Should include substantial content
      expect(result).toMatch(/Error/i);
    });

    test('should_handle_error_messages_with_special_characters', () => {
      // GIVEN: Error with special characters
      const error = 'Error: Package "my-package@1.0.0" not found in /path/to/dir with spaces & symbols!';
      const context = 'package resolution';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should preserve special characters appropriately
      expect(result).toContain('my-package');
      expect(result).toContain('1.0.0');
      expect(result).toContain('not found');
    });

    test('should_handle_error_objects_with_stack_traces', () => {
      // GIVEN: Error object with stack trace
      const error = new Error('Test error with stack');
      error.stack = 'Error: Test error\n    at Function.test (/path/file.js:123:45)';
      const context = 'testing';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should include relevant details without overwhelming user
      expect(result).toContain('Test error with stack');
      // Stack trace should be available but not dominate user message
      expect(result).toBeDefined();
    });

    test('should_handle_nested_error_objects', () => {
      // GIVEN: Nested error structure
      const innerError = new Error('Inner error details');
      const error = new Error('Outer error');
      error.cause = innerError;
      const context = 'nested error handling';
      
      // WHEN: Handling nested error
      const result = errorHandler.handleError(error, context);

      // THEN: Should handle nested structure
      expect(result).toContain('Outer error');
      expect(result).toBeDefined();
    });
  });

  describe('Actionable Suggestion Generation', () => {
    test('should_provide_platform_specific_installation_instructions', () => {
      // GIVEN: Installation-related error
      const error = 'opam command not found';
      const context = 'OCaml setup';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide platform-specific instructions
      expect(result).toContain('brew install opam'); // macOS
      expect(result).toMatch(/apt-get.*install.*opam/); // Ubuntu/Debian
      expect(result).toMatch(/yum|dnf.*install.*opam/); // RHEL/Fedora
    });

    test('should_include_manual_command_alternatives', () => {
      // GIVEN: Automation failure
      const error = 'Automated setup failed';
      const context = 'project initialization';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide manual alternatives
      expect(result).toMatch(/manual|manually/i);
      expect(result).toContain('dune init');
      expect(result).toContain('opam init');
      expect(result).toMatch(/step.*by.*step/i);
    });

    test('should_provide_documentation_links_and_resources', () => {
      // GIVEN: Complex setup error
      const error = 'OCaml development environment setup failed';
      const context = 'development environment';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should include documentation references
      expect(result).toMatch(/documentation|docs/i);
      expect(result).toMatch(/guide|tutorial/i);
      expect(result).toMatch(/ocaml\.org|opam\.ocaml\.org/i);
    });

    test('should_offer_step_by_step_troubleshooting_guides', () => {
      // GIVEN: Complex troubleshooting scenario
      const error = 'Multiple issues detected in OCaml setup';
      const context = 'environment validation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should provide structured troubleshooting
      expect(result).toMatch(/step.*1|first.*step/i);
      expect(result).toMatch(/then|next|after/i);
      expect(result).toMatch(/verify|check|ensure/i);
    });

    test('should_provide_fallback_options', () => {
      // GIVEN: Primary solution failure
      const error = 'Primary installation method failed';
      const context = 'package installation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should offer fallback approaches
      expect(result).toMatch(/alternatively|fallback|try.*instead/i);
      expect(result).toMatch(/docker|container/i);
      expect(result).toMatch(/source.*installation/i);
    });

    test('should_prioritize_most_likely_solutions', () => {
      // GIVEN: Common error scenario
      const error = 'Package not found';
      const context = 'opam package installation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should prioritize common solutions
      expect(result).toMatch(/first|try.*this|most.*common/i);
      expect(result).toContain('opam update');
      expect(result).toMatch(/if.*that.*doesn.*work/i);
    });
  });

  describe('Technical Detail Preservation', () => {
    test('should_preserve_error_codes_for_debugging', () => {
      // GIVEN: Error with specific code
      const error = new Error('Installation failed');
      error.code = 'EACCES';
      error.errno = -13;
      const context = 'package installation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should preserve technical details
      expect(result).toMatch(/EACCES|errno.*13/i);
      expect(result).toContain('Installation failed');
    });

    test('should_maintain_original_error_messages', () => {
      // GIVEN: Error with technical details
      const error = 'Package ocaml-base-compiler.4.14.0 conflicts with ocaml-variants.4.13.0+options';
      const context = 'dependency resolution';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should maintain specific package information
      expect(result).toContain('ocaml-base-compiler.4.14.0');
      expect(result).toContain('ocaml-variants.4.13.0+options');
      expect(result).toContain('conflicts');
    });

    test('should_include_stack_trace_information_when_relevant', () => {
      // GIVEN: Error with relevant stack trace
      const error = new Error('Function call failed');
      error.stack = `Error: Function call failed
    at handleOpamInstall (/app/lib/opam-manager.js:45:12)
    at processPackage (/app/lib/wrapper.js:123:5)`;
      const context = 'opam package processing';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should include relevant stack information
      expect(result).toContain('Function call failed');
      // Technical details should be preserved but not overwhelming
      expect(result).toBeDefined();
    });

    test('should_balance_user_friendliness_with_technical_accuracy', () => {
      // GIVEN: Technical error that needs both user and developer context
      const error = 'ENOTDIR: not a directory, scandir \'/path/to/file\'';
      const context = 'project structure analysis';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should balance user-friendly explanation with technical accuracy
      expect(result).toMatch(/not.*directory/i);
      expect(result).toMatch(/file.*instead.*of.*directory/i);
      expect(result).toContain('/path/to/file'); // Preserve path for debugging
      expect(result).not.toMatch(/^ENOTDIR:/); // Don't lead with technical code
    });

    test('should_support_different_verbosity_levels', () => {
      // GIVEN: Error that could have different detail levels
      const error = new Error('Complex system error occurred');
      error.details = { code: 'SYS001', module: 'filesystem', operation: 'scan' };
      const context = 'system operation';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should include appropriate level of detail
      expect(result).toContain('Complex system error occurred');
      expect(result).toBeDefined();
      // Should be informative but not overwhelming for typical users
    });

    test('should_preserve_exit_codes_and_process_information', () => {
      // GIVEN: Process error with exit code
      const error = new Error('Process exited with code 1');
      error.code = 1;
      error.signal = null;
      error.cmd = 'opam install dune';
      const context = 'external process execution';
      
      // WHEN: Handling the error
      const result = errorHandler.handleError(error, context);

      // THEN: Should preserve process execution details
      expect(result).toMatch(/exit.*code.*1/i);
      expect(result).toContain('opam install dune');
      expect(result).toContain('Process exited');
    });
  });
});