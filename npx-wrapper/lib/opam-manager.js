import { exec } from 'child_process';

export class OpamManager {
  constructor(execFunction = exec) {
    // Allow dependency injection for testing
    this._exec = execFunction;
    
    // Dependency resolution strategies
    this.resolutionStrategies = {
      'opam': this._resolveViaOpam.bind(this),
      'github': this._resolveViaGithub.bind(this),
      'git': this._resolveViaGit.bind(this),
      'file': this._resolveViaFile.bind(this),
      'archive': this._resolveViaArchive.bind(this)
    };
  }

  /**
   * Check if ocaml-mcp-server is installed and working
   * @returns {Promise<boolean>}
   */
  async isServerInstalled() {
    try {
      // Check if package is listed as INSTALLED in opam (not just available)
      const listResult = await this._execCommand('opam list ocaml-mcp-server --installed');
      if (listResult.error || !listResult.stdout || listResult.stdout.trim() === '' || listResult.stdout.includes('No matches found')) {
        return false;
      }

      // If we get here, the package is installed. Let's also verify the executable works
      // by checking if it can show help without the NPX wrapper interfering
      const execResult = await this._execCommand('opam exec -- ocaml-mcp-server --version');
      if (execResult.error) {
        return false;
      }

      // Check that the output is from the actual OCaml server, not the NPX wrapper
      if (execResult.stdout.includes('@ocaml-mcp/server')) {
        // This is the NPX wrapper output, not the real OCaml server
        return false;
      }

      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * Run pre-flight dependency checks
   * @returns {Promise<{success: boolean, error: string | null, warnings: string[]}>}
   */
  async runPreflightChecks() {
    const warnings = [];
    
    try {
      // Check if opam is available
      const opamResult = await this._execCommand('opam --version');
      if (opamResult.error) {
        return { 
          success: false, 
          error: 'OPAM is not installed or not available in PATH. Please install OPAM first.',
          warnings 
        };
      }

      // Check if a switch is set
      const switchResult = await this._execCommand('opam switch show');
      if (switchResult.error) {
        return { 
          success: false, 
          error: 'No OPAM switch is currently set. Please create or set an OPAM switch first.',
          warnings 
        };
      }

      // Check repository freshness (last update)
      const repoResult = await this._execCommand('opam repository list');
      if (repoResult.stdout && !repoResult.stdout.includes('default')) {
        warnings.push('No default OPAM repository found. Package installation may fail.');
      }

      // Check for core dependencies availability
      const coreDeps = ['lwt', 'yojson', 'cmdliner', 'dune'];
      const missingDeps = [];
      
      for (const dep of coreDeps) {
        const depResult = await this._execCommand(`opam show ${dep}`);
        if (depResult.error) {
          missingDeps.push(dep);
        }
      }

      if (missingDeps.length > 0) {
        warnings.push(`Core dependencies not found in repository: ${missingDeps.join(', ')}. Consider running 'opam update' first.`);
      }

      // Check OCaml version compatibility
      const ocamlResult = await this._execCommand('ocaml -version');
      if (ocamlResult.stdout) {
        const versionMatch = ocamlResult.stdout.match(/(\d+)\.(\d+)\.(\d+)/);
        if (versionMatch) {
          const [, major, minor] = versionMatch;
          const version = parseFloat(`${major}.${minor}`);
          if (version < 4.14) {
            warnings.push(`OCaml version ${major}.${minor}.x may be too old. OCaml >= 4.14 is recommended.`);
          }
        }
      }

      // Check for ocaml-platform-sdk availability
      const platformSdkResult = await this._execCommand('opam show ocaml-platform-sdk');
      if (platformSdkResult.error) {
        warnings.push('ocaml-platform-sdk not found. Will be pinned automatically during installation.');
      }

      return { success: true, error: null, warnings };
    } catch (error) {
      return { 
        success: false, 
        error: `Pre-flight check failed: ${error.message}`,
        warnings 
      };
    }
  }

  /**
   * Update OPAM repository before installation
   * @returns {Promise<{success: boolean, error: string | null}>}
   */
  async updateRepository() {
    try {
      console.log('Updating OPAM repository...');
      const result = await this._execCommand('opam update');
      
      if (result.error) {
        return { 
          success: false, 
          error: `Failed to update OPAM repository: ${result.stderr}` 
        };
      }
      
      console.log('OPAM repository updated successfully.');
      return { success: true, error: null };
    } catch (error) {
      return { 
        success: false, 
        error: `Repository update failed: ${error.message}` 
      };
    }
  }

  /**
   * Install ocaml-mcp-server via opam pin with enhanced diagnostics
   * @param {string} repoUrl - Repository URL
   * @returns {Promise<{success: boolean, error: string | null}>}
   */
  async installServer(repoUrl) {
    // Validate URL first
    const validationError = this._validateRepositoryUrl(repoUrl);
    if (validationError) {
      return { success: false, error: validationError };
    }

    try {
      // Run pre-flight checks
      const preflightResult = await this.runPreflightChecks();
      if (!preflightResult.success) {
        return { success: false, error: preflightResult.error };
      }

      // Show warnings if any
      if (preflightResult.warnings.length > 0) {
        console.warn('Pre-flight warnings:');
        preflightResult.warnings.forEach(warning => console.warn(`  - ${warning}`));
      }

      // Ensure ocaml-platform-sdk is pinned before installation
      const platformSdkResult = await this.ensurePlatformSdkPinned();
      if (!platformSdkResult.success) {
        return { success: false, error: platformSdkResult.error };
      }

      // Pin all local packages from the repository (mcp, mcp-eio, ocaml-mcp-server)
      console.log('📦 Pinning all local packages from repository...');
      const localPackagesResult = await this.ensureAllLocalPackagesPinned(repoUrl);
      if (!localPackagesResult.success) {
        return { success: false, error: localPackagesResult.error };
      }

      // Auto-update repository if dependencies are missing
      const needsUpdate = preflightResult.warnings.some(w => 
        w.includes('dependencies not found') || w.includes('Consider running'));
      
      if (needsUpdate) {
        console.log('Missing dependencies detected. Updating OPAM repository...');
        const updateResult = await this.updateRepository();
        if (!updateResult.success) {
          console.warn(`Repository update failed: ${updateResult.error}`);
          console.warn('Proceeding with installation anyway...');
        }
      }

      // Proceed with installation (packages are already pinned, just install them)
      console.log('📦 Installing ocaml-mcp-server and dependencies...');
      const command = `opam install ocaml-mcp-server --yes`;
      const result = await this._execCommand(command);
      
      if (!result.error) {
        return { success: true, error: null };
      } else {
        // Enhanced error handling with specific solutions
        const errorMessage = this._getEnhancedErrorMessage(result.error, result.stderr, repoUrl);
        return { success: false, error: errorMessage };
      }
    } catch (error) {
      const errorMessage = this._getEnhancedErrorMessage(error, error.message || '', repoUrl);
      return { success: false, error: errorMessage };
    }
  }

  /**
   * Ensure ocaml-platform-sdk is pinned to the correct repository
   * @returns {Promise<{success: boolean, error: string | null}>}
   */
  async ensurePlatformSdkPinned() {
    try {
      // Check if ocaml-platform-sdk is already pinned
      const checkResult = await this._execCommand('opam list --installed ocaml-platform-sdk');
      
      // If it's already pinned/installed, we're good (check for exact match at line start)
      const packageRegex = /^ocaml-platform-sdk\s+/m;
      if (!checkResult.error && checkResult.stdout && packageRegex.test(checkResult.stdout)) {
        return { success: true, error: null };
      }

      // Pin the package to the GitHub repository
      console.log('📦 Pinning ocaml-platform-sdk dependency...');
      const pinCommand = 'opam pin add ocaml-platform-sdk https://github.com/tmattio/ocaml-platform-sdk.git --yes';
      const pinResult = await this._execCommand(pinCommand);
      
      if (pinResult.error) {
        return { 
          success: false, 
          error: `Failed to pin ocaml-platform-sdk: ${pinResult.stderr || pinResult.error.message}` 
        };
      }

      console.log('✅ ocaml-platform-sdk pinned successfully.');
      return { success: true, error: null };
    } catch (error) {
      return { 
        success: false, 
        error: `Error pinning ocaml-platform-sdk: ${error.message}` 
      };
    }
  }

  /**
   * Ensure all local packages from the repository are pinned
   * @param {string} repoUrl - Repository URL containing the packages
   * @returns {Promise<{success: boolean, error: string | null, results: Array}>}
   */
  async ensureAllLocalPackagesPinned(repoUrl) {
    // Pin packages in dependency order: mcp first, then mcp-eio, then ocaml-mcp-server
    const packages = ['mcp', 'mcp-eio', 'ocaml-mcp-server'];
    const results = [];
    
    for (const pkg of packages) {
      try {
        // Check if package is already pinned/installed
        const checkResult = await this._execCommand(`opam list --installed ${pkg}`);
        // Check for exact package name match at the beginning of a line
        const packageRegex = new RegExp(`^${pkg}\\s+`, 'm');
        if (!checkResult.error && checkResult.stdout && packageRegex.test(checkResult.stdout)) {
          console.log(`✅ ${pkg} already pinned/installed.`);
          results.push({ package: pkg, success: true, alreadyPinned: true });
          continue;
        }

        // Pin the package
        console.log(`📦 Pinning ${pkg} from repository...`);
        const pinCommand = `opam pin add ${pkg} ${repoUrl} --yes`;
        const pinResult = await this._execCommand(pinCommand);
        
        if (pinResult.error) {
          // Check if the error is because it's already pinned (sometimes opam returns error for already pinned)
          const recheckResult = await this._execCommand(`opam list ${pkg}`);
          if (!recheckResult.error && recheckResult.stdout && recheckResult.stdout.includes(pkg)) {
            console.log(`✅ ${pkg} was already pinned.`);
            results.push({ package: pkg, success: true, alreadyPinned: true });
          } else {
            console.error(`❌ Failed to pin ${pkg}: ${pinResult.stderr || pinResult.error.message}`);
            results.push({ 
              package: pkg, 
              success: false, 
              error: pinResult.stderr || pinResult.error.message 
            });
          }
        } else {
          console.log(`✅ ${pkg} pinned successfully.`);
          results.push({ package: pkg, success: true, alreadyPinned: false });
        }
      } catch (error) {
        console.error(`❌ Error pinning ${pkg}: ${error.message}`);
        results.push({ 
          package: pkg, 
          success: false, 
          error: error.message 
        });
      }
    }
    
    const allSuccess = results.every(r => r.success);
    const failedPackages = results.filter(r => !r.success);
    
    if (!allSuccess) {
      const failureDetails = failedPackages
        .map(r => `${r.package}: ${r.error}`)
        .join('\n  ');
      return {
        success: false,
        error: `Failed to pin some packages:\n  ${failureDetails}`,
        results
      };
    }
    
    return {
      success: true,
      error: null,
      results
    };
  }

  /**
   * Validate repository URL format
   * @param {string} repoUrl 
   * @returns {string|null} Error message or null if valid
   */
  _validateRepositoryUrl(repoUrl) {
    if (!repoUrl || typeof repoUrl !== 'string') {
      return 'Invalid repository URL';
    }

    const url = repoUrl.trim();
    if (url === '') {
      return 'Invalid repository URL';
    }

    // Allow various formats:
    // - HTTPS Git URLs (https://...)
    // - SSH Git URLs (git@...)
    // - SSH protocol URLs (ssh://git@...)
    // - Local paths (starting with /)
    // - File URLs (file:///)
    // - URLs with branch specifications (#branch)
    const validPatterns = [
      /^https:\/\/.+\.git(\#.*)?$/,           // HTTPS Git URLs
      /^git@.+:.+\.git(\#.*)?$/,              // SSH Git URLs  
      /^ssh:\/\/git@.+\/.+\.git(\#.*)?$/,     // SSH protocol URLs
      /^\/.*$/,                               // Local absolute paths
      /^file:\/\/\/.*$/,                      // File URLs
      /^https:\/\/.+/                         // Other HTTPS URLs (for custom domains)
    ];

    const isValid = validPatterns.some(pattern => pattern.test(url));
    if (!isValid) {
      return 'Invalid repository URL';
    }

    return null;
  }

  /**
   * Get enhanced error message with specific solutions
   * @param {Error} error 
   * @param {string} stderr 
   * @param {string} repoUrl 
   * @returns {string}
   */
  _getEnhancedErrorMessage(error, stderr, repoUrl) {
    const code = error.code;
    const stderrLower = (stderr || '').toLowerCase();

    switch (code) {
      case 5:
        if (stderrLower.includes('no switch')) {
          return `❌ No OPAM switch is currently set.

🔧 Solutions:
1. Create a new switch: opam switch create 5.0.0
2. Use existing switch: opam switch list && opam switch <name>
3. Initialize OPAM: opam init

Original error: ${stderr}`;
        }
        return `❌ Permission denied accessing OPAM switch.

🔧 Solutions:
1. Fix permissions: sudo chown -R $USER ~/.opam
2. Reinstall OPAM: brew reinstall opam (macOS) or apt reinstall opam (Linux)
3. Use different switch: opam switch create temp-switch

Original error: ${stderr}`;
      
      case 20:
        const missingPackages = this._extractMissingPackages(stderr);
        return `❌ Cannot resolve package dependencies.

🔧 Solutions (try in order):
1. Update OPAM repository: opam update
2. Upgrade packages: opam upgrade
${missingPackages.length > 0 ? `3. Install missing packages: opam install ${missingPackages.join(' ')}` : ''}
4. Create fresh switch: opam switch create ocaml-mcp 5.0.0
5. Use Docker fallback: docker run -it ocaml/opam:ubuntu opam install ocaml-mcp-server

Missing/conflicting: ${missingPackages.join(', ') || 'See details below'}
Original error: ${stderr}`;
      
      case 30:
        if (stderrLower.includes('authentication failed')) {
          return `❌ Git authentication failed.

🔧 Solutions:
1. Check SSH key: ssh -T git@github.com
2. Use HTTPS instead: ${repoUrl.replace(/^git@github\.com:/, 'https://github.com/').replace(/^git@/, 'https://')}
3. Configure Git: git config --global user.name "Your Name"
4. Add SSH key: ssh-keygen -t ed25519 -C "your@email.com"

Original error: ${stderr}`;
        }
        return `❌ Repository not found or access denied.

🔧 Solutions:
1. Check repository URL: ${repoUrl}
2. Use official repo: https://github.com/tmattio/ocaml-mcp.git
3. Check network connectivity: ping github.com
4. Try with authentication: git clone ${repoUrl}

Original error: ${stderr}`;
      
      case 31:
        return `❌ Package compilation failed.

🔧 Solutions:
1. Install build dependencies: opam install dune ocamlfind
2. Update OCaml: opam switch create 5.0.0
3. Clean and retry: opam clean && opam install ocaml-mcp-server
4. Check system dependencies: sudo apt install build-essential (Linux)

Compilation details: ${stderr}`;
      
      case 40:
        return `❌ Network connectivity issue.

🔧 Solutions:
1. Check internet: ping opam.ocaml.org
2. Configure proxy: export HTTP_PROXY=http://proxy:port
3. Use VPN if behind corporate firewall
4. Try alternative repository: opam repo add custom-repo <url>
5. Download manually and install from local path

Network error: ${stderr}`;
      
      case 'TIMEOUT':
        return `❌ Installation timeout (exceeded time limit).

🔧 Solutions:
1. Retry installation: opam install ocaml-mcp-server
2. Install with more time: timeout 1800 opam install ocaml-mcp-server
3. Install dependencies separately: opam install lwt yojson cmdliner
4. Use faster mirror: opam repo priority <faster-repo> 1

Original error: ${stderr}`;
      
      default:
        if (stderrLower.includes('network')) {
          return `❌ Network connectivity issue.

🔧 Solutions:
1. Check internet connection: ping opam.ocaml.org
2. Configure proxy if needed: export HTTP_PROXY=http://proxy:port
3. Try with VPN if behind corporate firewall

Network error: ${stderr}`;
        }
        if (stderrLower.includes('dependency') || stderrLower.includes('conflict')) {
          return `❌ Package dependency conflict.

🔧 Solutions:
1. Update repository: opam update
2. Resolve conflicts: opam upgrade
3. Create clean switch: opam switch create clean-env 5.0.0

Conflict details: ${stderr}`;
        }
        return `❌ Installation failed.

🔧 General solutions:
1. Update OPAM: opam update && opam upgrade
2. Check OPAM status: opam doctor
3. Create new switch: opam switch create debug-switch 5.0.0
4. Get help: opam pin add ocaml-mcp-server ${repoUrl} --verbose

Error details: ${stderr || 'No additional details available'}`;
    }
  }

  /**
   * Extract missing package names from error message
   * @param {string} stderr 
   * @returns {string[]}
   */
  _extractMissingPackages(stderr) {
    const packages = [];
    const lines = stderr.split('\n');
    
    for (const line of lines) {
      // Look for patterns like "package not found" or "requires package"
      const match = line.match(/(?:requires?|missing|not found).*?([a-z][a-z0-9-]+)(?:\s|$|\.|,)/gi);
      if (match) {
        match.forEach(m => {
          const pkgMatch = m.match(/([a-z][a-z0-9-]+)/);
          if (pkgMatch && !packages.includes(pkgMatch[1])) {
            packages.push(pkgMatch[1]);
          }
        });
      }
    }
    
    return packages;
  }

  /**
   * Get basic error message (legacy method for compatibility)
   * @param {Error} error 
   * @param {string} stderr 
   * @returns {string}
   */
  _getErrorMessage(error, stderr) {
    return this._getEnhancedErrorMessage(error, stderr, '');
  }

  /**
   * Execute command using child_process.exec
   * @param {string} command 
   * @returns {Promise<{stdout: string, stderr: string, error: Error|null}>}
   */
  _execCommand(command) {
    return new Promise((resolve) => {
      // For opam pin add commands, set EDITOR=true to skip editor and pipe "y" for prompts
      let finalCommand = command;
      let options = {};
      
      if (command.includes('opam pin add')) {
        // Set EDITOR=true to skip the editor prompt
        options.env = { ...process.env, EDITOR: 'true' };
        // Also pipe yes for any prompts
        if (!command.startsWith('yes |')) {
          finalCommand = `yes | ${command}`;
        }
      }
      
      this._exec(finalCommand, options, (error, stdout, stderr) => {
        resolve({
          stdout: stdout || '',
          stderr: stderr || '',
          error: error
        });
      });
    });
  }

  /**
   * Enhanced installServer method with multiple dependency resolution strategies
   * @param {string} repoUrl - Repository URL or source specification
   * @returns {Promise<{success: boolean, error: string | null}>}
   */
  async installServerEnhanced(repoUrl) {
    const sourceType = this._detectSourceType(repoUrl);
    console.log(`🔍 Detected source type: ${sourceType}`);
    
    const strategy = this.resolutionStrategies[sourceType];
    if (!strategy) {
      return { success: false, error: `Unsupported source type: ${sourceType}` };
    }
    
    return await strategy(repoUrl);
  }

  /**
   * Detect the type of source URL
   * @param {string} repoUrl 
   * @returns {string}
   */
  _detectSourceType(repoUrl) {
    if (repoUrl.startsWith('github:')) return 'github';
    if (repoUrl.startsWith('file://') || repoUrl.startsWith('/')) return 'file';
    if (repoUrl.endsWith('.tar.gz') || repoUrl.endsWith('.zip')) return 'archive';
    if (repoUrl.startsWith('git+') || repoUrl.endsWith('.git')) return 'git';
    return 'git'; // Default to git for URLs
  }

  /**
   * Resolve dependency via standard opam repository
   * @param {string} packageName 
   * @returns {Promise<{success: boolean, error: string | null}>}
   */
  async _resolveViaOpam(packageName) {
    console.log(`📦 Installing ${packageName} via opam repository...`);
    const result = await this._execCommand(`opam install ${packageName} --yes`);
    
    if (result.error) {
      return { success: false, error: result.stderr || result.error.message };
    }
    
    return { success: true, error: null };
  }

  /**
   * Resolve dependency via GitHub repository (using git subtree approach)
   * @param {string} repoUrl 
   * @returns {Promise<{success: boolean, error: string | null}>}
   */
  async _resolveViaGithub(repoUrl) {
    // Convert github: prefix to full URL
    const githubUrl = repoUrl.replace('github:', 'https://github.com/') + '.git';
    return await this._resolveViaGit(githubUrl);
  }

  /**
   * Resolve dependency via Git repository (fallback to original method)
   * @param {string} repoUrl 
   * @returns {Promise<{success: boolean, error: string | null}>}
   */
  async _resolveViaGit(repoUrl) {
    console.log(`🔀 Installing from git repository: ${repoUrl}`);
    // Use the original installServer method for git URLs
    return await this.installServer(repoUrl);
  }

  /**
   * Resolve dependency via file:// URL or local path
   * @param {string} filePath 
   * @returns {Promise<{success: boolean, error: string | null}>}
   */
  async _resolveViaFile(filePath) {
    const cleanPath = filePath.replace('file://', '');
    console.log(`📁 Installing from local path: ${cleanPath}`);
    return await this.installServer(filePath);
  }

  /**
   * Resolve dependency via archive download
   * @param {string} archiveUrl 
   * @returns {Promise<{success: boolean, error: string | null}>}
   */
  async _resolveViaArchive(archiveUrl) {
    console.log(`📦 Installing from archive: ${archiveUrl}`);
    // For now, treat archives as git URLs (opam can handle them)
    return await this.installServer(archiveUrl);
  }
}