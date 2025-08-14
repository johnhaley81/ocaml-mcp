/**
 * Opam Manager - Test-Driven Development
 *
 * TEST SPECIFICATION:
 * ===================
 * Component: OpamManager
 * Interface: 
 *   - isServerInstalled(): Promise<boolean>
 *   - installServer(repoUrl: string): Promise<{ success: boolean, error: string | null }>
 *
 * REQUIREMENTS COVERAGE:
 * - Req 1.2: Install ocaml-mcp-server into current opam switch via `opam pin add`
 * - Req 3.1: Use custom repository URL for opam pin instead of the default
 * - Req 3.2: Fail with clear error message about repository issues
 * - Req 2.1: Check if ocaml-mcp-server is available via `opam list` and execution test
 * - Req 4.1: Handle opam command failures with appropriate exit codes (5, 20, 30, 31, 40)
 * - Req 5.1: Silent installation with no interactive prompts
 * - Req 6.1: Installation timeout handling (< 3 minutes requirement)
 *
 * TEST SCENARIOS:
 * 1. Installation Status Checking
 *    - Package installed and executable available
 *    - Package not installed
 *    - Package installed but executable not working
 *    - Opam command failures during status check
 *
 * 2. Installation via opam pin - Success Cases
 *    - Install with default GitHub repository
 *    - Install with custom HTTPS Git repository
 *    - Install with custom SSH Git repository  
 *    - Install with local path repository
 *    - Silent installation workflow
 *
 * 3. Installation Failure Scenarios
 *    - Network connectivity issues (exit code 40)
 *    - Invalid repository URL (exit code 30)
 *    - Package compilation failures (exit code 31)
 *    - Dependency resolution problems (exit code 20)
 *    - Permission denied issues (exit code 5)
 *    - Opam switch not available
 *    - Repository not accessible
 *
 * 4. Repository URL Handling
 *    - Validate different Git repository formats
 *    - Handle malformed URLs gracefully
 *    - Support branch/tag specifications
 *    - Repository authentication scenarios
 *
 * 5. Process and Environment Management
 *    - Proper opam environment usage
 *    - Timeout handling for long installations
 *    - Concurrent installation request handling
 *    - Cleanup on installation failure
 *
 * 6. Integration Scenarios
 *    - Full installation workflow (pin + install + verify)
 *    - Reinstallation scenarios (already pinned)
 *    - Multiple opam switches environment
 *
 * IMPLEMENTATION TASKS:
 * - [ ] Write failing tests for installation status checking
 * - [ ] Write failing tests for successful opam pin installation
 * - [ ] Write failing tests for installation failure scenarios
 * - [ ] Write failing tests for repository URL validation
 * - [ ] Write failing tests for process and timeout management
 * - [ ] Write failing tests for integration workflows
 *
 * Following TDD Red-Green-Refactor cycle:
 * RED: All tests below MUST FAIL initially (OpamManager doesn't exist)
 * GREEN: Write minimal code to make tests pass
 * REFACTOR: Improve code while keeping tests green
 */

import { jest } from '@jest/globals';
import { OpamManager } from '../opam-manager.js';

// Mock exec function for testing
const mockExec = jest.fn();

