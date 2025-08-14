/**
 * Binary Executor - Test-Driven Development
 *
 * TEST SPECIFICATION:
 * ===================
 * Component: BinaryExecutor
 * Interface: 
 *   - executeServer(serverArgs: string[]): Promise<number>
 *
 * REQUIREMENTS COVERAGE:
 * - Req 5.1: Execute via opam exec -- ocaml-mcp-server with argument forwarding
 * - Req 5.2: Exit code preservation - return child process exit code
 * - Req 5.3: stdio stream inheritance - set stdio: 'inherit' for stream pass-through
 * - Req 5.4: Signal propagation - forward SIGINT/SIGTERM to child process
 *
 * TEST SCENARIOS:
 * 1. Basic Execution Patterns
 *    - Execute with no arguments (minimal case)
 *    - Execute with single server argument
 *    - Execute with multiple server arguments
 *    - Proper opam exec command construction
 *    - Argument order preservation
 *
 * 2. Exit Code Handling
 *    - Return 0 for successful execution
 *    - Return 1 for general failure
 *    - Return 2 for misuse of shell builtin
 *    - Return 126 for command found but not executable
 *    - Return 127 for command not found
 *    - Return 130 for terminated by SIGINT (Ctrl+C)
 *    - Return 143 for terminated by SIGTERM
 *    - Preserve any other child process exit codes
 *
 * 3. Stream Management
 *    - Verify stdio: 'inherit' option is used
 *    - Ensure stdin is passed to child process
 *    - Ensure stdout is passed through from child
 *    - Ensure stderr is passed through from child
 *    - No stream buffering or interference
 *
 * 4. Signal Handling and Propagation
 *    - Forward SIGINT to child process
 *    - Forward SIGTERM to child process
 *    - Handle signal timing correctly
 *    - Child process receives signals before parent
 *    - Proper cleanup after signal propagation
 *    - Handle rapid signal sequences
 *
 * 5. Process Spawn Management
 *    - Use child_process.spawn (not exec) for real-time stream handling
 *    - Proper spawn options configuration
 *    - Handle spawn failures gracefully
 *    - Process cleanup on completion
 *    - Resource management and memory leaks prevention
 *
 * 6. Error Scenarios
 *    - Child process spawn failures (ENOENT, EACCES)
 *    - Command not found (opam or ocaml-mcp-server)
 *    - Permission denied errors
 *    - Process crashes and unexpected termination
 *    - Environment variable issues
 *    - Working directory access problems
 *
 * 7. Integration with opam exec
 *    - Correct opam exec command structure
 *    - Proper -- separator usage
 *    - Environment variable inheritance
 *    - Working directory preservation
 *    - Path resolution through opam environment
 *
 * IMPLEMENTATION TASKS:
 * - [ ] Write failing tests for basic execution with argument forwarding
 * - [ ] Write failing tests for exit code preservation scenarios
 * - [ ] Write failing tests for stdio inheritance verification
 * - [ ] Write failing tests for signal propagation (SIGINT/SIGTERM)
 * - [ ] Write failing tests for process spawn management
 * - [ ] Write failing tests for error handling scenarios
 * - [ ] Write failing tests for opam exec integration
 *
 * Following TDD Red-Green-Refactor cycle:
 * RED: All tests below MUST FAIL initially (BinaryExecutor doesn't exist)
 * GREEN: Write minimal code to make tests pass
 * REFACTOR: Improve code while keeping tests green
 */

import { jest } from '@jest/globals';
import { BinaryExecutor } from '../binary-executor.js';

// Mock child_process.spawn for testing
const mockSpawn = jest.fn();

// Mock process events for signal testing
const mockProcess = {
  on: jest.fn(),
  off: jest.fn(),
  kill: jest.fn(),
  pid: 12345
};

