/**
 * Argument Parser - Test-Driven Development
 *
 * TEST SPECIFICATION:
 * ===================
 * Component: ArgumentParser
 * Interface: parseArgs(args: string[]): { repoUrl: string | null, printConfig: boolean, serverArgs: string[] }
 *
 * REQUIREMENTS COVERAGE:
 * - Req 3.1: Extract `--repo <url>` parameter for opam pin
 * - Req 3.3: Extract `--repo` and forward remaining arguments  
 * - Req 4.1: Detect `--print-config` flag for early exit
 * - Req 5.1: Forward non-wrapper arguments unchanged
 *
 * TEST SCENARIOS:
 * 1. Basic argument parsing edge cases
 * 2. --repo parameter extraction and validation
 * 3. --print-config flag detection
 * 4. Argument forwarding and order preservation
 * 5. Error handling and malformed input
 *
 * IMPLEMENTATION TASKS:
 * - [ ] Write failing tests for basic parsing
 * - [ ] Write failing tests for --repo extraction
 * - [ ] Write failing tests for --print-config detection
 * - [ ] Write failing tests for argument forwarding
 * - [ ] Write failing tests for error scenarios
 *
 * Following TDD Red-Green-Refactor cycle:
 * RED: All tests below MUST FAIL initially (implementation doesn't exist)
 * GREEN: Write minimal code to make tests pass
 * REFACTOR: Improve code while keeping tests green
 */

import { ArgumentParser } from '../argument-parser.js';

