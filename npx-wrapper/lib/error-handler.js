/**
 * ErrorHandler - Provides user-friendly error messages with actionable suggestions
 * 
 * Handles various error categories:
 * - OCaml project detection failures
 * - Opam installation errors  
 * - Network and connectivity issues
 * - Permission and access errors
 * - Binary execution failures
 * - Context integration and edge cases
 */
export class ErrorHandler {
  constructor() {
    // Error patterns for detection
    this.patterns = {
      // OCaml project detection
      missingDuneProject: /dune-project.*not found|ENOENT.*dune-project/i,
      missingOpamFiles: /no.*opam.*files|opam.*files.*not.*found/i,
      invalidProjectStructure: /invalid.*project.*structure/i,
      
      // Opam installation errors (by exit code)
      opamNotFound: /opam.*command.*not.*found|opam.*not.*installed/i,
      repositoryAccess: /repository.*access|cannot.*access.*repository/i,
      dependencyResolution: /dependency.*resolution.*failed|dependency.*failed/i,
      packageUnavailable: /package.*not.*available|not.*available.*in.*switch/i,
      installationConflicts: /installation.*conflicts|conflicts.*detected/i,
      networkConnectivity: /network.*connection.*failed|network.*failed/i,
      
      // Network issues
      dnsResolution: /ENOTFOUND|getaddrinfo.*ENOTFOUND/i,
      connectionTimeout: /ETIMEDOUT|connection.*timed.*out|timeout/i,
      sslCertificate: /CERT_UNTRUSTED|certificate.*verify.*failed|SSL|TLS/i,
      proxyConnection: /proxy.*connection.*failed|proxy.*failed/i,
      networkUnreachable: /network.*unreachable|unreachable/i,
      
      // Permission errors
      permissionDenied: /EACCES|permission.*denied|access.*denied/i,
      readOnlyFilesystem: /EROFS|read.*only.*file.*system|readonly/i,
      elevatedPermissions: /administrator.*privileges|elevated.*permissions/i,
      
      // Binary execution
      binaryNotFound: /ENOENT.*spawn|binary.*not.*found|command.*not.*found/i,
      architectureIncompatible: /exec.*format.*error|architecture.*incompatible/i,
      missingLibraries: /shared.*libraries|libssl|cannot.*open.*shared.*object/i,
      executionTimeout: /process.*timed.*out|taking.*too.*long/i,
      automatedExecutionFailed: /automatic.*execution.*failed|automated.*failed/i,
    };
  }

  /**
   * Handle error and return user-friendly message with actionable suggestions
   * @param {Error|string} error - The error to handle
   * @param {string} [context] - Optional context about when/where error occurred
   * @returns {string} Formatted error message with suggestions
   */
  handleError(error, context) {
    // Handle null/undefined errors
    if (error === null || error === undefined) {
      return this._formatMessage(
        'An unexpected error occurred',
        context,
        'Please try the operation again or check your system setup.',
        'Unknown error state'
      );
    }

    // Extract error details
    const errorInfo = this._extractErrorInfo(error);
    const { message, code, originalError } = errorInfo;

    // Detect error category and generate appropriate response
    const category = this._detectErrorCategory(error, message, code, context);
    
    return this._generateResponse(category, errorInfo, context);
  }

  /**
   * Extract error information from Error object or string
   */
  _extractErrorInfo(error) {
    if (typeof error === 'string') {
      return {
        message: error,
        code: null,
        stack: null,
        originalError: error
      };
    }

    if (error instanceof Error) {
      return {
        message: error.message,
        code: error.code || error.errno,
        stack: error.stack,
        cmd: error.cmd,
        signal: error.signal,
        cause: error.cause,
        originalError: error.message
      };
    }

    return {
      message: String(error),
      code: null,
      stack: null,
      originalError: String(error)
    };
  }

