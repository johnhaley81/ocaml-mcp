/**
 * Config Generator - Test-Driven Development
 *
 * TEST SPECIFICATION:
 * ===================
 * Component: ConfigGenerator
 * Interface: 
 *   - generateConfig(repoUrl?: string): object
 *
 * REQUIREMENTS COVERAGE:
 * - Req 4.1: Generate valid MCP JSON structure with proper mcpServers section
 * - Req 4.3: Include workspace folder variables for proper working directory
 * - Req 4.4: Handle optional --repo parameter in generated configuration
 *
 * TEST SCENARIOS:
 * 1. Basic MCP Configuration Generation
 *    - Generate valid MCP structure without repo URL
 *    - Proper mcpServers section with server entry
 *    - NPX command structure: ["npx", "@ocaml-mcp/server"]
 *    - Valid JSON schema compliance
 *    - Required MCP fields present
 *
 * 2. Repository URL Integration
 *    - Include --repo parameter when URL provided
 *    - Exclude --repo when URL is null/undefined
 *    - Handle GitHub URLs (https://github.com/user/repo)
 *    - Handle GitLab URLs (https://gitlab.com/user/repo)
 *    - Handle SSH URLs (git@github.com:user/repo.git)
 *    - Handle local repository paths (/path/to/repo)
 *    - Handle repository URLs with special characters
 *
 * 3. Workspace Integration
 *    - Include workspace folder variables (${workspaceFolder})
 *    - Proper working directory configuration
 *    - Environment-specific path handling
 *    - Template variable substitution support
 *
 * 4. JSON Structure Validation
 *    - Valid JSON object structure
 *    - Proper array and object nesting
 *    - String values properly quoted
 *    - No circular references
 *    - Serializable to JSON string
 *
 * 5. Edge Cases and Error Handling
 *    - Empty string repository URLs
 *    - Null and undefined repository URLs
 *    - URLs with spaces and special characters
 *    - Very long repository URLs
 *    - Malformed repository URLs
 *    - Invalid characters in server names
 *
 * 6. MCP Protocol Compliance
 *    - Proper mcpServers object structure
 *    - Server entries with command arrays
 *    - Optional args arrays for parameters
 *    - Working directory specification
 *    - Server naming conventions
 *
 * IMPLEMENTATION TASKS:
 * - [ ] Write failing tests for basic MCP configuration generation
 * - [ ] Write failing tests for NPX command structure verification
 * - [ ] Write failing tests for repository URL parameter inclusion
 * - [ ] Write failing tests for workspace folder variable integration
 * - [ ] Write failing tests for JSON structure validation
 * - [ ] Write failing tests for edge cases and error scenarios
 * - [ ] Write failing tests for MCP protocol compliance
 *
 * Following TDD Red-Green-Refactor cycle:
 * RED: All tests below MUST FAIL initially (ConfigGenerator doesn't exist)
 * GREEN: Write minimal code to make tests pass
 * REFACTOR: Improve code while keeping tests green
 */

import { jest } from '@jest/globals';
import { ConfigGenerator } from '../config-generator.js';

