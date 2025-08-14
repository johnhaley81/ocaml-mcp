/**
 * ConfigGenerator - Generates MCP configuration for OCaml MCP Server
 * 
 * This class generates MCP (Model Context Protocol) server configurations
 * specifically for the OCaml MCP Server package.
 */
export class ConfigGenerator {
  /**
   * Generates MCP configuration object for the OCaml MCP Server
   * 
   * @param {string} [repoUrl] - Optional repository URL to include in configuration
   * @returns {object} MCP configuration object
   */
  generateConfig(repoUrl) {
    // Determine args based on repoUrl
    let args = [];
    
    // Include --repo parameter only if repoUrl is provided and not empty/whitespace-only
    if (repoUrl != null && typeof repoUrl === 'string' && repoUrl.trim() !== '') {
      args = ['--repo', repoUrl];
    }
    
    // Return MCP configuration structure
    return {
      mcpServers: {
        'ocaml-mcp-server': {
          command: ['npx', '@ocaml-mcp/server'],
          args: args,
          cwd: '${workspaceFolder}'
        }
      }
    };
  }
}