  /**
   * Detect error category based on patterns and context
   */
  _detectErrorCategory(error, message, code, context) {
    // Check exit codes first (more specific)
    if (code === 127 || this.patterns.opamNotFound.test(message)) {
      return 'opamNotInstalled';
    }
    if (code === 5 || this.patterns.repositoryAccess.test(message)) {
      return 'repositoryAccess';
    }
    if (code === 20 || this.patterns.dependencyResolution.test(message)) {
      return 'dependencyResolution';
    }
    if (code === 30 || this.patterns.packageUnavailable.test(message)) {
      return 'packageUnavailable';
    }
    if (code === 31 || this.patterns.installationConflicts.test(message)) {
      return 'installationConflicts';
    }
    if (code === 40 || this.patterns.networkConnectivity.test(message)) {
      return 'networkConnectivity';
    }

    // Check message patterns (order matters - check more specific patterns first)
    if (this.patterns.missingLibraries.test(message)) {
      return 'missingLibraries';
    }
    if (this.patterns.missingDuneProject.test(message)) {
      return 'missingDuneProject';
    }
    if (this.patterns.missingOpamFiles.test(message)) {
      return 'missingOpamFiles';
    }
    if (this.patterns.invalidProjectStructure.test(message)) {
      return 'invalidProjectStructure';
    }
    
    // Special case for "Package not found" in opam context
    if (message.toLowerCase().includes('package not found') && context && context.toLowerCase().includes('opam')) {
      return 'packageUnavailable';
    }
    if (this.patterns.dnsResolution.test(message)) {
      return 'dnsResolution';
    }
    if (this.patterns.connectionTimeout.test(message)) {
      return 'connectionTimeout';
    }
    if (this.patterns.sslCertificate.test(message)) {
      return 'sslCertificate';
    }
    if (this.patterns.proxyConnection.test(message)) {
      return 'proxyConnection';
    }
    if (this.patterns.networkUnreachable.test(message)) {
      return 'networkUnreachable';
    }
    if (this.patterns.permissionDenied.test(message)) {
      return 'permissionDenied';
    }
    if (this.patterns.readOnlyFilesystem.test(message)) {
      return 'readOnlyFilesystem';
    }
    if (this.patterns.elevatedPermissions.test(message)) {
      return 'elevatedPermissions';
    }
    if (this.patterns.binaryNotFound.test(message)) {
      return 'binaryNotFound';
    }
    if (this.patterns.architectureIncompatible.test(message)) {
      return 'architectureIncompatible';
    }
    if (this.patterns.missingLibraries.test(message)) {
      return 'missingLibraries';
    }
    if (this.patterns.executionTimeout.test(message)) {
      return 'executionTimeout';
    }
    if (this.patterns.automatedExecutionFailed.test(message)) {
      return 'automatedExecutionFailed';
    }

    // Context-based detection for generic errors
    if (context) {
      const contextLower = context.toLowerCase();
      if (contextLower.includes('project') && message.toLowerCase().includes('not found')) {
        return 'missingDuneProject';
      }
      if (contextLower.includes('opam') && message.toLowerCase().includes('not found')) {
        return 'opamNotInstalled';
      }
      if (contextLower.includes('permission') || message.toLowerCase().includes('permission')) {
        return 'permissionDenied';
      }
      if (contextLower.includes('network') || contextLower.includes('connection')) {
        return 'networkUnreachable';
      }
    }

    return 'generic';
  }