describe('OpamManager - TDD Specification', () => {
  let opamManager;

  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
    
    // Initialize OpamManager instance with mocked exec function
    opamManager = new OpamManager(mockExec);
  });

  describe('Installation Status Checking', () => {
    test('should_return_true_when_server_is_installed_and_executable', async () => {
      // GIVEN: ocaml-mcp-server is installed and executable
      mockExec
        .mockImplementationOnce((cmd, callback) => {
          // opam list ocaml-mcp-server - package is listed
          expect(cmd).toContain('opam list ocaml-mcp-server');
          callback(null, 'ocaml-mcp-server  0.1.0  pinned to version 0.1.0', '');
        })
        .mockImplementationOnce((cmd, callback) => {
          // opam exec -- ocaml-mcp-server --help - executable works
          expect(cmd).toContain('opam exec -- ocaml-mcp-server --help');
          callback(null, 'MCP server for OCaml\nUsage: ocaml-mcp-server [options]', '');
        });

      // WHEN: Checking if server is installed
      const result = await opamManager.isServerInstalled();

      // THEN: Should return true
      expect(result).toBe(true);
      expect(mockExec).toHaveBeenCalledTimes(2);
    });

    test('should_return_false_when_package_not_installed', async () => {
      // GIVEN: ocaml-mcp-server is not installed (not in opam list)
      mockExec.mockImplementationOnce((cmd, callback) => {
        expect(cmd).toContain('opam list ocaml-mcp-server');
        callback(null, '', ''); // Empty output means not installed
      });

      // WHEN: Checking if server is installed
      const result = await opamManager.isServerInstalled();

      // THEN: Should return false
      expect(result).toBe(false);
      expect(mockExec).toHaveBeenCalledTimes(1);
    });

    test('should_return_false_when_package_installed_but_executable_not_working', async () => {
      // GIVEN: Package is listed but executable fails
      mockExec
        .mockImplementationOnce((cmd, callback) => {
          // opam list shows package is installed
          callback(null, 'ocaml-mcp-server  0.1.0  pinned', '');
        })
        .mockImplementationOnce((cmd, callback) => {
          // But opam exec fails
          callback(new Error('Command failed'), '', 'ocaml-mcp-server: command not found');
        });

      // WHEN: Checking if server is installed
      const result = await opamManager.isServerInstalled();

      // THEN: Should return false
      expect(result).toBe(false);
    });

    test('should_handle_opam_command_failure_during_status_check', async () => {
      // GIVEN: opam list command fails with exit code 5 (permission denied)
      const error = new Error('Command failed: opam list');
      error.code = 5;
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(error, '', 'opam: Permission denied');
      });

      // WHEN: Checking if server is installed
      const result = await opamManager.isServerInstalled();

      // THEN: Should return false (cannot determine status)
      expect(result).toBe(false);
    });

    test('should_handle_opam_switch_not_available_error', async () => {
      // GIVEN: No opam switch is available (exit code 5)
      const error = new Error('No switch is currently set');
      error.code = 5;
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(error, '', 'No switch is currently set');
      });

      // WHEN: Checking if server is installed
      const result = await opamManager.isServerInstalled();

      // THEN: Should return false
      expect(result).toBe(false);
    });
  });

  describe('Installation via opam pin - Success Cases', () => {
    test('should_install_with_default_github_repository', async () => {
      // GIVEN: Default GitHub repository URL
      const defaultRepoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        // opam pin add ocaml-mcp-server <repo> --yes
        expect(cmd).toContain('opam pin add ocaml-mcp-server');
        expect(cmd).toContain(defaultRepoUrl);
        expect(cmd).toContain('--yes'); // Silent installation
        callback(null, 'Successfully pinned and installed ocaml-mcp-server', '');
      });

      // WHEN: Installing server with default repository
      const result = await opamManager.installServer(defaultRepoUrl);

      // THEN: Should succeed
      expect(result.success).toBe(true);
      expect(result.error).toBe(null);
      expect(mockExec).toHaveBeenCalledTimes(1);
    });

    test('should_install_with_custom_https_git_repository', async () => {
      // GIVEN: Custom HTTPS Git repository URL
      const customRepoUrl = 'https://gitlab.com/example/ocaml-mcp-fork.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        expect(cmd).toContain('opam pin add ocaml-mcp-server');
        expect(cmd).toContain(customRepoUrl);
        expect(cmd).toContain('--yes');
        callback(null, 'ocaml-mcp-server is now pinned to ' + customRepoUrl, '');
      });

      // WHEN: Installing server with custom HTTPS repository
      const result = await opamManager.installServer(customRepoUrl);

      // THEN: Should succeed
      expect(result.success).toBe(true);
      expect(result.error).toBe(null);
    });

    test('should_install_with_custom_ssh_git_repository', async () => {
      // GIVEN: Custom SSH Git repository URL
      const sshRepoUrl = 'git@github.com:user/ocaml-mcp-private.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        expect(cmd).toContain('opam pin add ocaml-mcp-server');
        expect(cmd).toContain(sshRepoUrl);
        expect(cmd).toContain('--yes');
        callback(null, 'Package pinned successfully', '');
      });

      // WHEN: Installing server with SSH repository
      const result = await opamManager.installServer(sshRepoUrl);

      // THEN: Should succeed
      expect(result.success).toBe(true);
      expect(result.error).toBe(null);
    });

    test('should_install_with_local_path_repository', async () => {
      // GIVEN: Local path repository
      const localRepoPath = '/home/user/projects/ocaml-mcp';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        expect(cmd).toContain('opam pin add ocaml-mcp-server');
        expect(cmd).toContain(localRepoPath);
        expect(cmd).toContain('--yes');
        callback(null, 'Successfully pinned to local path', '');
      });

      // WHEN: Installing server with local path
      const result = await opamManager.installServer(localRepoPath);

      // THEN: Should succeed
      expect(result.success).toBe(true);
      expect(result.error).toBe(null);
    });

    test('should_use_silent_installation_with_no_prompts', async () => {
      // GIVEN: Any repository URL
      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        // Should include --yes flag for non-interactive installation
        expect(cmd).toContain('--yes');
        // Should not include any interactive flags
        expect(cmd).not.toContain('--interactive');
        callback(null, 'Installation completed', '');
      });

      // WHEN: Installing server
      const result = await opamManager.installServer(repoUrl);

      // THEN: Should use silent installation
      expect(result.success).toBe(true);
    });
  });

  describe('Installation Failure Scenarios', () => {
    test('should_handle_network_connectivity_issues', async () => {
      // GIVEN: Network connectivity issue (exit code 40)
      const error = new Error('Command failed');
      error.code = 40;
      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(error, '', 'Network unreachable: Failed to connect to github.com');
      });

      // WHEN: Attempting to install server
      const result = await opamManager.installServer(repoUrl);

      // THEN: Should fail with network error
      expect(result.success).toBe(false);
      expect(result.error).toContain('Network');
      expect(result.error).toContain('connectivity');
    });

    test('should_handle_invalid_repository_url', async () => {
      // GIVEN: Invalid repository URL (exit code 30)
      const error = new Error('Command failed');
      error.code = 30;
      const invalidUrl = 'https://invalid-repo-url.example.com/fake.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(error, '', 'Repository not found or access denied');
      });

      // WHEN: Attempting to install server with invalid URL
      const result = await opamManager.installServer(invalidUrl);

      // THEN: Should fail with repository error
      expect(result.success).toBe(false);
      expect(result.error).toContain('Repository');
      expect(result.error).toContain('not found');
    });

    test('should_handle_package_compilation_failures', async () => {
      // GIVEN: Package compilation failure (exit code 31)
      const error = new Error('Command failed');
      error.code = 31;
      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(error, '', 'Compilation failed: Error in dune build\nMissing dependencies: lwt, yojson');
      });

      // WHEN: Attempting to install server
      const result = await opamManager.installServer(repoUrl);

      // THEN: Should fail with compilation error
      expect(result.success).toBe(false);
      expect(result.error).toContain('Compilation failed');
      expect(result.error).toContain('dependencies');
    });

    test('should_handle_dependency_resolution_problems', async () => {
      // GIVEN: Dependency resolution failure (exit code 20)
      const error = new Error('Command failed');
      error.code = 20;
      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(error, '', 'conflict between lwt.5.6.0 and lwt.5.7.0');
      });

      // WHEN: Attempting to install server
      const result = await opamManager.installServer(repoUrl);

      // THEN: Should fail with dependency error
      expect(result.success).toBe(false);
      expect(result.error).toContain('dependencies');
      expect(result.error).toContain('conflict');
    });

    test('should_handle_permission_denied_issues', async () => {
      // GIVEN: Permission denied (exit code 5)
      const error = new Error('Command failed');
      error.code = 5;
      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(error, '', 'Permission denied: Cannot write to opam switch');
      });

      // WHEN: Attempting to install server
      const result = await opamManager.installServer(repoUrl);

      // THEN: Should fail with permission error
      expect(result.success).toBe(false);
      expect(result.error).toContain('Permission denied');
    });

    test('should_handle_opam_switch_not_available', async () => {
      // GIVEN: No opam switch available
      const error = new Error('Command failed');
      error.code = 5;
      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(error, '', 'No switch is currently set. Please create or set a switch first.');
      });

      // WHEN: Attempting to install server
      const result = await opamManager.installServer(repoUrl);

      // THEN: Should fail with switch error
      expect(result.success).toBe(false);
      expect(result.error).toContain('switch');
      expect(result.error).toContain('create or set');
    });

    test('should_handle_repository_authentication_failure', async () => {
      // GIVEN: Repository requires authentication
      const error = new Error('Command failed');
      error.code = 30;
      const privateRepoUrl = 'git@github.com:private/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(error, '', 'Authentication failed: Permission denied (publickey)');
      });

      // WHEN: Attempting to install from private repository
      const result = await opamManager.installServer(privateRepoUrl);

      // THEN: Should fail with authentication error
      expect(result.success).toBe(false);
      expect(result.error).toContain('Authentication failed');
    });
  });

  describe('Repository URL Handling', () => {
    test('should_validate_https_git_repository_format', async () => {
      // GIVEN: Valid HTTPS Git repository URLs
      const validUrls = [
        'https://github.com/user/repo.git',
        'https://gitlab.com/group/project.git',
        'https://bitbucket.org/team/repo.git',
        'https://custom-git.example.com/path/to/repo.git'
      ];

      // Mock successful installation for all URLs
      mockExec.mockImplementation((cmd, callback) => {
        callback(null, 'Installation successful', '');
      });

      // WHEN: Installing with each valid URL
      for (const url of validUrls) {
        const result = await opamManager.installServer(url);
        
        // THEN: Should succeed for valid URLs
        expect(result.success).toBe(true);
      }
    });

    test('should_validate_ssh_git_repository_format', async () => {
      // GIVEN: Valid SSH Git repository URLs
      const validSshUrls = [
        'git@github.com:user/repo.git',
        'git@gitlab.com:group/project.git',
        'ssh://git@bitbucket.org/team/repo.git'
      ];

      mockExec.mockImplementation((cmd, callback) => {
        callback(null, 'Installation successful', '');
      });

      // WHEN: Installing with SSH URLs
      for (const url of validSshUrls) {
        const result = await opamManager.installServer(url);
        
        // THEN: Should succeed for valid SSH URLs
        expect(result.success).toBe(true);
      }
    });

    test('should_handle_malformed_urls_gracefully', async () => {
      // GIVEN: Malformed repository URLs
      const malformedUrls = [
        'not-a-url',
        'http://missing-git-extension.com/repo',
        'https://',
        '',
        null,
        undefined
      ];

      // WHEN: Attempting to install with malformed URLs
      for (const url of malformedUrls) {
        const result = await opamManager.installServer(url);
        
        // THEN: Should fail gracefully with validation error
        expect(result.success).toBe(false);
        expect(result.error).toContain('Invalid repository URL');
      }
    });

    test('should_support_git_urls_with_branch_specifications', async () => {
      // GIVEN: Git URL with branch/tag specification
      const repoUrlWithBranch = 'https://github.com/tmattio/ocaml-mcp.git#feature-branch';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        expect(cmd).toContain(repoUrlWithBranch);
        callback(null, 'Pinned to specific branch', '');
      });

      // WHEN: Installing with branch specification
      const result = await opamManager.installServer(repoUrlWithBranch);

      // THEN: Should handle branch specification
      expect(result.success).toBe(true);
    });
  });

  describe('Process and Environment Management', () => {
    test('should_use_proper_opam_environment_for_installation', async () => {
      // GIVEN: Repository URL for installation
      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        // Should use opam command with proper environment
        expect(cmd).toMatch(/^opam\s+pin\s+add/);
        expect(cmd).toContain('ocaml-mcp-server');
        callback(null, 'Installation successful', '');
      });

      // WHEN: Installing server
      await opamManager.installServer(repoUrl);

      // THEN: Should use proper opam command structure
      expect(mockExec).toHaveBeenCalledWith(
        expect.stringMatching(/opam\s+pin\s+add\s+ocaml-mcp-server/),
        expect.any(Function)
      );
    });

    test('should_handle_installation_timeout', async () => {
      // GIVEN: Long-running installation that times out
      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        // Simulate timeout - don't call callback immediately
        setTimeout(() => {
          const error = new Error('Command timeout');
          error.code = 'TIMEOUT';
          callback(error, '', 'Installation timed out');
        }, 100); // Simulate quick timeout for test
      });

      // WHEN: Installing server with timeout
      const result = await opamManager.installServer(repoUrl);

      // THEN: Should handle timeout gracefully
      expect(result.success).toBe(false);
      expect(result.error).toContain('timeout');
    }, 180000); // Test timeout should be less than 3 minutes

    test('should_handle_concurrent_installation_requests', async () => {
      // GIVEN: Multiple concurrent installation requests
      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      
      mockExec.mockImplementation((cmd, callback) => {
        // Simulate installation delay
        setTimeout(() => {
          callback(null, 'Installation successful', '');
        }, 50);
      });

      // WHEN: Making concurrent installation requests
      const promises = [
        opamManager.installServer(repoUrl),
        opamManager.installServer(repoUrl),
        opamManager.installServer(repoUrl)
      ];
      
      const results = await Promise.all(promises);

      // THEN: Should handle concurrent requests appropriately
      // Note: Implementation should prevent concurrent installations
      // At least one should succeed, others should either succeed or fail gracefully
      const successCount = results.filter(r => r.success).length;
      expect(successCount).toBeGreaterThan(0);
    });

    test('should_cleanup_on_installation_failure', async () => {
      // GIVEN: Installation that fails after partial completion
      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      const error = new Error('Installation failed');
      error.code = 31;
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(error, 'Partially completed installation', 'Build failed during compilation');
      });

      // WHEN: Installation fails
      const result = await opamManager.installServer(repoUrl);

      // THEN: Should cleanup and report failure
      expect(result.success).toBe(false);
      expect(result.error).toContain('Build failed');
    });
  });

  describe('Integration Scenarios', () => {
    test('should_complete_full_installation_workflow', async () => {
      // GIVEN: Complete installation workflow (pin + install + verify)
      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        // opam pin add command
        expect(cmd).toContain('opam pin add ocaml-mcp-server');
        callback(null, 'ocaml-mcp-server is now pinned to ' + repoUrl + '\nBuilding and installing...', '');
      });

      // WHEN: Installing server through full workflow
      const result = await opamManager.installServer(repoUrl);

      // THEN: Should complete successfully
      expect(result.success).toBe(true);
      expect(result.error).toBe(null);
    });

    test('should_handle_reinstallation_of_already_pinned_package', async () => {
      // GIVEN: Package is already pinned to a different URL
      const newRepoUrl = 'https://github.com/fork/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(null, 'ocaml-mcp-server was already pinned, updating to new source\nReinstalling...', '');
      });

      // WHEN: Installing server with different repository
      const result = await opamManager.installServer(newRepoUrl);

      // THEN: Should handle repin/reinstall successfully
      expect(result.success).toBe(true);
    });

    test('should_work_with_multiple_opam_switches', async () => {
      // GIVEN: System with multiple opam switches
      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        // Should work with current switch
        expect(cmd).toContain('opam pin add');
        callback(null, 'Installing in current switch: default\nInstallation successful', '');
      });

      // WHEN: Installing in current switch environment
      const result = await opamManager.installServer(repoUrl);

      // THEN: Should install in current switch
      expect(result.success).toBe(true);
    });

    test('should_validate_real_world_repository_patterns', async () => {
      // GIVEN: Real-world repository URL patterns
      const realWorldUrls = [
        'https://github.com/tmattio/ocaml-mcp.git',
        'https://gitlab.inria.fr/example/ocaml-project.git',
        'git@github.com:organization/private-repo.git',
        '/home/developer/local-projects/ocaml-mcp'
      ];

      mockExec.mockImplementation((cmd, callback) => {
        callback(null, 'Installation successful', '');
      });

      // WHEN: Installing with real-world URL patterns
      for (const url of realWorldUrls) {
        const result = await opamManager.installServer(url);
        
        // THEN: Should handle real-world patterns successfully
        expect(result.success).toBe(true);
      }
    });

    test('should_provide_comprehensive_error_reporting', async () => {
      // GIVEN: Various failure scenarios with detailed error reporting
      const errorScenarios = [
        { code: 5, stderr: 'Permission denied', expectedError: 'Permission denied' },
        { code: 20, stderr: 'conflict between packages', expectedError: 'dependencies' },
        { code: 30, stderr: 'Repository not found', expectedError: 'Repository' },
        { code: 31, stderr: 'Build failure', expectedError: 'Build' },
        { code: 40, stderr: 'Network timeout', expectedError: 'Network' }
      ];

      const repoUrl = 'https://github.com/tmattio/ocaml-mcp.git';

      // WHEN/THEN: Testing each error scenario
      for (const scenario of errorScenarios) {
        const error = new Error('Command failed');
        error.code = scenario.code;
        
        mockExec.mockImplementationOnce((cmd, callback) => {
          callback(error, '', scenario.stderr);
        });

        const result = await opamManager.installServer(repoUrl);
        
        expect(result.success).toBe(false);
        expect(result.error).toContain(scenario.expectedError);
        
        // Reset mock for next iteration
        jest.clearAllMocks();
      }
    });
  });

  describe('Enhanced Diagnostics and Error Handling', () => {
    test('should_run_preflight_checks_successfully', async () => {
      // GIVEN: All preflight checks pass
      mockExec
        .mockImplementationOnce((cmd, callback) => {
          // opam --version
          expect(cmd).toContain('opam --version');
          callback(null, '2.1.0', '');
        })
        .mockImplementationOnce((cmd, callback) => {
          // opam switch show
          expect(cmd).toContain('opam switch show');
          callback(null, 'default', '');
        })
        .mockImplementationOnce((cmd, callback) => {
          // opam repository list
          expect(cmd).toContain('opam repository list');
          callback(null, 'default      https://opam.ocaml.org/', '');
        })
        .mockImplementationOnce((cmd, callback) => {
          // opam show lwt
          callback(null, 'package available', '');
        })
        .mockImplementationOnce((cmd, callback) => {
          // opam show yojson  
          callback(null, 'package available', '');
        })
        .mockImplementationOnce((cmd, callback) => {
          // opam show cmdliner
          callback(null, 'package available', '');
        })
        .mockImplementationOnce((cmd, callback) => {
          // opam show dune
          callback(null, 'package available', '');
        })
        .mockImplementationOnce((cmd, callback) => {
          // ocaml -version
          expect(cmd).toContain('ocaml -version');
          callback(null, 'The OCaml toplevel, version 5.0.0', '');
        });

      // WHEN: Running preflight checks
      const result = await opamManager.runPreflightChecks();

      // THEN: Should succeed with no warnings
      expect(result.success).toBe(true);
      expect(result.error).toBe(null);
      expect(result.warnings).toHaveLength(0);
    });

    test('should_detect_missing_dependencies_in_preflight', async () => {
      // GIVEN: Some dependencies are missing
      mockExec
        .mockImplementationOnce((cmd, callback) => {
          callback(null, '2.1.0', ''); // opam version
        })
        .mockImplementationOnce((cmd, callback) => {
          callback(null, 'default', ''); // switch show
        })
        .mockImplementationOnce((cmd, callback) => {
          callback(null, 'default      https://opam.ocaml.org/', ''); // repo list
        })
        .mockImplementationOnce((cmd, callback) => {
          callback(null, 'package available', ''); // lwt available
        })
        .mockImplementationOnce((cmd, callback) => {
          const error = new Error('Package not found');
          callback(error, '', 'yojson not found'); // yojson missing
        })
        .mockImplementationOnce((cmd, callback) => {
          callback(null, 'package available', ''); // cmdliner available
        })
        .mockImplementationOnce((cmd, callback) => {
          const error = new Error('Package not found');
          callback(error, '', 'dune not found'); // dune missing
        })
        .mockImplementationOnce((cmd, callback) => {
          callback(null, 'The OCaml toplevel, version 5.0.0', '');
        });

      // WHEN: Running preflight checks
      const result = await opamManager.runPreflightChecks();

      // THEN: Should succeed but with warnings about missing packages
      expect(result.success).toBe(true);
      expect(result.warnings).toContain(
        expect.stringContaining('Core dependencies not found in repository: yojson, dune')
      );
    });

    test('should_fail_preflight_when_opam_not_available', async () => {
      // GIVEN: OPAM is not installed
      mockExec.mockImplementationOnce((cmd, callback) => {
        const error = new Error('Command not found');
        error.code = 127;
        callback(error, '', 'opam: command not found');
      });

      // WHEN: Running preflight checks
      const result = await opamManager.runPreflightChecks();

      // THEN: Should fail with OPAM installation error
      expect(result.success).toBe(false);
      expect(result.error).toContain('OPAM is not installed');
    });

    test('should_auto_update_repository_when_dependencies_missing', async () => {
      // GIVEN: Missing dependencies trigger auto-update
      const consoleLogSpy = jest.spyOn(console, 'log').mockImplementation();
      const consoleWarnSpy = jest.spyOn(console, 'warn').mockImplementation();
      
      // Mock preflight checks with missing deps
      opamManager.runPreflightChecks = jest.fn().mockResolvedValue({
        success: true,
        error: null,
        warnings: ['Core dependencies not found in repository: yojson']
      });
      
      // Mock repository update
      opamManager.updateRepository = jest.fn().mockResolvedValue({
        success: true,
        error: null
      });
      
      // Mock installation success
      mockExec.mockImplementationOnce((cmd, callback) => {
        expect(cmd).toContain('opam pin add ocaml-mcp-server');
        callback(null, 'Installation successful', '');
      });

      // WHEN: Installing with missing dependencies
      const result = await opamManager.installServer('https://github.com/test/repo.git');

      // THEN: Should auto-update repository and succeed
      expect(opamManager.updateRepository).toHaveBeenCalled();
      expect(consoleLogSpy).toHaveBeenCalledWith(expect.stringContaining('Missing dependencies detected'));
      expect(result.success).toBe(true);
      
      consoleLogSpy.mockRestore();
      consoleWarnSpy.mockRestore();
    });

    test('should_provide_enhanced_error_messages_for_dependency_conflicts', async () => {
      // GIVEN: Dependency resolution failure with specific packages
      opamManager.runPreflightChecks = jest.fn().mockResolvedValue({
        success: true,
        error: null,
        warnings: []
      });
      
      const error = new Error('Command failed');
      error.code = 20;
      const stderr = 'Package conflict: lwt.5.7.0 required but lwt.5.5.0 installed';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(error, '', stderr);
      });

      // WHEN: Installation fails with dependency conflict
      const result = await opamManager.installServer('https://github.com/test/repo.git');

      // THEN: Should provide enhanced error message with solutions
      expect(result.success).toBe(false);
      expect(result.error).toContain('❌ Cannot resolve package dependencies');
      expect(result.error).toContain('🔧 Solutions');
      expect(result.error).toContain('opam update');
      expect(result.error).toContain('opam upgrade');
      expect(result.error).toContain('Docker fallback');
    });

    test('should_extract_missing_packages_from_error_message', async () => {
      // GIVEN: Error message with specific missing packages
      const stderr = `Error: Package lwt not found\nRequires yojson >= 2.0\nMissing dependency cmdliner`;
      
      // WHEN: Extracting missing packages
      const packages = opamManager._extractMissingPackages(stderr);
      
      // THEN: Should identify specific packages
      expect(packages).toContain('lwt');
      expect(packages).toContain('yojson');
      expect(packages).toContain('cmdliner');
    });

    test('should_provide_git_auth_solutions_for_ssh_failures', async () => {
      // GIVEN: SSH authentication failure
      opamManager.runPreflightChecks = jest.fn().mockResolvedValue({
        success: true,
        error: null,
        warnings: []
      });
      
      const error = new Error('Command failed');
      error.code = 30;
      const stderr = 'Authentication failed: Permission denied (publickey)';
      const repoUrl = 'git@github.com:user/repo.git';
      
      mockExec.mockImplementationOnce((cmd, callback) => {
        callback(error, '', stderr);
      });

      // WHEN: Installation fails with SSH auth error
      const result = await opamManager.installServer(repoUrl);

      // THEN: Should provide SSH-specific solutions
      expect(result.success).toBe(false);
      expect(result.error).toContain('❌ Git authentication failed');
      expect(result.error).toContain('ssh -T git@github.com');
      expect(result.error).toContain('https://github.com/user/repo.git');
      expect(result.error).toContain('ssh-keygen');
    });
  });
});