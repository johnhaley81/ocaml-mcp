/**
 * Project Detector - Test-Driven Development
 *
 * TEST SPECIFICATION:
 * ===================
 * Component: ProjectDetector
 * Interface: 
 *   - detectProject(cwd: string): Promise<{ success: boolean, projectRoot: string | null, error: string | null }>
 *   - validateEnvironment(): Promise<{ success: boolean, opamAvailable: boolean, error: string | null }>
 *
 * REQUIREMENTS COVERAGE:
 * - Req 2.1: Search for `dune-project` or `*.opam` files in current directory and up to 2 levels deep
 * - Req 2.2: Exit with clear error message if no OCaml project markers found
 * - Req 2.3: Verify opam is installed and accessible in PATH
 *
 * TEST SCENARIOS:
 * 1. Project Detection - Success Cases
 *    - Detect project with dune-project in current directory
 *    - Detect project with *.opam files (single and multiple)
 *    - Find project markers up to 2 levels deep
 *    - Handle projects with both dune-project and *.opam files
 *    - Return correct project root path
 *
 * 2. Project Detection - Failure Cases
 *    - No OCaml markers in directory tree
 *    - OCaml markers beyond 2 levels deep (should not detect)
 *    - Empty directories
 *    - Non-existent directories
 *    - Permission denied scenarios
 *
 * 3. Environment Validation - Success Cases
 *    - Opam available in PATH
 *    - Opam working correctly with version check
 *    - Valid opam switch environment
 *
 * 4. Environment Validation - Failure Cases
 *    - Opam not installed
 *    - Opam in PATH but not executable
 *    - Opam installed but no valid switch
 *
 * 5. File System Edge Cases
 *    - Symbolic links to project files
 *    - Case sensitivity on different platforms
 *    - Special characters in directory names
 *    - Very deep directory structures
 *
 * 6. Integration Scenarios
 *    - Real OCaml project structures (dune + opam)
 *    - Mixed project types (some valid, some invalid markers)
 *    - Nested OCaml projects (monorepo scenarios)
 *
 * IMPLEMENTATION TASKS:
 * - [ ] Write failing tests for dune-project detection
 * - [ ] Write failing tests for *.opam file detection  
 * - [ ] Write failing tests for multi-level directory search
 * - [ ] Write failing tests for project detection failures
 * - [ ] Write failing tests for opam environment validation
 * - [ ] Write failing tests for edge cases and error scenarios
 *
 * Following TDD Red-Green-Refactor cycle:
 * RED: All tests below MUST FAIL initially (implementation doesn't exist)
 * GREEN: Write minimal code to make tests pass
 * REFACTOR: Improve code while keeping tests green
 */

import { ProjectDetector } from '../project-detector.js';

