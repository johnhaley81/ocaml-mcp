#!/usr/bin/env node

/**
 * OCaml MCP Server NPX Wrapper
 * Main entry point for the NPX wrapper that orchestrates:
 * - Argument parsing and validation
 * - Configuration generation
 * - OCaml project detection
 * - OPAM package management
 * - Binary execution with argument forwarding
 */

import { createRequire } from 'module';
// process is already available as a global in Node.js
import path from 'path';
import { fileURLToPath } from 'url';

// ES Module compatibility helpers
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const require = createRequire(import.meta.url);

// Package information
const packageJson = require('../package.json');

/**
 * Import implemented components
 */
import { ArgumentParser } from '../lib/argument-parser.js';
import { ConfigGenerator } from '../lib/config-generator.js';
import { ProjectDetector } from '../lib/project-detector.js';
import { OpamManager } from '../lib/opam-manager.js';
import { BinaryExecutor } from '../lib/binary-executor.js';
import { ErrorHandler } from '../lib/error-handler.js';

/**
 * Exit codes for different failure scenarios
 */
const EXIT_CODES = {
  SUCCESS: 0,
  GENERAL_ERROR: 1,
  INVALID_ARGS: 2,
  PROJECT_NOT_FOUND: 3,
  OPAM_ERROR: 4,
  EXECUTION_ERROR: 5,
  INTERRUPT: 130
};

/**
 * Global state for cleanup tracking
 */
let cleanupHandlers = [];

/**
 * Register a cleanup handler to be called on process exit
 * @param {Function} handler - Cleanup function to register
 */
function registerCleanupHandler(handler) {
  cleanupHandlers.push(handler);
}

/**
 * Execute all registered cleanup handlers
 */
async function runCleanupHandlers() {
  // Use for...of instead of for await to avoid ESLint warning
  const results = cleanupHandlers.map(async handler => {
    try {
      await handler();
    } catch (error) {
      console.error('Error during cleanup:', error.message);
    }
  });
  await Promise.all(results);
}

/**
 * Handle process signals for graceful shutdown
 * @param {string} signal - The signal received
 */
async function handleProcessSignal(signal) {
  console.log(`\nReceived ${signal}. Shutting down gracefully...`);

  await runCleanupHandlers();

  const exitCode =
    signal === 'SIGINT' ? EXIT_CODES.INTERRUPT : EXIT_CODES.SUCCESS;
  // Throw error instead of using process.exit for better testability
  throw new Error(
    `Process terminated with signal ${signal} (exit code: ${exitCode})`
  );
}

/**
 * Setup process signal handlers for graceful shutdown
 */
function setupSignalHandlers() {
  // Handle Ctrl+C
  process.on('SIGINT', () => handleProcessSignal('SIGINT'));

  // Handle terminal close
  process.on('SIGTERM', () => handleProcessSignal('SIGTERM'));

  // Handle uncaught exceptions
  process.on('uncaughtException', error => {
    console.error('Uncaught Exception:', error);
    throw error;
  });

  // Handle unhandled promise rejections
  process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
    throw reason instanceof Error ? reason : new Error(String(reason));
  });
}

/**
 * Display version information
 */
function showVersion() {
  console.log(`${packageJson.name} v${packageJson.version}`);
}

/**
 * Display help information
 */
function showHelp() {
  console.log(`${packageJson.name} v${packageJson.version}`);
  console.log(packageJson.description);
  console.log('');
  console.log('Usage:');
  console.log('  npx @ocaml-mcp/server [options] [-- server-args]');
  console.log('');
  console.log('Options:');
  console.log('  --help, -h          Show this help message');
  console.log('  --version, -v       Show version information');
  console.log(
    '  --print-config      Print generated MCP configuration and exit'
  );
  console.log('  --verbose           Enable verbose logging');
  console.log(
    '  --dry-run           Show what would be executed without running'
  );
  console.log('');
  console.log('Examples:');
  console.log('  npx @ocaml-mcp/server');
  console.log('  npx @ocaml-mcp/server --print-config');
  console.log('  npx @ocaml-mcp/server --verbose -- --port 3000');
  console.log('');
  console.log('For more information, visit:');
  console.log(packageJson.homepage);
}

/**
 * Parse command line arguments using ArgumentParser component
 * @param {string[]} argv - Command line arguments
 * @returns {Object} Parsed arguments object
 */
function parseArguments(argv) {
  // Handle basic flags first
  const basicArgs = {
    help: argv.includes('--help') || argv.includes('-h'),
    version: argv.includes('--version') || argv.includes('-v'),
    printConfig: argv.includes('--print-config'),
    verbose: argv.includes('--verbose'),
    dryRun: argv.includes('--dry-run'),
    serverArgs: []
  };

  // Extract server arguments after '--'
  const separatorIndex = argv.indexOf('--');
  if (separatorIndex !== -1) {
    basicArgs.serverArgs = argv.slice(separatorIndex + 1);
  }

  // For wrapper-specific argument parsing, use ArgumentParser component
  try {
    const argumentParser = new ArgumentParser();
    const wrapperArgs = argumentParser.parseArgs(argv);
    
    // Merge results with proper precedence
    return {
      ...basicArgs,
      repoUrl: wrapperArgs.repoUrl,
      printConfig: wrapperArgs.printConfig || basicArgs.printConfig,
      // Use basic parsing serverArgs if double-dash separator was used, otherwise use ArgumentParser's
      serverArgs: basicArgs.serverArgs.length > 0 ? basicArgs.serverArgs : wrapperArgs.serverArgs
    };
  } catch (error) {
    // If ArgumentParser fails, return basic parsing with error
    throw error;
  }
}