describe('ArgumentParser - TDD Specification', () => {
  let argumentParser;

  beforeEach(() => {
    // This will FAIL initially since ArgumentParser doesn't exist
    argumentParser = new ArgumentParser();
  });

  describe('Basic Argument Parsing', () => {
    test('should_parse_empty_arguments_array', () => {
      // GIVEN: Empty arguments array
      const args = [];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should return default structure
      expect(result).toEqual({
        repoUrl: null,
        printConfig: false,
        serverArgs: []
      });
    });

    test('should_parse_arguments_without_wrapper_flags', () => {
      // GIVEN: Arguments without wrapper-specific flags
      const args = ['--port', '3000', '--host', 'localhost'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should forward all arguments to server
      expect(result).toEqual({
        repoUrl: null,
        printConfig: false,
        serverArgs: ['--port', '3000', '--host', 'localhost']
      });
    });

    test('should_handle_undefined_arguments', () => {
      // GIVEN: Undefined input
      const args = undefined;
      
      // WHEN: Parsing arguments
      // THEN: Should throw descriptive error
      expect(() => argumentParser.parseArgs(args)).toThrow(
        'Arguments must be an array'
      );
    });

    test('should_handle_non_array_arguments', () => {
      // GIVEN: Non-array input
      const args = 'not-an-array';
      
      // WHEN: Parsing arguments
      // THEN: Should throw descriptive error
      expect(() => argumentParser.parseArgs(args)).toThrow(
        'Arguments must be an array'
      );
    });
  });

  describe('--repo Parameter Extraction', () => {
    test('should_extract_repo_url_at_beginning', () => {
      // GIVEN: --repo at the beginning of arguments
      const args = ['--repo', 'https://github.com/user/repo.git', '--port', '3000'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should extract repo URL and forward remaining args
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: false,
        serverArgs: ['--port', '3000']
      });
    });

    test('should_extract_repo_url_at_middle', () => {
      // GIVEN: --repo in the middle of arguments
      const args = ['--port', '3000', '--repo', 'https://github.com/user/repo.git', '--host', 'localhost'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should extract repo URL and forward remaining args in order
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: false,
        serverArgs: ['--port', '3000', '--host', 'localhost']
      });
    });

    test('should_extract_repo_url_at_end', () => {
      // GIVEN: --repo at the end of arguments
      const args = ['--port', '3000', '--host', 'localhost', '--repo', 'https://github.com/user/repo.git'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should extract repo URL and forward remaining args
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: false,
        serverArgs: ['--port', '3000', '--host', 'localhost']
      });
    });

    test('should_handle_multiple_repo_arguments_use_last', () => {
      // GIVEN: Multiple --repo arguments
      const args = ['--repo', 'https://github.com/first/repo.git', '--port', '3000', '--repo', 'https://github.com/last/repo.git'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should use the last --repo value
      expect(result).toEqual({
        repoUrl: 'https://github.com/last/repo.git',
        printConfig: false,
        serverArgs: ['--port', '3000']
      });
    });

    test('should_handle_repo_without_value', () => {
      // GIVEN: --repo flag without value
      const args = ['--repo'];
      
      // WHEN: Parsing arguments
      // THEN: Should throw descriptive error
      expect(() => argumentParser.parseArgs(args)).toThrow(
        '--repo requires a repository URL'
      );
    });

    test('should_handle_repo_without_value_at_end', () => {
      // GIVEN: --repo flag without value at end
      const args = ['--port', '3000', '--repo'];
      
      // WHEN: Parsing arguments
      // THEN: Should throw descriptive error
      expect(() => argumentParser.parseArgs(args)).toThrow(
        '--repo requires a repository URL'
      );
    });

    test('should_validate_repository_url_format', () => {
      // GIVEN: Invalid repository URL
      const args = ['--repo', 'not-a-valid-url'];
      
      // WHEN: Parsing arguments
      // THEN: Should throw descriptive error
      expect(() => argumentParser.parseArgs(args)).toThrow(
        'Invalid repository URL format'
      );
    });

    test('should_accept_valid_git_urls', () => {
      const validUrls = [
        'https://github.com/user/repo.git',
        'git@github.com:user/repo.git',
        'https://gitlab.com/user/repo.git',
        'git://github.com/user/repo.git'
      ];

      validUrls.forEach(url => {
        // GIVEN: Valid git URL
        const args = ['--repo', url];
        
        // WHEN: Parsing arguments
        const result = argumentParser.parseArgs(args);
        
        // THEN: Should accept the URL
        expect(result.repoUrl).toBe(url);
      });
    });
  });

  describe('--print-config Flag Detection', () => {
    test('should_detect_print_config_flag_alone', () => {
      // GIVEN: Only --print-config flag
      const args = ['--print-config'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should set printConfig flag
      expect(result).toEqual({
        repoUrl: null,
        printConfig: true,
        serverArgs: []
      });
    });

    test('should_detect_print_config_with_other_args', () => {
      // GIVEN: --print-config with other arguments
      const args = ['--print-config', '--port', '3000'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should set printConfig and forward remaining args
      expect(result).toEqual({
        repoUrl: null,
        printConfig: true,
        serverArgs: ['--port', '3000']
      });
    });

    test('should_detect_print_config_with_repo', () => {
      // GIVEN: --print-config with --repo
      const args = ['--repo', 'https://github.com/user/repo.git', '--print-config'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should set both repoUrl and printConfig
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: true,
        serverArgs: []
      });
    });

    test('should_handle_print_config_in_middle', () => {
      // GIVEN: --print-config in the middle of arguments
      const args = ['--port', '3000', '--print-config', '--host', 'localhost'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should set printConfig and forward remaining args
      expect(result).toEqual({
        repoUrl: null,
        printConfig: true,
        serverArgs: ['--port', '3000', '--host', 'localhost']
      });
    });
  });

  describe('Argument Forwarding and Order Preservation', () => {
    test('should_preserve_server_argument_order', () => {
      // GIVEN: Server arguments in specific order
      const args = ['--alpha', 'value1', '--beta', '--gamma', 'value2'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should preserve exact order
      expect(result.serverArgs).toEqual(['--alpha', 'value1', '--beta', '--gamma', 'value2']);
    });

    test('should_forward_unknown_flags', () => {
      // GIVEN: Unknown flags mixed with wrapper flags
      const args = ['--repo', 'https://github.com/user/repo.git', '--unknown-flag', '--another-unknown'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should forward unknown flags
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: false,
        serverArgs: ['--unknown-flag', '--another-unknown']
      });
    });

    test('should_handle_double_dash_separator', () => {
      // GIVEN: Arguments with explicit server separator
      const args = ['--repo', 'https://github.com/user/repo.git', '--', '--port', '3000', '--repo', 'server-repo'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should extract wrapper args before -- and forward rest
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: false,
        serverArgs: ['--port', '3000', '--repo', 'server-repo']
      });
    });

    test('should_handle_mixed_wrapper_and_server_args', () => {
      // GIVEN: Complex mix of wrapper and server arguments
      const args = [
        '--verbose', 
        '--repo', 'https://github.com/user/repo.git',
        '--port', '3000',
        '--print-config',
        '--host', 'localhost'
      ];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should extract wrapper args and forward the rest
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: true,
        serverArgs: ['--verbose', '--port', '3000', '--host', 'localhost']
      });
    });

    test('should_handle_single_dash_arguments', () => {
      // GIVEN: Single dash arguments
      const args = ['-v', '--repo', 'https://github.com/user/repo.git', '-p', '3000'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should forward single dash args to server
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: false,
        serverArgs: ['-v', '-p', '3000']
      });
    });

    test('should_handle_arguments_with_equals_syntax', () => {
      // GIVEN: Arguments with equals syntax
      const args = ['--repo=https://github.com/user/repo.git', '--port=3000'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should parse equals syntax correctly
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: false,
        serverArgs: ['--port=3000']
      });
    });
  });

  describe('Error Scenarios and Edge Cases', () => {
    test('should_handle_empty_string_arguments', () => {
      // GIVEN: Arguments containing empty strings
      const args = ['', '--repo', 'https://github.com/user/repo.git', ''];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should filter out empty strings
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: false,
        serverArgs: []
      });
    });

    test('should_handle_whitespace_only_arguments', () => {
      // GIVEN: Arguments containing whitespace
      const args = ['   ', '--repo', 'https://github.com/user/repo.git', '\t'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should filter out whitespace-only strings
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: false,
        serverArgs: []
      });
    });

    test('should_handle_special_characters_in_repo_url', () => {
      // GIVEN: Repository URL with special characters
      const args = ['--repo', 'https://github.com/user-name/repo_name.git'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should accept special characters in URLs
      expect(result.repoUrl).toBe('https://github.com/user-name/repo_name.git');
    });

    test('should_reject_invalid_url_schemes', () => {
      // GIVEN: Repository URL with invalid scheme
      const args = ['--repo', 'ftp://invalid.com/repo.git'];
      
      // WHEN: Parsing arguments
      // THEN: Should throw error for invalid scheme
      expect(() => argumentParser.parseArgs(args)).toThrow(
        'Invalid repository URL format'
      );
    });

    test('should_handle_repo_url_with_credentials', () => {
      // GIVEN: Repository URL with embedded credentials
      const args = ['--repo', 'https://user:pass@github.com/user/repo.git'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should accept URL with credentials
      expect(result.repoUrl).toBe('https://user:pass@github.com/user/repo.git');
    });

    test('should_handle_very_long_argument_list', () => {
      // GIVEN: Very long argument list
      const baseArgs = ['--repo', 'https://github.com/user/repo.git'];
      const longArgs = [];
      for (let i = 0; i < 100; i++) {
        longArgs.push(`--arg${i}`, `value${i}`);
      }
      const args = [...baseArgs, ...longArgs];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should handle long argument lists
      expect(result.repoUrl).toBe('https://github.com/user/repo.git');
      expect(result.serverArgs).toHaveLength(200); // 100 pairs
    });

    test('should_handle_conflicting_repo_and_print_config', () => {
      // GIVEN: Both --repo and --print-config (valid combination)
      const args = ['--repo', 'https://github.com/user/repo.git', '--print-config'];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should handle both flags correctly
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: true,
        serverArgs: []
      });
    });
  });

  describe('Integration Test Scenarios', () => {
    test('should_handle_real_world_mcp_server_args', () => {
      // GIVEN: Realistic MCP server arguments
      const args = [
        '--repo', 'https://github.com/ocaml/dune.git',
        '--stdio',
        '--log-level', 'info',
        '--capabilities', 'tools,resources',
        '--timeout', '30000'
      ];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should extract repo and forward server args
      expect(result).toEqual({
        repoUrl: 'https://github.com/ocaml/dune.git',
        printConfig: false,
        serverArgs: ['--stdio', '--log-level', 'info', '--capabilities', 'tools,resources', '--timeout', '30000']
      });
    });

    test('should_handle_npm_style_script_invocation', () => {
      // GIVEN: Arguments that might come from npm script
      const args = [
        'run',
        'server',
        '--repo', 'https://github.com/user/repo.git',
        '--print-config'
      ];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should handle npm-style invocation
      expect(result).toEqual({
        repoUrl: 'https://github.com/user/repo.git',
        printConfig: true,
        serverArgs: ['run', 'server']
      });
    });

    test('should_support_opam_pin_workflow_requirements', () => {
      // GIVEN: Arguments for opam pin workflow (Requirement 3.1)
      const args = [
        '--repo', 'https://github.com/ocaml-community/ocaml-mcp.git#feature-branch',
        '--build-dir', '/tmp/build',
        '--no-cache'
      ];
      
      // WHEN: Parsing arguments
      const result = argumentParser.parseArgs(args);
      
      // THEN: Should extract repo URL with branch for opam pin
      expect(result).toEqual({
        repoUrl: 'https://github.com/ocaml-community/ocaml-mcp.git#feature-branch',
        printConfig: false,
        serverArgs: ['--build-dir', '/tmp/build', '--no-cache']
      });
    });
  });
});