describe('ProjectDetector - TDD Specification', () => {
  let projectDetector;

  beforeEach(() => {
    // This will FAIL initially since ProjectDetector doesn't exist
    projectDetector = new ProjectDetector();
  });

  describe('Project Detection - Success Cases', () => {
    test('should_detect_dune_project_in_current_directory', async () => {
      // GIVEN: Current directory contains dune-project file
      const testDir = '/test/project';

      // WHEN: Detecting project in current directory
      const result = await projectDetector.detectProject(testDir);

      // THEN: Should successfully detect project
      // Note: This WILL FAIL since ProjectDetector doesn't exist
      expect(result.success).toBe(true);
      expect(result.projectRoot).toBe(testDir);
      expect(result.error).toBe(null);
    });

    test('should_detect_single_opam_file_in_current_directory', async () => {
      // GIVEN: Current directory contains single .opam file
      const testDir = '/test/project';

      // WHEN: Detecting project in current directory
      const result = await projectDetector.detectProject(testDir);

      // THEN: Should successfully detect project
      expect(result.success).toBe(true);
      expect(result.projectRoot).toBe(testDir);
      expect(result.error).toBe(null);
    });

    test('should_detect_multiple_opam_files_in_current_directory', async () => {
      // GIVEN: Current directory contains multiple .opam files
      const testDir = '/test/monorepo';

      // WHEN: Detecting project in current directory
      const result = await projectDetector.detectProject(testDir);

      // THEN: Should successfully detect project
      expect(result.success).toBe(true);
      expect(result.projectRoot).toBe(testDir);
      expect(result.error).toBe(null);
    });

    test('should_find_dune_project_up_to_2_levels_deep', async () => {
      // GIVEN: dune-project exists 2 levels up from starting directory
      const startDir = '/test/project/src/lib';
      const projectRoot = '/test/project';

      // WHEN: Detecting project from deep directory
      const result = await projectDetector.detectProject(startDir);

      // THEN: Should find project root 2 levels up
      expect(result.success).toBe(true);
      expect(result.projectRoot).toBe(projectRoot);
      expect(result.error).toBe(null);
    });

    test('should_prefer_dune_project_over_opam_files', async () => {
      // GIVEN: Directory contains both dune-project and .opam files
      const testDir = '/test/project';

      // WHEN: Detecting project
      const result = await projectDetector.detectProject(testDir);

      // THEN: Should detect project successfully
      expect(result.success).toBe(true);
      expect(result.projectRoot).toBe(testDir);
      expect(result.error).toBe(null);
    });

    test('should_return_absolute_project_root_path', async () => {
      // GIVEN: Relative path input but dune-project found
      const relativeDir = './project';
      const absoluteDir = '/absolute/path/to/project';

      // WHEN: Detecting project with relative path
      const result = await projectDetector.detectProject(relativeDir);

      // THEN: Should return absolute path
      expect(result.success).toBe(true);
      expect(result.projectRoot).toBe(absoluteDir);
      expect(result.error).toBe(null);
    });
  });

  describe('Project Detection - Failure Cases', () => {
    test('should_fail_when_no_ocaml_markers_found', async () => {
      // GIVEN: No OCaml project markers in directory tree
      const testDir = '/test/empty';

      // WHEN: Detecting project
      const result = await projectDetector.detectProject(testDir);

      // THEN: Should fail with clear error message
      expect(result.success).toBe(false);
      expect(result.projectRoot).toBe(null);
      expect(result.error).toContain('No OCaml project found');
      expect(result.error).toContain('dune-project');
      expect(result.error).toContain('.opam');
    });

    test('should_not_detect_markers_beyond_2_levels_deep', async () => {
      // GIVEN: OCaml markers exist but beyond 2 levels up
      const deepDir = '/test/very/deep/nested/project/src';

      // WHEN: Detecting project from deep directory
      const result = await projectDetector.detectProject(deepDir);

      // THEN: Should fail to detect distant project
      expect(result.success).toBe(false);
      expect(result.projectRoot).toBe(null);
      expect(result.error).toContain('No OCaml project found');
    });

    test('should_handle_non_existent_directory', async () => {
      // GIVEN: Non-existent directory path
      const invalidDir = '/nonexistent/path';

      // WHEN: Detecting project in non-existent directory
      const result = await projectDetector.detectProject(invalidDir);

      // THEN: Should fail with appropriate error
      expect(result.success).toBe(false);
      expect(result.projectRoot).toBe(null);
      expect(result.error).toContain('Directory not found');
      expect(result.error).toContain(invalidDir);
    });

    test('should_handle_permission_denied_scenarios', async () => {
      // GIVEN: Directory exists but permission denied
      const restrictedDir = '/restricted/project';

      // WHEN: Detecting project in restricted directory
      const result = await projectDetector.detectProject(restrictedDir);

      // THEN: Should fail with permission error
      expect(result.success).toBe(false);
      expect(result.projectRoot).toBe(null);
      expect(result.error).toContain('Permission denied');
      expect(result.error).toContain(restrictedDir);
    });

    test('should_handle_empty_directory_gracefully', async () => {
      // GIVEN: Empty directory with no files
      const emptyDir = '/test/empty';

      // WHEN: Detecting project in empty directory
      const result = await projectDetector.detectProject(emptyDir);

      // THEN: Should fail gracefully
      expect(result.success).toBe(false);
      expect(result.projectRoot).toBe(null);
      expect(result.error).toContain('No OCaml project found');
    });
  });

  describe('Environment Validation - Success Cases', () => {
    test('should_validate_opam_is_available_and_working', async () => {
      // GIVEN: opam is installed and working

      // WHEN: Validating environment
      const result = await projectDetector.validateEnvironment();

      // THEN: Should confirm opam is available
      expect(result.success).toBe(true);
      expect(result.opamAvailable).toBe(true);
      expect(result.error).toBe(null);
    });

    test('should_validate_opam_with_working_switch', async () => {
      // GIVEN: opam with valid switch environment

      // WHEN: Validating environment with switch check
      const result = await projectDetector.validateEnvironment();

      // THEN: Should validate opam switch
      expect(result.success).toBe(true);
      expect(result.opamAvailable).toBe(true);
      expect(result.error).toBe(null);
    });
  });

  describe('Environment Validation - Failure Cases', () => {
    test('should_fail_when_opam_not_installed', async () => {
      // GIVEN: opam command not found

      // WHEN: Validating environment without opam
      const result = await projectDetector.validateEnvironment();

      // THEN: Should report opam not available
      expect(result.success).toBe(false);
      expect(result.opamAvailable).toBe(false);
      expect(result.error).toContain('opam not found');
      expect(result.error).toContain('Please install opam');
    });

    test('should_fail_when_opam_exists_but_not_executable', async () => {
      // GIVEN: opam exists but not executable

      // WHEN: Validating non-executable opam
      const result = await projectDetector.validateEnvironment();

      // THEN: Should report permission issue
      expect(result.success).toBe(false);
      expect(result.opamAvailable).toBe(false);
      expect(result.error).toContain('opam not executable');
      expect(result.error).toContain('Permission denied');
    });

    test('should_fail_when_opam_version_command_fails', async () => {
      // GIVEN: opam command fails with non-zero exit

      // WHEN: Validating failing opam
      const result = await projectDetector.validateEnvironment();

      // THEN: Should report opam malfunction
      expect(result.success).toBe(false);
      expect(result.opamAvailable).toBe(false);
      expect(result.error).toContain('opam version check failed');
    });
  });

  describe('File System Edge Cases', () => {
    test('should_handle_symbolic_links_to_project_files', async () => {
      // GIVEN: Symbolic link to dune-project file
      const testDir = '/test/linked-project';

      // WHEN: Detecting project with symbolic links
      const result = await projectDetector.detectProject(testDir);

      // THEN: Should detect project through symlink
      expect(result.success).toBe(true);
      expect(result.projectRoot).toBe(testDir);
      expect(result.error).toBe(null);
    });

    test('should_handle_special_characters_in_directory_names', async () => {
      // GIVEN: Directory with special characters
      const specialDir = '/test/project with spaces & symbols!@#';

      // WHEN: Detecting project in directory with special chars
      const result = await projectDetector.detectProject(specialDir);

      // THEN: Should handle special characters correctly
      expect(result.success).toBe(true);
      expect(result.projectRoot).toBe(specialDir);
      expect(result.error).toBe(null);
    });

    test('should_handle_case_sensitivity_appropriately', async () => {
      // GIVEN: Mixed case project files
      const testDir = '/test/Case-Sensitive-Project';

      // WHEN: Detecting project with mixed case
      const result = await projectDetector.detectProject(testDir);

      // THEN: Should handle case-sensitive file matching
      expect(result.success).toBe(true);
      expect(result.projectRoot).toBe(testDir);
      expect(result.error).toBe(null);
    });
  });

  describe('Integration Scenarios', () => {
    test('should_handle_real_ocaml_project_structure', async () => {
      // GIVEN: Typical OCaml project with dune + opam
      const projectDir = '/test/real-project';

      // WHEN: Detecting real OCaml project
      const result = await projectDetector.detectProject(projectDir);

      // THEN: Should detect project successfully
      expect(result.success).toBe(true);
      expect(result.projectRoot).toBe(projectDir);
      expect(result.error).toBe(null);
    });

    test('should_handle_monorepo_with_multiple_projects', async () => {
      // GIVEN: Monorepo with multiple OCaml projects
      const monorepoDir = '/test/monorepo';

      // WHEN: Detecting project in monorepo
      const result = await projectDetector.detectProject(monorepoDir);

      // THEN: Should detect monorepo root
      expect(result.success).toBe(true);
      expect(result.projectRoot).toBe(monorepoDir);
      expect(result.error).toBe(null);
    });

    test('should_handle_nested_project_detection_correctly', async () => {
      // GIVEN: Nested projects where inner project should be found
      const nestedDir = '/test/outer-project/inner-project';

      // WHEN: Detecting from nested project directory
      const result = await projectDetector.detectProject(nestedDir);

      // THEN: Should find inner project first
      expect(result.success).toBe(true);
      expect(result.projectRoot).toBe(nestedDir);
      expect(result.error).toBe(null);
    });
  });

  describe('Error Handling and Edge Cases', () => {
    test('should_provide_clear_error_messages_for_debugging', async () => {
      // GIVEN: Various failure scenarios
      const testDir = '/test/debug-project';

      // WHEN: Project detection fails
      const result = await projectDetector.detectProject(testDir);

      // THEN: Error message should be informative
      expect(result.success).toBe(false);
      expect(result.error).toContain('No OCaml project found');
      expect(result.error).toContain('dune-project');
      expect(result.error).toContain('.opam');
      expect(result.error).toContain('2 levels deep');
      expect(result.error).toContain(testDir);
    });

    test('should_timeout_gracefully_on_slow_file_operations', async () => {
      // GIVEN: Slow file system operations
      const testDir = '/test/slow-fs';

      // WHEN: Detecting project with slow file system
      const result = await projectDetector.detectProject(testDir);

      // THEN: Should handle timeout gracefully
      expect(result.success).toBe(false);
      expect(result.projectRoot).toBe(null);
      expect(result.error).toContain('timeout');
    });

    test('should_handle_concurrent_detection_requests', async () => {
      // GIVEN: Multiple concurrent detection requests
      const testDir = '/test/concurrent';

      // WHEN: Multiple detection calls concurrently
      const promises = [
        projectDetector.detectProject(testDir),
        projectDetector.detectProject(testDir),
        projectDetector.detectProject(testDir)
      ];
      const results = await Promise.all(promises);

      // THEN: All should succeed consistently
      results.forEach(result => {
        expect(result.success).toBe(true);
        expect(result.projectRoot).toBe(testDir);
        expect(result.error).toBe(null);
      });
    });
  });
});