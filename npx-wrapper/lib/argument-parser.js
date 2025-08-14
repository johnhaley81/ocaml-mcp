/**
 * ArgumentParser - Command-line argument parser for OCaml MCP server wrapper
 * 
 * Parses wrapper-specific arguments (--repo, --print-config) and forwards
 * remaining arguments to the OCaml MCP server.
 *
 * Requirements:
 * - Extract --repo <url> parameter for opam pin workflow
 * - Detect --print-config flag for early exit
 * - Forward remaining arguments unchanged to server
 * - Validate Git repository URLs
 * - Handle various argument formats and edge cases
 */

export class ArgumentParser {
  /**
   * Parse command-line arguments into wrapper and server components
   * @param {string[]} args - Array of command-line arguments
   * @returns {{ repoUrl: string | null, printConfig: boolean, serverArgs: string[] }}
   */
  parseArgs(args) {
    // Input validation
    if (!Array.isArray(args)) {
      throw new Error('Arguments must be an array');
    }

    let repoUrl = null;
    let printConfig = false;
    const serverArgs = [];

    // Process arguments sequentially
    for (let i = 0; i < args.length; i++) {
      const arg = args[i];

      // Skip empty or whitespace-only arguments
      if (!arg || typeof arg !== 'string' || arg.trim() === '') {
        continue;
      }

      // Handle double dash separator - everything after goes to server
      if (arg === '--') {
        // Add remaining arguments to serverArgs
        serverArgs.push(...args.slice(i + 1));
        break;
      }

      // Handle --repo with equals syntax: --repo=url
      if (arg.startsWith('--repo=')) {
        const url = arg.substring(7); // Remove '--repo='
        if (!url) {
          throw new Error('--repo requires a repository URL');
        }
        this._validateRepositoryUrl(url);
        repoUrl = url;
        continue;
      }

      // Handle --repo as separate argument: --repo url
      if (arg === '--repo') {
        // Check if there's a next argument
        if (i + 1 >= args.length) {
          throw new Error('--repo requires a repository URL');
        }
        const url = args[i + 1];
        if (!url || url.startsWith('-')) {
          throw new Error('--repo requires a repository URL');
        }
        this._validateRepositoryUrl(url);
        repoUrl = url;
        i++; // Skip the next argument as we've consumed it
        continue;
      }

      // Handle --print-config flag
      if (arg === '--print-config') {
        printConfig = true;
        continue;
      }

      // Forward all other arguments to server
      serverArgs.push(arg);
    }

    return {
      repoUrl,
      printConfig,
      serverArgs
    };
  }

  /**
   * Validate repository URL format
   * @param {string} url - Repository URL to validate
   * @private
   */
  _validateRepositoryUrl(url) {
    if (!url || typeof url !== 'string') {
      throw new Error('Invalid repository URL format');
    }

    // Git URL patterns:
    // - https://github.com/user/repo.git
    // - https://gitlab.com/user/repo.git
    // - git@github.com:user/repo.git
    // - git://github.com/user/repo.git
    // - URLs with credentials: https://user:pass@github.com/user/repo.git
    // - URLs with branch/tag: https://github.com/user/repo.git#branch
    const gitUrlPatterns = [
      // HTTPS URLs (with optional credentials and branch/tag)
      /^https:\/\/(?:[^@\/]+@)?[a-zA-Z0-9.-]+\/[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+(?:\.git)?(?:#[a-zA-Z0-9._-]+)?$/,
      // SSH URLs
      /^git@[a-zA-Z0-9.-]+:[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+(?:\.git)?(?:#[a-zA-Z0-9._-]+)?$/,
      // Git protocol URLs
      /^git:\/\/[a-zA-Z0-9.-]+\/[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+(?:\.git)?(?:#[a-zA-Z0-9._-]+)?$/
    ];

    const isValidGitUrl = gitUrlPatterns.some(pattern => pattern.test(url));
    
    if (!isValidGitUrl) {
      throw new Error('Invalid repository URL format');
    }
  }
}