describe('BinaryExecutor - TDD Specification', () => {
  let binaryExecutor;

  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
    
    // Initialize BinaryExecutor instance with mocked spawn function
    binaryExecutor = new BinaryExecutor(mockSpawn);
  });

  describe('Basic Execution Patterns', () => {
    test('should_execute_with_no_arguments_using_opam_exec', async () => {
      // GIVEN: No server arguments provided
      const serverArgs = [];
      
      // Mock child process that exits successfully
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null)); // Success exit
          }
        })
      });

      // WHEN: Executing server with no arguments
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should execute opam exec -- ocaml-mcp-server
      expect(mockSpawn).toHaveBeenCalledWith(
        'opam',
        ['exec', '--', 'ocaml-mcp-server'],
        { stdio: 'inherit' }
      );
      expect(exitCode).toBe(0);
    });

    test('should_execute_with_single_server_argument', async () => {
      // GIVEN: Single server argument
      const serverArgs = ['--help'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing server with single argument
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should forward argument to ocaml-mcp-server
      expect(mockSpawn).toHaveBeenCalledWith(
        'opam',
        ['exec', '--', 'ocaml-mcp-server', '--help'],
        { stdio: 'inherit' }
      );
      expect(exitCode).toBe(0);
    });

    test('should_execute_with_multiple_server_arguments', async () => {
      // GIVEN: Multiple server arguments with various formats
      const serverArgs = ['--verbose', '--port', '3000', '--config', '/path/to/config.json'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing server with multiple arguments
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should preserve argument order and forward all arguments
      expect(mockSpawn).toHaveBeenCalledWith(
        'opam',
        ['exec', '--', 'ocaml-mcp-server', '--verbose', '--port', '3000', '--config', '/path/to/config.json'],
        { stdio: 'inherit' }
      );
      expect(exitCode).toBe(0);
    });

    test('should_handle_arguments_with_spaces_and_special_characters', async () => {
      // GIVEN: Arguments containing spaces and special characters
      const serverArgs = ['--message', 'Hello World!', '--path', '/path with spaces/file.txt', '--regex', '*.js'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing server with special arguments
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should properly handle arguments with spaces and special chars
      expect(mockSpawn).toHaveBeenCalledWith(
        'opam',
        ['exec', '--', 'ocaml-mcp-server', '--message', 'Hello World!', '--path', '/path with spaces/file.txt', '--regex', '*.js'],
        { stdio: 'inherit' }
      );
      expect(exitCode).toBe(0);
    });

    test('should_construct_proper_opam_exec_command_structure', async () => {
      // GIVEN: Any server arguments
      const serverArgs = ['--test'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing server
      await binaryExecutor.executeServer(serverArgs);

      // THEN: Should use correct opam exec structure with -- separator
      const [command, args, options] = mockSpawn.mock.calls[0];
      expect(command).toBe('opam');
      expect(args[0]).toBe('exec');
      expect(args[1]).toBe('--');
      expect(args[2]).toBe('ocaml-mcp-server');
      expect(args.slice(3)).toEqual(serverArgs);
      expect(options).toEqual({ stdio: 'inherit' });
    });
  });

  describe('Exit Code Handling', () => {
    test('should_return_0_for_successful_execution', async () => {
      // GIVEN: Child process exits successfully
      const serverArgs = ['--version'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null)); // Exit code 0
          }
        })
      });

      // WHEN: Executing server
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should return exit code 0
      expect(exitCode).toBe(0);
    });

    test('should_return_1_for_general_failure', async () => {
      // GIVEN: Child process exits with general error
      const serverArgs = ['--invalid-flag'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(1, null)); // Exit code 1
          }
        })
      });

      // WHEN: Executing server with invalid flag
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should return exit code 1
      expect(exitCode).toBe(1);
    });

    test('should_return_127_for_command_not_found', async () => {
      // GIVEN: Child process exits with command not found
      const serverArgs = [];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(127, null)); // Command not found
          }
        })
      });

      // WHEN: Executing server when command not found
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should return exit code 127
      expect(exitCode).toBe(127);
    });

    test('should_return_126_for_permission_denied', async () => {
      // GIVEN: Child process exits with permission denied
      const serverArgs = [];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(126, null)); // Permission denied
          }
        })
      });

      // WHEN: Executing server with permission issues
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should return exit code 126
      expect(exitCode).toBe(126);
    });

    test('should_return_130_for_sigint_termination', async () => {
      // GIVEN: Child process terminated by SIGINT
      const serverArgs = [];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(null, 'SIGINT')); // Terminated by SIGINT
          }
        })
      });

      // WHEN: Server process is terminated by SIGINT
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should return exit code 130 (128 + SIGINT number 2)
      expect(exitCode).toBe(130);
    });

    test('should_return_143_for_sigterm_termination', async () => {
      // GIVEN: Child process terminated by SIGTERM
      const serverArgs = [];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(null, 'SIGTERM')); // Terminated by SIGTERM
          }
        })
      });

      // WHEN: Server process is terminated by SIGTERM
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should return exit code 143 (128 + SIGTERM number 15)
      expect(exitCode).toBe(143);
    });

    test('should_preserve_any_custom_exit_codes', async () => {
      // GIVEN: Child process exits with custom exit codes
      const customExitCodes = [2, 3, 5, 42, 64, 255];
      const serverArgs = [];

      // WHEN/THEN: Testing each custom exit code
      for (const expectedCode of customExitCodes) {
        mockSpawn.mockReturnValue({
          ...mockProcess,
          on: jest.fn((event, callback) => {
            if (event === 'exit') {
              setImmediate(() => callback(expectedCode, null));
            }
          })
        });

        const exitCode = await binaryExecutor.executeServer(serverArgs);
        expect(exitCode).toBe(expectedCode);
        
        jest.clearAllMocks();
      }
    });
  });

  describe('Stream Management', () => {
    test('should_use_stdio_inherit_for_stream_passthrough', async () => {
      // GIVEN: Any execution scenario
      const serverArgs = ['--help'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing server
      await binaryExecutor.executeServer(serverArgs);

      // THEN: Should use stdio: 'inherit' option
      const [, , options] = mockSpawn.mock.calls[0];
      expect(options.stdio).toBe('inherit');
    });

    test('should_not_interfere_with_stdin_stream', async () => {
      // GIVEN: Server execution that might read from stdin
      const serverArgs = ['--interactive'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing interactive server
      await binaryExecutor.executeServer(serverArgs);

      // THEN: Should allow stdin to pass through to child process
      expect(mockSpawn).toHaveBeenCalledWith(
        expect.any(String),
        expect.any(Array),
        expect.objectContaining({ stdio: 'inherit' })
      );
    });

    test('should_not_buffer_stdout_output', async () => {
      // GIVEN: Server that produces streaming output
      const serverArgs = ['--stream-output'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing server with streaming output
      await binaryExecutor.executeServer(serverArgs);

      // THEN: Should use inherit mode to avoid buffering
      const [, , options] = mockSpawn.mock.calls[0];
      expect(options.stdio).toBe('inherit');
      // Inherit mode ensures real-time stdout passthrough
    });

    test('should_not_buffer_stderr_output', async () => {
      // GIVEN: Server that produces error output
      const serverArgs = ['--debug'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing server with debug output
      await binaryExecutor.executeServer(serverArgs);

      // THEN: Should use inherit mode for real-time stderr passthrough
      const [, , options] = mockSpawn.mock.calls[0];
      expect(options.stdio).toBe('inherit');
    });
  });

  describe('Signal Handling and Propagation', () => {
    test('should_forward_sigint_to_child_process', async () => {
      // GIVEN: Child process is running
      const serverArgs = ['--long-running'];
      const mockChild = {
        ...mockProcess,
        kill: jest.fn(),
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            // Don't call callback immediately, simulating long-running process
          }
        })
      };
      
      mockSpawn.mockReturnValue(mockChild);

      // WHEN: Executing server and SIGINT is received
      const executePromise = binaryExecutor.executeServer(serverArgs);
      
      // Simulate SIGINT received by parent process
      const sigintHandler = mockChild.on.mock.calls.find(call => call[0] === 'SIGINT')?.[1];
      expect(sigintHandler).toBeDefined();
      
      // Trigger the SIGINT handler
      if (sigintHandler) {
        sigintHandler();
      }

      // THEN: Should forward SIGINT to child process
      expect(mockChild.kill).toHaveBeenCalledWith('SIGINT');
      
      // Clean up: simulate child exit to resolve promise
      const exitHandler = mockChild.on.mock.calls.find(call => call[0] === 'exit')?.[1];
      if (exitHandler) {
        exitHandler(130, 'SIGINT');
      }
      
      await expect(executePromise).resolves.toBe(130);
    });

    test('should_forward_sigterm_to_child_process', async () => {
      // GIVEN: Child process is running
      const serverArgs = ['--daemon'];
      const mockChild = {
        ...mockProcess,
        kill: jest.fn(),
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            // Don't call callback immediately
          }
        })
      };
      
      mockSpawn.mockReturnValue(mockChild);

      // WHEN: Executing server and SIGTERM is received
      const executePromise = binaryExecutor.executeServer(serverArgs);
      
      // Simulate SIGTERM received
      const sigtermHandler = mockChild.on.mock.calls.find(call => call[0] === 'SIGTERM')?.[1];
      expect(sigtermHandler).toBeDefined();
      
      if (sigtermHandler) {
        sigtermHandler();
      }

      // THEN: Should forward SIGTERM to child process
      expect(mockChild.kill).toHaveBeenCalledWith('SIGTERM');
      
      // Clean up
      const exitHandler = mockChild.on.mock.calls.find(call => call[0] === 'exit')?.[1];
      if (exitHandler) {
        exitHandler(143, 'SIGTERM');
      }
      
      await expect(executePromise).resolves.toBe(143);
    });

    test('should_handle_signal_timing_correctly', async () => {
      // GIVEN: Long-running child process
      const serverArgs = ['--background'];
      const mockChild = {
        ...mockProcess,
        kill: jest.fn(),
        on: jest.fn((event, callback) => {
          // Store callbacks for manual triggering
          mockChild[`${event}Handler`] = callback;
        })
      };
      
      mockSpawn.mockReturnValue(mockChild);

      // WHEN: Executing server and receiving rapid signals
      const executePromise = binaryExecutor.executeServer(serverArgs);
      
      // Simulate rapid signal sequence
      const sigintHandler = mockChild.on.mock.calls.find(call => call[0] === 'SIGINT')?.[1];
      const sigtermHandler = mockChild.on.mock.calls.find(call => call[0] === 'SIGTERM')?.[1];
      
      if (sigintHandler) {
        sigintHandler(); // First SIGINT
      }
      if (sigtermHandler) {
        sigtermHandler(); // Then SIGTERM
      }

      // THEN: Should handle multiple signals properly
      expect(mockChild.kill).toHaveBeenCalledWith('SIGINT');
      expect(mockChild.kill).toHaveBeenCalledWith('SIGTERM');
      expect(mockChild.kill).toHaveBeenCalledTimes(2);
      
      // Clean up
      if (mockChild.exitHandler) {
        mockChild.exitHandler(143, 'SIGTERM');
      }
      
      await expect(executePromise).resolves.toBe(143);
    });

    test('should_cleanup_signal_handlers_after_process_exit', async () => {
      // GIVEN: Child process that exits normally
      const serverArgs = [];
      const mockChild = {
        ...mockProcess,
        kill: jest.fn(),
        off: jest.fn(),
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      };
      
      mockSpawn.mockReturnValue(mockChild);

      // WHEN: Executing server that completes successfully
      await binaryExecutor.executeServer(serverArgs);

      // THEN: Should clean up signal handlers after completion
      expect(mockChild.off).toHaveBeenCalledWith('SIGINT', expect.any(Function));
      expect(mockChild.off).toHaveBeenCalledWith('SIGTERM', expect.any(Function));
    });
  });

  describe('Process Spawn Management', () => {
    test('should_use_spawn_instead_of_exec_for_streaming', async () => {
      // GIVEN: Any server execution
      const serverArgs = ['--output-stream'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing server
      await binaryExecutor.executeServer(serverArgs);

      // THEN: Should use spawn function (not exec) for real-time streaming
      expect(mockSpawn).toHaveBeenCalledTimes(1);
      expect(mockSpawn).toHaveBeenCalledWith(
        expect.any(String),
        expect.any(Array),
        expect.objectContaining({ stdio: 'inherit' })
      );
    });

    test('should_handle_spawn_errors_gracefully', async () => {
      // GIVEN: Spawn fails with ENOENT (command not found)
      const serverArgs = [];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'error') {
            const error = new Error('spawn opam ENOENT');
            error.code = 'ENOENT';
            setImmediate(() => callback(error));
          }
        })
      });

      // WHEN: Attempting to execute with spawn failure
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should handle spawn error and return appropriate exit code
      expect(exitCode).toBe(127); // Command not found exit code
    });

    test('should_handle_spawn_permission_errors', async () => {
      // GIVEN: Spawn fails with EACCES (permission denied)
      const serverArgs = [];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'error') {
            const error = new Error('spawn opam EACCES');
            error.code = 'EACCES';
            setImmediate(() => callback(error));
          }
        })
      });

      // WHEN: Attempting to execute with permission error
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should handle permission error appropriately
      expect(exitCode).toBe(126); // Permission denied exit code
    });

    test('should_properly_configure_spawn_options', async () => {
      // GIVEN: Server execution request
      const serverArgs = ['--config', 'test.json'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing server
      await binaryExecutor.executeServer(serverArgs);

      // THEN: Should configure spawn options correctly
      const [command, args, options] = mockSpawn.mock.calls[0];
      expect(command).toBe('opam');
      expect(Array.isArray(args)).toBe(true);
      expect(options).toEqual(expect.objectContaining({
        stdio: 'inherit'
      }));
    });
  });

  describe('Error Scenarios', () => {
    test('should_handle_opam_command_not_found', async () => {
      // GIVEN: opam command is not available on system
      const serverArgs = [];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'error') {
            const error = new Error('spawn opam ENOENT');
            error.code = 'ENOENT';
            error.path = 'opam';
            setImmediate(() => callback(error));
          }
        })
      });

      // WHEN: Attempting to execute when opam not found
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should handle opam not found error
      expect(exitCode).toBe(127);
    });

    test('should_handle_ocaml_mcp_server_not_found', async () => {
      // GIVEN: opam runs but ocaml-mcp-server not installed
      const serverArgs = [];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(127, null)); // Command not found
          }
        })
      });

      // WHEN: Executing when ocaml-mcp-server not available
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should return command not found exit code
      expect(exitCode).toBe(127);
    });

    test('should_handle_process_crashes', async () => {
      // GIVEN: Child process crashes unexpectedly
      const serverArgs = ['--unstable-mode'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(null, 'SIGSEGV')); // Segmentation fault
          }
        })
      });

      // WHEN: Server process crashes
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should handle crash and return appropriate exit code
      expect(exitCode).toBe(139); // 128 + SIGSEGV (11)
    });

    test('should_handle_environment_variable_issues', async () => {
      // GIVEN: Environment setup problems
      const serverArgs = [];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(1, null)); // General error
          }
        })
      });

      // WHEN: Executing with environment issues
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should handle environment issues gracefully
      expect(exitCode).toBe(1);
    });

    test('should_handle_working_directory_access_problems', async () => {
      // GIVEN: Working directory is not accessible
      const serverArgs = [];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'error') {
            const error = new Error('spawn EACCES');
            error.code = 'EACCES';
            error.errno = -13;
            setImmediate(() => callback(error));
          }
        })
      });

      // WHEN: Attempting to execute with directory access issues
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should handle directory access problems
      expect(exitCode).toBe(126); // Permission denied
    });
  });

  describe('Integration with opam exec', () => {
    test('should_construct_correct_opam_exec_command', async () => {
      // GIVEN: Server execution with arguments
      const serverArgs = ['--port', '8080', '--verbose'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing server
      await binaryExecutor.executeServer(serverArgs);

      // THEN: Should construct proper opam exec command
      expect(mockSpawn).toHaveBeenCalledWith(
        'opam',
        ['exec', '--', 'ocaml-mcp-server', '--port', '8080', '--verbose'],
        { stdio: 'inherit' }
      );
    });

    test('should_preserve_environment_variables', async () => {
      // GIVEN: Server execution that relies on environment
      const serverArgs = ['--env-config'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing server
      await binaryExecutor.executeServer(serverArgs);

      // THEN: Should use default environment inheritance (no env override)
      const [, , options] = mockSpawn.mock.calls[0];
      expect(options.env).toBeUndefined(); // Uses process.env by default
    });

    test('should_preserve_working_directory', async () => {
      // GIVEN: Server execution that uses current working directory
      const serverArgs = ['--cwd-relative'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing server
      await binaryExecutor.executeServer(serverArgs);

      // THEN: Should use current working directory (no cwd override)
      const [, , options] = mockSpawn.mock.calls[0];
      expect(options.cwd).toBeUndefined(); // Uses process.cwd() by default
    });

    test('should_handle_opam_exec_specific_errors', async () => {
      // GIVEN: opam exec fails with specific error patterns
      const serverArgs = [];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            // opam-specific error: no switch set
            setImmediate(() => callback(5, null));
          }
        })
      });

      // WHEN: opam exec fails due to switch issues
      const exitCode = await binaryExecutor.executeServer(serverArgs);

      // THEN: Should preserve opam-specific exit codes
      expect(exitCode).toBe(5);
    });

    test('should_work_with_opam_switch_environments', async () => {
      // GIVEN: Multiple opam switches available
      const serverArgs = ['--switch-aware'];
      
      mockSpawn.mockReturnValue({
        ...mockProcess,
        on: jest.fn((event, callback) => {
          if (event === 'exit') {
            setImmediate(() => callback(0, null));
          }
        })
      });

      // WHEN: Executing in opam switch environment
      await binaryExecutor.executeServer(serverArgs);

      // THEN: Should work with current opam switch
      expect(mockSpawn).toHaveBeenCalledWith(
        'opam',
        expect.arrayContaining(['exec', '--', 'ocaml-mcp-server']),
        expect.objectContaining({ stdio: 'inherit' })
      );
    });
  });
});