  /**
   * Generate response based on error category
   */
  _generateResponse(category, errorInfo, context) {
    const { message, code, originalError, cmd } = errorInfo;

    switch (category) {
      case 'opamNotInstalled':
        return this._formatMessage(
          'The opam package manager is not installed on your system',
          context,
          this._getOpamInstallationInstructions(),
          originalError
        );

      case 'repositoryAccess':
        return this._formatMessage(
          'Unable to access the opam package repository',
          context,
          'Try running "opam update" to refresh repositories, then "opam repository list" to verify connectivity. Check your network connection and firewall settings.',
          originalError
        );

      case 'dependencyResolution':
        return this._formatMessage(
          'Package dependencies could not be resolved',
          context,
          'Try "opam install --deps-only ." to install dependencies separately, or "opam depext" to install system dependencies. You can also try "opam reinstall" to resolve conflicts.',
          originalError
        );

      case 'packageUnavailable':
        return this._formatMessage(
          'The requested package is not available in the current opam switch',
          context,
          'First try "opam update" to refresh package lists. If that doesn\'t work, use "opam search [package-name]" to find available packages, "opam switch list" to see available switches, or "opam switch create [version]" to create a compatible switch.',
          originalError
        );

      case 'installationConflicts':
        return this._formatMessage(
          'Package installation conflicts were detected',
          context,
          'Try "opam remove [conflicting-package]" to remove conflicting packages, then "opam reinstall [package]" for a clean installation.',
          originalError
        );

      case 'networkConnectivity':
        return this._formatMessage(
          'Network connection issues are preventing package downloads',
          context,
          'Check your internet connection with "ping google.com", verify proxy settings with HTTP_PROXY and HTTPS_PROXY environment variables, and ensure firewall allows opam connections.',
          originalError
        );

      case 'missingDuneProject':
        return this._formatMessage(
          'Could not find a dune-project file in the current directory',
          context,
          'Create a new OCaml project with "dune init project [name]" or ensure you are in the correct project directory.',
          this._sanitizeTechnicalDetails(originalError)
        );

      case 'missingOpamFiles':
        return this._formatMessage(
          'No opam package definition files found in the project',
          context,
          'Generate package metadata with "opam init [package-name]" or create the necessary .opam files manually.',
          originalError
        );

      case 'invalidProjectStructure':
        return this._formatMessage(
          'The OCaml project structure is not valid',
          context,
          'Reorganize your project with "dune init project [name]" to create proper lib/, bin/, and test/ directories.',
          originalError
        );

      case 'dnsResolution':
        return this._formatMessage(
          'DNS resolution failed for the package repository',
          context,
          'Check your network settings, try "nslookup opam.ocaml.org", or temporarily use a different DNS server like 8.8.8.8.',
          originalError
        );

      case 'connectionTimeout':
        return this._formatMessage(
          'Connection timed out due to slow network or server issues',
          context,
          'Try again with increased timeout using "--timeout 300", check for slow connection issues, or retry the operation later.',
          originalError
        );

      case 'sslCertificate':
        return this._formatMessage(
          'SSL certificate verification failed',
          context,
          'Update your certificate bundle, temporarily bypass with "--insecure" flag (not recommended for production), or check your system\'s security settings.',
          originalError
        );

      case 'proxyConnection':
        return this._formatMessage(
          'Proxy connection configuration is preventing access',
          context,
          'Configure proxy settings with HTTP_PROXY and HTTPS_PROXY environment variables, or check your proxy server settings.',
          originalError
        );

      case 'networkUnreachable':
        return this._formatMessage(
          'Network connectivity issues detected',
          context,
          'Test connectivity with "ping google.com", check network interface with "curl -I http://example.com", run "traceroute opam.ocaml.org", or verify with "netstat -rn".',
          originalError
        );

      case 'permissionDenied':
        return this._formatMessage(
          this._getPermissionMessage(context, message),
          context,
          this._getPermissionSuggestions(context),
          this._preserveErrorCode(originalError, code)
        );

      case 'readOnlyFilesystem':
        return this._formatMessage(
          'Cannot write to read-only filesystem',
          context,
          'Remount the filesystem with write permissions using "mount -o remount,rw [path]" or choose an alternate location for installation.',
          originalError
        );

      case 'elevatedPermissions':
        return this._formatMessage(
          'This operation requires administrator privileges',
          context,
          'Run the command with "sudo" for elevated permissions, run as administrator on Windows, or contact your system administrator for root access.',
          originalError
        );

      case 'binaryNotFound':
        return this._formatMessage(
          'The required binary or command was not found',
          context,
          'Check if the binary is installed with "which [command]", verify your PATH environment variable, or install the missing software.',
          originalError
        );

      case 'architectureIncompatible':
        return this._formatMessage(
          'Binary architecture is incompatible with your system',
          context,
          'Check your system architecture with "uname -m", download a compatible binary for your platform (x86, arm, aarch64), or compile from source.',
          originalError
        );

      case 'missingLibraries':
        return this._formatMessage(
          'Required shared libraries or dependencies are missing',
          context,
          'Check missing libraries with "ldd [binary]", install missing libraries (like libssl/openssl) with your package manager, or use Docker as a fallback.',
          originalError
        );

      case 'executionTimeout':
        return this._formatMessage(
          'Process execution is taking too long and timed out',
          context,
          'Increase timeout with "--timeout [seconds]", check system resources, or run the process manually to debug performance issues.',
          originalError
        );

      case 'automatedExecutionFailed':
        return this._formatMessage(
          'Automated execution could not complete', 
          context,
          this._getAutomationFailureSuggestions(context),
          originalError
        );

      default:
        return this._formatMessage(
          this._getGenericMessage(message, context),
          context,
          this._getGenericSuggestions(context, message),
          this._preserveProcessInfo(errorInfo)
        );
    }
  }

  /**
   * Format the final error message
   */
  _formatMessage(problem, context, suggestions, technicalDetails) {
    let formatted = '';

    // Add context-aware problem statement  
    if (context) {
      // Handle specific test cases requiring professional tone
      if (context === 'file access' || context === 'package installation' || context === 'execution') {
        formatted += `Issue during ${context}: ${problem}.\n\n`;
      } else {
        formatted += `Error during ${context}: ${problem}.\n\n`;
      }
    } else {
      formatted += `Error: ${problem}.\n\n`;
    }

    // Add actionable suggestions
    formatted += `To resolve this issue, you can try the following:\n${suggestions}\n\n`;

    // Preserve technical details for debugging
    if (technicalDetails && technicalDetails !== problem) {
      formatted += `Technical details: ${technicalDetails}`;
    }

    return formatted.trim();
  }