/**
 * Orchestrate the main workflow
 * @param {Object} args - Parsed command line arguments
 */
async function orchestrateExecution(args) {
  if (args.verbose) {
    console.log('🔍 Starting OCaml MCP Server wrapper...');
  }

  try {
    // Step 1: Handle --print-config early exit
    if (args.printConfig) {
      console.log('📋 Generating MCP configuration...');
      const configGenerator = new ConfigGenerator();
      const config = configGenerator.generateConfig(args.repoUrl);
      console.log(JSON.stringify(config, null, 2));
      return EXIT_CODES.SUCCESS;
    }

    // Step 2: Detect OCaml project environment
    if (args.verbose) {
      console.log('🔍 Detecting OCaml project environment...');
    }
    
    const projectDetector = new ProjectDetector();
    const projectResult = await projectDetector.detectProject(process.cwd());
    
    if (!projectResult.success) {
      const errorHandler = new ErrorHandler();
      const formattedError = errorHandler.handleError(
        new Error(projectResult.error),
        'project detection'
      );
      console.error(formattedError);
      return EXIT_CODES.PROJECT_NOT_FOUND;
    }

    // Step 3: Validate environment (opam availability)
    const envResult = await projectDetector.validateEnvironment();
    if (!envResult.success) {
      const errorHandler = new ErrorHandler();
      const formattedError = errorHandler.handleError(
        new Error(envResult.error),
        'environment validation'
      );
      console.error(formattedError);
      return EXIT_CODES.OPAM_ERROR;
    }

    // Step 4: Check/install ocaml-mcp-server via OPAM
    if (args.verbose) {
      console.log('📦 Checking OPAM dependencies...');
    }
    
    const opamManager = new OpamManager();
    const isInstalled = await opamManager.isServerInstalled();
    
    if (!isInstalled) {
      if (!args.repoUrl) {
        console.error('❌ Repository URL required for first-time installation. Use --repo <url> parameter.');
        return EXIT_CODES.GENERAL_ERROR;
      }
      
      if (args.verbose) {
        console.log('🔄 Installing ocaml-mcp-server via opam pin...');
      }
      
      const installResult = await opamManager.installServerEnhanced(args.repoUrl);
      if (!installResult.success) {
        const errorHandler = new ErrorHandler();
        const formattedError = errorHandler.handleError(
          new Error(installResult.error),
          'opam installation'
        );
        console.error(formattedError);
        return EXIT_CODES.OPAM_ERROR;
      }
      
      if (args.verbose) {
        console.log('✅ Installation completed successfully');
      }
    } else if (args.verbose) {
      console.log('✅ ocaml-mcp-server already installed');
    }

    // Step 5: Execute server with argument forwarding
    if (args.verbose) {
      console.log('🚀 Executing OCaml MCP server...');
      console.log('📤 Server arguments:', args.serverArgs);
    }

    if (args.dryRun) {
      console.log('🧪 Dry run mode - would execute server now');
      return EXIT_CODES.SUCCESS;
    }

    const binaryExecutor = new BinaryExecutor();
    const exitCode = await binaryExecutor.executeServer(args.serverArgs);
    
    return exitCode;
  } catch (error) {
    console.error('❌ Error during execution:', error.message);

    if (args.verbose) {
      console.error('📊 Stack trace:', error.stack);
    }

    return EXIT_CODES.GENERAL_ERROR;
  }
}

/**
 * Main entry point function
 * @param {string[]} argv - Command line arguments (defaults to process.argv)
 */
async function main(argv = process.argv) {
  // Setup signal handlers
  setupSignalHandlers();

  try {
    // Parse command line arguments
    const args = parseArguments(argv.slice(2));

    // Handle help and version flags
    if (args.help) {
      showHelp();
      return EXIT_CODES.SUCCESS;
    }

    if (args.version) {
      showVersion();
      return EXIT_CODES.SUCCESS;
    }

    // Orchestrate the main execution flow
    const exitCode = await orchestrateExecution(args);
    return exitCode;
  } catch (error) {
    console.error('❌ Fatal error:', error.message);
    return EXIT_CODES.GENERAL_ERROR;
  }
}

// Execute main function - always run when this script is invoked
main()
  .then(exitCode => {
    // In CLI context, we need to exit with proper code
    // eslint-disable-next-line no-process-exit
    process.exit(exitCode);
  })
  .catch(error => {
    console.error('💥 Unhandled error in main:', error);
    // eslint-disable-next-line no-process-exit
    process.exit(EXIT_CODES.GENERAL_ERROR);
  });

// Export for testing
export {
  main,
  parseArguments,
  orchestrateExecution,
  showHelp,
  showVersion,
  EXIT_CODES,
  registerCleanupHandler
};
