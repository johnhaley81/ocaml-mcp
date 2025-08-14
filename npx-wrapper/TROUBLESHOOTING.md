# OCaml MCP Server NPX Wrapper - Troubleshooting Guide

This guide helps resolve common issues when using `npx @ocaml-mcp/server`.

## 🚀 Quick Diagnostics

Run these commands to check your environment:

```bash
# Test the wrapper
npx @ocaml-mcp/server --help

# Check OCaml environment
opam --version
opam switch show
ocaml -version

# Generate configuration
npx @ocaml-mcp/server --print-config
```

## 🔧 Common Issues and Solutions

### 1. Dependency Resolution Failures

**Error**: `Cannot resolve dependencies` or `Package conflict`

**Symptoms**:
- Installation fails with dependency errors
- Missing package errors (lwt, yojson, cmdliner)
- Version conflicts between packages

**Solutions** (try in order):

```bash
# 1. Update OPAM repository
opam update

# 2. Upgrade existing packages
opam upgrade

# 3. Install core dependencies manually
opam install lwt yojson cmdliner dune

# 4. Create a fresh OPAM switch
opam switch create ocaml-mcp 5.0.0
eval $(opam env)

# 5. Use Docker as fallback
docker run -it ocaml/opam:ubuntu opam install ocaml-mcp-server
```

### 2. OPAM Not Available

**Error**: `OPAM is not installed` or `opam: command not found`

**Solutions**:

**macOS**:
```bash
# Install via Homebrew
brew install opam

# Initialize OPAM
opam init
eval $(opam env)
```

**Linux (Ubuntu/Debian)**:
```bash
# Install via package manager
sudo apt update
sudo apt install opam

# Initialize OPAM
opam init
eval $(opam env)
```

**Linux (CentOS/RHEL)**:
```bash
# Install via package manager
sudo yum install opam
# or
sudo dnf install opam

# Initialize OPAM
opam init
eval $(opam env)
```

### 3. No OPAM Switch Set

**Error**: `No switch is currently set`

**Solutions**:

```bash
# List available switches
opam switch list

# Create a new switch
opam switch create ocaml-mcp 5.0.0

# Or use an existing switch
opam switch <switch-name>

# Apply environment
eval $(opam env)
```

### 4. Network and Connectivity Issues

**Error**: `Network connectivity issue` or `Connection failed`

**Solutions**:

```bash
# Test connectivity
ping opam.ocaml.org
ping github.com

# Configure proxy (if behind corporate firewall)
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080

# Use VPN if required
# Connect to company VPN and retry

# Test with verbose output
opam install ocaml-mcp-server --verbose
```

### 5. Git Authentication Failures

**Error**: `Authentication failed` or `Permission denied (publickey)`

**Solutions**:

```bash
# Test SSH access
ssh -T git@github.com

# Generate SSH key if needed
ssh-keygen -t ed25519 -C "your-email@example.com"

# Add key to SSH agent
ssh-add ~/.ssh/id_ed25519

# Use HTTPS instead of SSH
npx @ocaml-mcp/server --repo https://github.com/tmattio/ocaml-mcp.git
```

### 6. Compilation Failures

**Error**: `Compilation failed` or `Build failed`

**Solutions**:

```bash
# Install build dependencies
opam install dune ocamlfind

# Update to newer OCaml version
opam switch create build-env 5.0.0
eval $(opam env)

# Clean and retry
opam clean
opam install ocaml-mcp-server

# Linux: Install system dependencies
sudo apt install build-essential pkg-config

# macOS: Install Xcode command line tools
xcode-select --install
```

### 7. Permission Denied Errors

**Error**: `Permission denied` or `Cannot write to opam switch`

**Solutions**:

```bash
# Fix OPAM directory permissions
sudo chown -R $USER ~/.opam

# Reinstall OPAM if corrupted
rm -rf ~/.opam
opam init

# Use a new switch location
opam switch create --root /tmp/opam-temp temp-switch
```

## 🐳 Docker Fallback

If all else fails, use Docker:

```bash
# Run OCaml MCP Server in Docker
docker run -it --rm \
  -v "$(pwd):/workspace" \
  -w /workspace \
  ocaml/opam:ubuntu bash -c "
    opam update && 
    opam install ocaml-mcp-server && 
    opam exec -- ocaml-mcp-server --help
  "
```

## 🔍 Advanced Debugging

### Environment Diagnostics

```bash
# Check OPAM configuration
opam config list
opam doctor

# Check repository status
opam repository list
opam update --dry-run

# Check package availability
opam show lwt yojson cmdliner dune

# Check system dependencies
which git gcc make pkg-config
```

### Verbose Installation

```bash
# Get detailed installation logs
npx @ocaml-mcp/server --repo https://github.com/tmattio/ocaml-mcp.git --verbose

# Manual OPAM installation with full output
opam pin add ocaml-mcp-server https://github.com/tmattio/ocaml-mcp.git --verbose --yes
```

### Clean Environment Setup

```bash
# Start fresh with a new switch
opam switch create debug-mcp 5.0.0
eval $(opam env)

# Install with minimal dependencies
opam install --deps-only ocaml-mcp-server

# Then install the package
opam pin add ocaml-mcp-server https://github.com/tmattio/ocaml-mcp.git
```

## 📚 Environment-Specific Issues

### Corporate/Enterprise Environments

**Common Issues**:
- Proxy servers blocking OPAM repositories
- Firewall restrictions on Git/SSH
- Restricted package repositories

**Solutions**:
```bash
# Configure corporate proxy
export HTTP_PROXY=http://corporate-proxy:8080
export HTTPS_PROXY=http://corporate-proxy:8080

# Use HTTPS instead of SSH for Git
git config --global url."https://github.com/".insteadOf git@github.com:

# Add custom OPAM repository if available
opam repo add corporate-repo https://opam.corp.company.com/
```

### Restricted Internet Access

**Solutions**:
```bash
# Download packages manually
wget https://github.com/tmattio/ocaml-mcp/archive/main.zip
unzip main.zip
opam pin add ocaml-mcp-server ./ocaml-mcp-main/

# Use offline package cache
opam install --download-only ocaml-mcp-server
# Transfer to restricted machine and install
```

### Virtual Environments (Docker, VM)

**Considerations**:
- Ensure adequate memory (>= 2GB for compilation)
- Mount project directory correctly
- Use appropriate base images with OPAM pre-installed

## 🆘 Getting Help

If you're still experiencing issues:

1. **Check our FAQ**: [Link to FAQ section]
2. **Search existing issues**: [GitHub Issues](https://github.com/johnhaley81/ocaml-mcp-server/issues)
3. **Create a new issue** with:
   - Output of `npx @ocaml-mcp/server --version`
   - Your operating system and version
   - Output of `opam config list`
   - Complete error message and stack trace
   - Steps to reproduce

## 📝 Manual Installation Alternative

If the NPX wrapper continues to fail, install manually:

```bash
# Clone the repository
git clone https://github.com/tmattio/ocaml-mcp.git
cd ocaml-mcp

# Install using OPAM
opam install . --deps-only
dune build
dune install

# Test installation
which ocaml-mcp-server
ocaml-mcp-server --help
```

## 🔄 Reporting Issues

When reporting issues, please include:

```bash
# System information
uname -a
opam --version
ocaml -version
node --version
npm --version

# OPAM environment
opam switch show
opam repository list
opam config list

# Error reproduction
npx @ocaml-mcp/server --verbose --repo https://github.com/tmattio/ocaml-mcp.git
```

This information helps maintainers diagnose and resolve issues quickly.