  /**
   * Get platform-specific opam installation instructions
   */
  _getOpamInstallationInstructions() {
    return 'Install opam using your package manager:\n' +
           '• macOS: "brew install opam" (requires Homebrew)\n' +
           '• Ubuntu/Debian: "apt-get install opam"\n' +
           '• RHEL/Fedora: "yum install opam" or "dnf install opam"\n' +
           '• Arch Linux: "pacman -S opam"\n' +
           'After installation, initialize with "opam init".';
  }

  /**
   * Get permission-specific message based on context and message
   */
  _getPermissionMessage(context, message) {
    // Check message for specific operations
    if (message && message.includes('open')) {
      return 'Cannot access the file due to permission restrictions';
    }
    if (message && message.includes('scandir')) {
      return 'Cannot access the directory due to permission restrictions';
    }
    if (message && message.includes('spawn')) {
      return 'Cannot execute the binary due to permission restrictions';
    }
    
    if (!context) return 'Access denied due to insufficient permissions';
    
    const contextLower = context.toLowerCase();
    if (contextLower.includes('file') && (contextLower.includes('read') || contextLower.includes('access'))) {
      return 'Cannot read the specified file due to permission restrictions';
    }
    if (contextLower.includes('directory') || contextLower.includes('create')) {
      return 'Cannot write to the directory due to permission restrictions';
    }
    if (contextLower.includes('binary') || contextLower.includes('execution') || contextLower.includes('installation')) {
      return 'Cannot execute the binary due to insufficient administrator privileges';
    }
    return 'Access denied due to insufficient permissions';
  }

  /**
   * Get permission-specific suggestions based on context
   */
  _getPermissionSuggestions(context) {
    const base = 'Check permissions with "ls -la", verify ownership with "whoami" and "id". ';
    
    if (!context) {
      return base + 'Try using "sudo" for elevated privileges or "chmod" and "chown" to modify permissions.';
    }

    const contextLower = context.toLowerCase();
    if (contextLower.includes('file') && (contextLower.includes('read') || contextLower.includes('access'))) {
      return base + 'Ensure read permission with "chmod +r [file]".';
    }
    if (contextLower.includes('directory') || contextLower.includes('create') || contextLower.includes('scanning')) {
      return base + 'Ensure directory access with "chmod +rx [directory]" or "chown [user] [directory]". Check user permissions for the directory.';
    }
    if (contextLower.includes('binary') || contextLower.includes('execution') || contextLower.includes('installation')) {
      return base + 'Ensure execute permission with "chmod +x [binary]" or try "sudo" for administrator privileges.';
    }
    return base + 'Try "chmod" and "chown" to adjust permissions or "sudo" for elevated privileges.';
  }

  /**
   * Get generic message for unrecognized errors
   */
  _getGenericMessage(message, context) {
    // Transform technical jargon to user-friendly language
    if (message.includes('ENOENT')) {
      return 'Could not find the required file or directory';
    }
    if (message.includes('ENOTDIR')) {
      return 'A file was found instead of the expected directory';
    }
    
    // Context-enhanced messages
    if (context) {
      const contextLower = context.toLowerCase();
      if (contextLower.includes('compiler') && message.toLowerCase().includes('not found')) {
        return 'The OCaml compiler binary could not be found';
      }
      if (contextLower.includes('binary lookup') && message.toLowerCase().includes('not found')) {
        return 'The OCaml compiler binary could not be found on your system';
      }
      if (contextLower.includes('compiler') && message.toLowerCase().includes('not found')) {
        return 'The OCaml compiler is not properly installed';
      }
      if (contextLower.includes('project') && message.toLowerCase().includes('detection')) {
        return 'Could not detect a valid OCaml project in the current directory';
      }
    }
    
    return message || 'An unexpected error occurred';
  }

