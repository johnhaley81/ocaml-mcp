# @ocaml-mcp/server

NPX wrapper for the OCaml MCP (Model Context Protocol) server - provides seamless installation and execution of OCaml development tools through MCP.

## Features

- 🚀 **Zero Configuration** - Automatically installs and manages the OCaml MCP server
- 🔧 **Smart Detection** - Validates OCaml project context before execution
- 📦 **Dependency Management** - Handles opam installation transparently
- 🔌 **MCP Integration** - Generates configuration for AI tools (Claude, Cursor, etc.)
- 🌍 **Cross-Platform** - Works on macOS and Linux with opam

## Quick Start

### Running the Server

In any OCaml project directory (containing `dune-project` or `*.opam` files):

```bash
npx @ocaml-mcp/server
```

On first run, the wrapper will:
1. Detect your OCaml project
2. Install the ocaml-mcp-server via opam
3. Start the MCP server

### Generate MCP Configuration

To generate configuration for your AI tool:

```bash
npx @ocaml-mcp/server --print-config
```

This outputs JSON configuration that can be added to:
- Claude Desktop: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Cursor: `.cursor/mcp_config.json`
- Other MCP-compatible tools

Example output:
```json
{
  "mcpServers": {
    "ocaml-mcp-server": {
      "command": ["npx", "@ocaml-mcp/server"],
      "args": [],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

## Installation Options

### Default Installation

By default, the wrapper installs from the official repository:

```bash
npx @ocaml-mcp/server
```

### Custom Repository

To install from a specific repository or fork:

```bash
npx @ocaml-mcp/server --repo https://github.com/your-fork/ocaml-mcp
```

### Local Development

For local development or testing:

```bash
npx @ocaml-mcp/server --repo file:///path/to/local/ocaml-mcp
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `--help, -h` | Show help message |
| `--version, -v` | Show version information |
| `--print-config` | Print MCP configuration and exit |
| `--repo <url>` | Custom repository URL for installation |
| `--verbose` | Enable verbose logging |
| `--dry-run` | Show what would be executed without running |
| `--` | Pass remaining arguments to the server |

### Passing Server Arguments

To pass arguments to the underlying ocaml-mcp-server:

```bash
npx @ocaml-mcp/server -- --port 3000 --log-level debug
```

## Requirements

### System Requirements

- Node.js >= 14.0.0
- opam (OCaml package manager)
- OCaml project with `dune-project` or `*.opam` files

### Installing opam

If opam is not installed:

**macOS:**
```bash
brew install opam
opam init
```

**Ubuntu/Debian:**
```bash
apt-get install opam
opam init
```

**Other Linux:**
```bash
sh <(curl -sL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)
opam init
```

## Troubleshooting

### "Not an OCaml project" Error

The wrapper requires OCaml project markers. Ensure your project has:
- A `dune-project` file, OR
- One or more `*.opam` files

### "opam not found" Error

Install opam following the instructions above, then run:
```bash
eval $(opam env)
```

### Installation Fails

If automatic installation fails:

1. **Update opam repositories:**
   ```bash
   opam update
   ```

2. **Install manually:**
   ```bash
   opam pin add ocaml-mcp-server https://github.com/tmattio/ocaml-mcp.git
   opam install ocaml-mcp-server
   ```

3. **Use local installation:**
   ```bash
   git clone https://github.com/tmattio/ocaml-mcp.git
   cd ocaml-mcp
   opam install . --deps-only
   dune build
   ```

### Network Issues

Behind a corporate proxy:
```bash
export HTTP_PROXY=http://proxy:port
export HTTPS_PROXY=http://proxy:port
npx @ocaml-mcp/server
```

### Permission Denied

If you encounter permission errors:
```bash
npm config set prefix ~/.npm-global
export PATH=~/.npm-global/bin:$PATH
```

## MCP Client Configuration

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "ocaml-mcp-server": {
      "command": ["npx", "@ocaml-mcp/server"],
      "args": [],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

### Cursor

Add to `.cursor/mcp_config.json` in your project:

```json
{
  "mcpServers": {
    "ocaml-mcp-server": {
      "command": ["npx", "@ocaml-mcp/server"],
      "args": ["--repo", "https://github.com/your-fork/ocaml-mcp"],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

### VS Code with Continue

Add to `.continue/config.json`:

```json
{
  "models": [...],
  "mcpServers": {
    "ocaml-mcp-server": {
      "command": ["npx", "@ocaml-mcp/server"],
      "args": [],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

## Available MCP Tools

Once running, the OCaml MCP server provides these tools to AI assistants:

- **dune_build** - Build OCaml projects
- **dune_test** - Run tests
- **dune_exec** - Execute binaries
- **dune_clean** - Clean build artifacts
- **read_file** - Read source files
- **write_file** - Modify source files
- **search_code** - Search in codebase
- **get_diagnostics** - Get compilation errors

## Development

### Running Tests

```bash
cd npx-wrapper
npm test
```

### Running Integration Tests

```bash
npm run test:integration
```

### Local Testing

To test the wrapper locally without publishing:

```bash
cd npx-wrapper
npm link
cd /path/to/ocaml/project
npx @ocaml-mcp/server
```

## Architecture

The NPX wrapper follows a modular architecture:

1. **Argument Parser** - Processes CLI arguments
2. **Project Detector** - Validates OCaml project context
3. **Opam Manager** - Handles server installation
4. **Binary Executor** - Delegates to ocaml-mcp-server
5. **Config Generator** - Creates MCP configurations
6. **Error Handler** - Provides actionable error messages

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

ISC License - see LICENSE file for details.

## Support

- **Issues:** [GitHub Issues](https://github.com/tmattio/ocaml-mcp/issues)
- **Discussions:** [GitHub Discussions](https://github.com/tmattio/ocaml-mcp/discussions)
- **OCaml MCP Server:** [Main Repository](https://github.com/tmattio/ocaml-mcp)

## Changelog

### 0.1.0 (Initial Release)
- Zero-configuration NPX wrapper
- Automatic opam installation
- MCP configuration generation
- Cross-platform support (macOS, Linux)
- Comprehensive error handling