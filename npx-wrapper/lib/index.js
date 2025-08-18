/**
 * OCaml MCP Server NPX Wrapper - Library Entry Point
 *
 * This module exports the main functionality for programmatic use.
 * The primary interface is through the CLI, but this allows integration
 * into other Node.js applications if needed.
 */

import {
  main,
  parseArguments,
  orchestrateExecution,
  EXIT_CODES
} from '../bin/ocaml-mcp-server.js';

/**
 * Main exports for programmatic usage
 */
export { main, parseArguments, orchestrateExecution, EXIT_CODES };

/**
 * Default export for CommonJS compatibility
 */
export default {
  main,
  parseArguments,
  orchestrateExecution,
  EXIT_CODES
};