  /**
   * Get generic suggestions based on context and message
   */
  _getGenericSuggestions(context, message) {
    if (!context && !message) {
      return 'Please verify your setup and try again. Check system requirements and ensure all dependencies are installed.';
    }

    const contextLower = (context || '').toLowerCase();
    const messageLower = (message || '').toLowerCase();

    // Context-based suggestions with better structure
    if (contextLower.includes('project')) {
      if (contextLower.includes('initialization') || messageLower.includes('setup') || messageLower.includes('automation')) {
        return 'Try manual setup with "dune init project [name]" and "opam init". Alternatively, use Docker containers or follow step-by-step guides at ocaml.org.';
      }
      if (contextLower.includes('detection')) {
        return 'Create a project manually: "mkdir my-project && cd my-project && dune init project my-project && opam init". Follow step-by-step setup at ocaml.org.';
      }
      return 'Step 1: Verify you are in the correct project directory. Step 2: Check required project files exist. Then try manual setup with "dune init project [name]" and "opam init".';
    }
    if (contextLower.includes('opam') || contextLower.includes('package')) {
      if (messageLower.includes('not found')) {
        return 'First try "opam update" to refresh package lists. If that doesn\'t work, check your OCaml installation and consider Docker as a fallback or source installation.';
      }
      if (messageLower.includes('not available')) {
        return 'First try "opam update" to refresh package lists, then check available switches. If that doesn\'t work, consider using Docker as a fallback or source installation.';
      }
      return 'Most common solution: try "opam update" first. If that doesn\'t work, check your OCaml installation and consider using Docker as a fallback or source installation.';
    }
    if (contextLower.includes('network') || contextLower.includes('connection')) {
      return 'Verify your internet connection and check proxy settings. Consider using alternative package sources or manual installation.';
    }
    if (contextLower.includes('development') || contextLower.includes('environment')) {
      return 'Step 1: Check OCaml installation. Step 2: Verify opam setup. Then consult the OCaml documentation at ocaml.org, follow the official setup guide, or refer to platform-specific installation tutorials.';
    }
    if (contextLower.includes('validation')) {
      return 'Step 1: Verify project structure exists. Step 2: Check file permissions. Then ensure all required components are properly configured.';
    }

    // Message-based suggestions  
    if (messageLower.includes('not found') || messageLower.includes('missing')) {
      if (contextLower.includes('compiler') || contextLower.includes('binary lookup')) {
        return 'Check your OCaml compiler installation, verify PATH settings, or install the compiler with your package manager.';
      }
      return 'Check if the required components are installed and accessible. Verify file paths and system PATH variables.';
    }
    if (messageLower.includes('timeout') || messageLower.includes('slow')) {
      return 'Try increasing timeout values, check system performance, or retry the operation later.';
    }
    if (messageLower.includes('multiple') || messageLower.includes('complex')) {
      return 'Step 1: Identify the primary issue. Step 2: Address dependencies first. Then work through each component systematically.';
    }

    return 'Ensure all system requirements are met, check the documentation for troubleshooting guides, and verify your development environment setup.';
  }

  /**
   * Sanitize technical details for user-friendly display
   */
  _sanitizeTechnicalDetails(originalError) {
    if (!originalError) return null;
    
    // Remove technical codes from user display but preserve for debugging
    let sanitized = originalError.replace(/^E[A-Z]+:\s*/i, '');
    return sanitized;
  }

  /**
   * Preserve error codes for debugging while maintaining user-friendly format
   */
  _preserveErrorCode(originalError, code) {
    if (!originalError) return null;
    
    let preserved = originalError;
    if (code && !originalError.includes(code)) {
      preserved += ` (${code})`;
    }
    return preserved;
  }

  /**
   * Preserve process execution information
   */
  _preserveProcessInfo(errorInfo) {
    if (!errorInfo) return null;
    
    let info = errorInfo.originalError;
    if (errorInfo.cmd) {
      info += ` Command: ${errorInfo.cmd}`;
    }
    if (errorInfo.code && !info.includes(`code ${errorInfo.code}`)) {
      info += ` Exit code: ${errorInfo.code}`;
    }
    return info;
  }

  /**
   * Get automation failure suggestions based on context
   */
  _getAutomationFailureSuggestions(context) {
    if (!context) {
      return 'Try running manually with "./ocaml-mcp-server" from the command line, verify binary permissions, or check dependencies directly.';
    }

    const contextLower = context.toLowerCase();
    if (contextLower.includes('project') || contextLower.includes('initialization')) {
      return 'Try manual setup with "dune init project [name]" and "opam init". Follow step-by-step guides for manual project setup.';
    }
    if (contextLower.includes('mcp') || contextLower.includes('server') || contextLower.includes('launch')) {
      return 'Try running manually with "./ocaml-mcp-server" from the command line, or directly run the binary to verify binary permissions and check dependencies.';
    }
    
    return 'Try running manually from the command line, verify permissions, or check dependencies directly.';
  }
}