describe('ConfigGenerator - TDD Specification', () => {
  let configGenerator;

  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
    
    // Initialize ConfigGenerator instance
    configGenerator = new ConfigGenerator();
  });

  describe('Basic MCP Configuration Generation', () => {
    test('should_generate_valid_mcp_structure_without_repo_url', () => {
      // GIVEN: No repository URL provided
      const repoUrl = undefined;
      
      // WHEN: Generating MCP configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should generate valid MCP structure
      expect(config).toBeDefined();
      expect(config).toBeInstanceOf(Object);
      expect(config.mcpServers).toBeDefined();
      expect(typeof config.mcpServers).toBe('object');
    });

    test('should_include_proper_mcpservers_section', () => {
      // GIVEN: Configuration generation request
      const repoUrl = undefined;
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should have proper mcpServers section structure
      expect(config.mcpServers).toBeInstanceOf(Object);
      expect(Object.keys(config.mcpServers)).toHaveLength(1);
      
      // Should have a server entry
      const serverName = Object.keys(config.mcpServers)[0];
      expect(serverName).toBe('ocaml-mcp-server');
    });

    test('should_use_npx_command_structure', () => {
      // GIVEN: Configuration generation without repo
      const repoUrl = undefined;
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should use NPX command structure
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.command).toEqual(['npx', '@ocaml-mcp/server']);
      expect(Array.isArray(serverConfig.command)).toBe(true);
      expect(serverConfig.command[0]).toBe('npx');
      expect(serverConfig.command[1]).toBe('@ocaml-mcp/server');
    });

    test('should_have_empty_args_array_without_repo', () => {
      // GIVEN: No repository URL provided
      const repoUrl = undefined;
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should have empty args array
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).toEqual([]);
      expect(Array.isArray(serverConfig.args)).toBe(true);
      expect(serverConfig.args.length).toBe(0);
    });

    test('should_include_required_mcp_fields', () => {
      // GIVEN: Configuration generation request
      const repoUrl = undefined;
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should include all required MCP fields
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig).toHaveProperty('command');
      expect(serverConfig).toHaveProperty('args');
      expect(serverConfig).toHaveProperty('cwd');
      
      // Verify field types
      expect(Array.isArray(serverConfig.command)).toBe(true);
      expect(Array.isArray(serverConfig.args)).toBe(true);
      expect(typeof serverConfig.cwd).toBe('string');
    });

    test('should_generate_serializable_json', () => {
      // GIVEN: Configuration generation
      const repoUrl = undefined;
      
      // WHEN: Generating and serializing configuration
      const config = configGenerator.generateConfig(repoUrl);
      
      // THEN: Should be serializable to JSON
      expect(() => JSON.stringify(config)).not.toThrow();
      
      const jsonString = JSON.stringify(config);
      expect(typeof jsonString).toBe('string');
      expect(jsonString.length).toBeGreaterThan(0);
      
      // Should be parseable back to object
      const parsedConfig = JSON.parse(jsonString);
      expect(parsedConfig).toEqual(config);
    });
  });

  describe('Repository URL Integration', () => {
    test('should_include_repo_parameter_when_url_provided', () => {
      // GIVEN: Repository URL provided
      const repoUrl = 'https://github.com/user/repo';
      
      // WHEN: Generating configuration with repo URL
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should include --repo parameter in args
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).toContain('--repo');
      expect(serverConfig.args).toContain(repoUrl);
      expect(serverConfig.args.indexOf('--repo')).toBe(serverConfig.args.indexOf(repoUrl) - 1);
    });

    test('should_exclude_repo_parameter_when_url_is_null', () => {
      // GIVEN: Null repository URL
      const repoUrl = null;
      
      // WHEN: Generating configuration with null repo
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should not include --repo parameter
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).not.toContain('--repo');
      expect(serverConfig.args).toEqual([]);
    });

    test('should_exclude_repo_parameter_when_url_is_undefined', () => {
      // GIVEN: Undefined repository URL
      const repoUrl = undefined;
      
      // WHEN: Generating configuration with undefined repo
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should not include --repo parameter
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).not.toContain('--repo');
      expect(serverConfig.args.length).toBe(0);
    });

    test('should_handle_github_https_urls', () => {
      // GIVEN: GitHub HTTPS URL
      const repoUrl = 'https://github.com/ocaml/ocaml';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should properly include GitHub URL
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).toEqual(['--repo', repoUrl]);
    });

    test('should_handle_gitlab_https_urls', () => {
      // GIVEN: GitLab HTTPS URL
      const repoUrl = 'https://gitlab.com/user/project';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should properly include GitLab URL
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).toEqual(['--repo', repoUrl]);
    });

    test('should_handle_ssh_git_urls', () => {
      // GIVEN: SSH Git URL
      const repoUrl = 'git@github.com:user/repo.git';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should properly include SSH URL
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).toEqual(['--repo', repoUrl]);
    });

    test('should_handle_local_repository_paths', () => {
      // GIVEN: Local repository path
      const repoUrl = '/path/to/local/repo';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should properly include local path
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).toEqual(['--repo', repoUrl]);
    });

    test('should_handle_urls_with_special_characters', () => {
      // GIVEN: URL with special characters
      const repoUrl = 'https://github.com/user/my-repo_v2.0';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should properly handle special characters
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).toEqual(['--repo', repoUrl]);
    });

    test('should_handle_empty_string_repo_url', () => {
      // GIVEN: Empty string repository URL
      const repoUrl = '';
      
      // WHEN: Generating configuration with empty string
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should treat as no repo URL
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).toEqual([]);
    });

    test('should_preserve_exact_repo_url_format', () => {
      // GIVEN: Various repo URL formats
      const testUrls = [
        'https://github.com/user/repo',
        'git@gitlab.com:group/project.git',
        '/Users/dev/workspace/project',
        'file:///absolute/path/to/repo',
        'https://bitbucket.org/team/repo.git'
      ];
      
      // WHEN/THEN: Each URL should be preserved exactly
      testUrls.forEach(repoUrl => {
        const config = configGenerator.generateConfig(repoUrl);
        const serverConfig = config.mcpServers['ocaml-mcp-server'];
        expect(serverConfig.args).toEqual(['--repo', repoUrl]);
      });
    });
  });

  describe('Workspace Integration', () => {
    test('should_include_workspace_folder_variable_in_cwd', () => {
      // GIVEN: Configuration generation
      const repoUrl = undefined;
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should include workspace folder variable
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.cwd).toBe('${workspaceFolder}');
    });

    test('should_set_proper_working_directory_configuration', () => {
      // GIVEN: Any configuration scenario
      const repoUrl = 'https://github.com/user/repo';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should have proper working directory setup
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig).toHaveProperty('cwd');
      expect(typeof serverConfig.cwd).toBe('string');
      expect(serverConfig.cwd).toContain('workspaceFolder');
    });

    test('should_support_workspace_template_variable_format', () => {
      // GIVEN: Configuration generation request
      const repoUrl = undefined;
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should use proper template variable format
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.cwd).toMatch(/^\$\{workspaceFolder\}$/);
      expect(serverConfig.cwd.startsWith('${') && serverConfig.cwd.endsWith('}')).toBe(true);
    });

    test('should_maintain_workspace_variable_with_repo_url', () => {
      // GIVEN: Configuration with repository URL
      const repoUrl = 'https://github.com/test/project';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should maintain workspace variable regardless of repo URL
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.cwd).toBe('${workspaceFolder}');
      expect(serverConfig.args).toContain('--repo');
    });
  });

  describe('JSON Structure Validation', () => {
    test('should_generate_valid_json_object_structure', () => {
      // GIVEN: Configuration generation
      const repoUrl = 'https://github.com/user/repo';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should have valid JSON object structure
      expect(typeof config).toBe('object');
      expect(config).not.toBeNull();
      expect(Array.isArray(config)).toBe(false);
      expect(config.constructor).toBe(Object);
    });

    test('should_have_proper_array_and_object_nesting', () => {
      // GIVEN: Configuration generation
      const repoUrl = 'https://github.com/user/repo';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should have proper nesting structure
      expect(typeof config.mcpServers).toBe('object');
      expect(Array.isArray(config.mcpServers)).toBe(false);
      
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(Array.isArray(serverConfig.command)).toBe(true);
      expect(Array.isArray(serverConfig.args)).toBe(true);
      expect(typeof serverConfig.cwd).toBe('string');
    });

    test('should_have_string_values_properly_typed', () => {
      // GIVEN: Configuration generation
      const repoUrl = 'https://github.com/user/repo';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should have proper string typing
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      serverConfig.command.forEach(item => {
        expect(typeof item).toBe('string');
      });
      serverConfig.args.forEach(item => {
        expect(typeof item).toBe('string');
      });
      expect(typeof serverConfig.cwd).toBe('string');
    });

    test('should_not_contain_circular_references', () => {
      // GIVEN: Configuration generation
      const repoUrl = undefined;
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should not contain circular references
      expect(() => JSON.stringify(config)).not.toThrow();
      
      // Verify no circular structure
      const visited = new WeakSet();
      const checkCircular = (obj) => {
        if (typeof obj === 'object' && obj !== null) {
          expect(visited.has(obj)).toBe(false);
          visited.add(obj);
          Object.values(obj).forEach(checkCircular);
        }
      };
      
      expect(() => checkCircular(config)).not.toThrow();
    });

    test('should_round_trip_through_json_serialization', () => {
      // GIVEN: Generated configuration
      const repoUrl = 'https://github.com/user/repo';
      const config = configGenerator.generateConfig(repoUrl);
      
      // WHEN: Serializing and parsing back
      const jsonString = JSON.stringify(config);
      const parsedConfig = JSON.parse(jsonString);

      // THEN: Should maintain exact structure
      expect(parsedConfig).toEqual(config);
      expect(parsedConfig.mcpServers).toEqual(config.mcpServers);
      expect(parsedConfig.mcpServers['ocaml-mcp-server']).toEqual(config.mcpServers['ocaml-mcp-server']);
    });
  });

  describe('Edge Cases and Error Handling', () => {
    test('should_handle_very_long_repository_urls', () => {
      // GIVEN: Very long repository URL
      const longPath = 'a'.repeat(500);
      const repoUrl = `https://github.com/user/${longPath}`;
      
      // WHEN: Generating configuration with long URL
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should handle long URLs properly
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).toContain('--repo');
      expect(serverConfig.args).toContain(repoUrl);
    });

    test('should_handle_urls_with_spaces', () => {
      // GIVEN: Repository URL with spaces
      const repoUrl = '/path/with spaces/to/repo';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should preserve spaces in URL
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).toEqual(['--repo', repoUrl]);
    });

    test('should_handle_urls_with_unicode_characters', () => {
      // GIVEN: Repository URL with Unicode characters
      const repoUrl = 'https://github.com/用户/项目';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should preserve Unicode characters
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).toEqual(['--repo', repoUrl]);
    });

    test('should_handle_malformed_but_provided_urls', () => {
      // GIVEN: Malformed but non-empty URLs
      const malformedUrls = [
        'not-a-url',
        '://missing-scheme',
        'https://',
        'file:///',
        'just-text-no-protocol'
      ];
      
      // WHEN/THEN: Should include malformed URLs as provided
      malformedUrls.forEach(repoUrl => {
        const config = configGenerator.generateConfig(repoUrl);
        const serverConfig = config.mcpServers['ocaml-mcp-server'];
        expect(serverConfig.args).toEqual(['--repo', repoUrl]);
      });
    });

    test('should_handle_whitespace_only_repo_urls', () => {
      // GIVEN: Whitespace-only repository URL
      const repoUrl = '   ';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should treat as no repo URL (after trimming)
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.args).toEqual([]);
    });

    test('should_maintain_consistent_output_structure', () => {
      // GIVEN: Various input scenarios
      const testCases = [
        undefined,
        null,
        '',
        'https://github.com/user/repo',
        '/local/path',
        'git@host:repo.git'
      ];
      
      // WHEN/THEN: Should maintain consistent structure across all cases
      testCases.forEach(repoUrl => {
        const config = configGenerator.generateConfig(repoUrl);
        
        // Consistent structure verification
        expect(config).toHaveProperty('mcpServers');
        expect(config.mcpServers).toHaveProperty('ocaml-mcp-server');
        
        const serverConfig = config.mcpServers['ocaml-mcp-server'];
        expect(serverConfig).toHaveProperty('command');
        expect(serverConfig).toHaveProperty('args');
        expect(serverConfig).toHaveProperty('cwd');
        expect(serverConfig.command).toEqual(['npx', '@ocaml-mcp/server']);
        expect(serverConfig.cwd).toBe('${workspaceFolder}');
      });
    });
  });

  describe('MCP Protocol Compliance', () => {
    test('should_follow_mcp_server_configuration_schema', () => {
      // GIVEN: Configuration generation
      const repoUrl = 'https://github.com/user/repo';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should follow MCP server configuration schema
      expect(config).toHaveProperty('mcpServers');
      
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig).toHaveProperty('command');
      expect(serverConfig).toHaveProperty('args');
      expect(serverConfig).toHaveProperty('cwd');
      
      // Verify data types according to MCP schema
      expect(Array.isArray(serverConfig.command)).toBe(true);
      expect(Array.isArray(serverConfig.args)).toBe(true);
      expect(typeof serverConfig.cwd).toBe('string');
    });

    test('should_use_proper_server_naming_convention', () => {
      // GIVEN: Configuration generation
      const repoUrl = undefined;
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should use proper server naming
      const serverNames = Object.keys(config.mcpServers);
      expect(serverNames).toHaveLength(1);
      expect(serverNames[0]).toBe('ocaml-mcp-server');
      expect(serverNames[0]).toMatch(/^[a-z0-9-]+$/); // Valid server name pattern
    });

    test('should_have_executable_command_array', () => {
      // GIVEN: Configuration generation
      const repoUrl = undefined;
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should have valid executable command
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(serverConfig.command.length).toBeGreaterThan(0);
      expect(serverConfig.command[0]).toBe('npx'); // Executable command
      expect(typeof serverConfig.command[0]).toBe('string');
    });

    test('should_have_valid_args_array_structure', () => {
      // GIVEN: Configuration with repository URL
      const repoUrl = 'https://github.com/user/repo';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should have valid args array structure
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      expect(Array.isArray(serverConfig.args)).toBe(true);
      
      // Args should be strings if present
      serverConfig.args.forEach(arg => {
        expect(typeof arg).toBe('string');
        expect(arg.length).toBeGreaterThan(0); // No empty strings in args
      });
    });

    test('should_support_claude_desktop_mcp_config_format', () => {
      // GIVEN: Configuration for Claude Desktop
      const repoUrl = 'https://github.com/user/repo';
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should be compatible with Claude Desktop MCP config format
      expect(config).toHaveProperty('mcpServers');
      
      // Verify Claude Desktop compatibility
      const expectedStructure = {
        mcpServers: {
          'ocaml-mcp-server': {
            command: expect.any(Array),
            args: expect.any(Array),
            cwd: expect.any(String)
          }
        }
      };
      
      expect(config).toMatchObject(expectedStructure);
    });

    test('should_generate_mcp_config_without_extra_fields', () => {
      // GIVEN: Clean configuration generation
      const repoUrl = undefined;
      
      // WHEN: Generating configuration
      const config = configGenerator.generateConfig(repoUrl);

      // THEN: Should only have required MCP fields
      const allowedTopLevelKeys = ['mcpServers'];
      const actualKeys = Object.keys(config);
      expect(actualKeys).toEqual(expect.arrayContaining(allowedTopLevelKeys));
      expect(actualKeys.length).toBe(allowedTopLevelKeys.length);
      
      const serverConfig = config.mcpServers['ocaml-mcp-server'];
      const allowedServerKeys = ['command', 'args', 'cwd'];
      const actualServerKeys = Object.keys(serverConfig);
      expect(actualServerKeys.sort()).toEqual(allowedServerKeys.sort());
    });
  });
});