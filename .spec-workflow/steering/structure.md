# Structure Steering

## Project Organization

### Repository Structure
```
ocaml-mcp/
├── .spec-workflow/              # Specification and workflow documents
│   ├── steering/                # Product, technical, and structure steering
│   ├── specs/                   # Feature specifications
│   └── bugs/                    # Bug reports and fixes
├── lib/                         # OCaml libraries (existing)
│   ├── mcp/                     # Core MCP protocol
│   ├── mcp-eio/                 # Transport layer
│   ├── mcp-sdk-eio/             # High-level SDK
│   └── ocaml-mcp-server/        # Server implementation
├── bin/                         # OCaml executables (existing)
│   ├── ocaml_mcp_server.ml      # Main server binary
│   └── mcp_client.ml            # Client example
├── npx-wrapper/                 # NEW: NPX wrapper package
│   ├── package.json             # NPM package configuration
│   ├── bin/                     # Executable wrapper scripts
│   │   └── ocaml-mcp-server.js  # Main NPX wrapper
│   ├── lib/                     # Wrapper implementation modules
│   │   ├── argument-parser.js   # Command-line argument parsing
│   │   ├── project-detector.js  # OCaml project detection
│   │   ├── opam-manager.js      # Opam installation management
│   │   ├── binary-executor.js   # Binary execution wrapper
│   │   └── config-generator.js  # MCP configuration generation
│   ├── __tests__/               # Test suites
│   │   ├── unit/                # Unit tests
│   │   └── integration/         # Integration tests
│   └── README.md                # NPX package documentation
├── test/                        # OCaml tests (existing)
├── spec/                        # Protocol specifications (existing)
├── docs/                        # Documentation
└── README.md                    # Main project documentation
```

### File Naming Conventions

#### OCaml Components (Existing Patterns)
- **Libraries**: `kebab-case` directory names (`mcp-eio`, `ocaml-mcp-server`)
- **Modules**: `PascalCase` for module names (`Mcp_types`, `Ocaml_mcp_server`)
- **Files**: `snake_case.ml` for implementation, `snake_case.mli` for interfaces
- **Tests**: Mirror source structure with `.test.ml` suffix

#### NPX Wrapper Components (Node.js Patterns)
- **Package**: `@ocaml-mcp/server` (scoped, kebab-case)
- **Files**: `kebab-case.js` for modules (`argument-parser.js`)
- **Tests**: `*.test.js` for unit tests, `*.integration.test.js` for integration
- **Directories**: `kebab-case` for logical groupings

### Module Organization

#### NPX Wrapper Modules
- **Single Responsibility**: Each module handles one specific concern
- **Clear Interfaces**: Export only necessary functions
- **Dependency Injection**: Accept dependencies as parameters
- **Error Handling**: Return Result-style objects for error management

#### Module Dependencies
```
argument-parser.js (pure)
    ↑
project-detector.js (file system)
    ↑
opam-manager.js (process spawning)
    ↑
binary-executor.js (process delegation)
    ↑
config-generator.js (JSON generation)
    ↑
main wrapper script
```

### Configuration Management

#### Package Configuration
- **package.json**: NPM package metadata and dependencies
- **.gitignore**: Exclude node_modules, dist, coverage
- **.eslintrc.js**: Code quality and style rules
- **jest.config.js**: Test framework configuration

#### Environment Variables
- **OCAML_MCP_REPO**: Override default repository URL
- **OCAML_MCP_DEBUG**: Enable debug logging
- **NODE_ENV**: Environment (test, development, production)

## Development Workflow

### Git Branching Strategy

#### Branch Types
- **main**: Stable release branch, always deployable
- **develop**: Integration branch for features
- **feature/**: Individual feature branches
- **hotfix/**: Critical bug fixes for production
- **release/**: Release preparation branches

#### Naming Conventions
- **Features**: `feature/npx-wrapper-auto-install`
- **Bugs**: `bugfix/installation-error-handling`
- **Hotfixes**: `hotfix/security-patch-v1.2.1`
- **Releases**: `release/v1.3.0`

#### Merge Strategy
- **Feature → Develop**: Squash merge with detailed commit message
- **Develop → Main**: Merge commit to preserve history
- **Hotfix → Main**: Direct merge for critical fixes
- **Release → Main**: Merge commit with version tag

### Code Review Process

#### Review Requirements
- **Minimum Reviews**: 1 approval required for merge
- **Testing**: All tests must pass before merge
- **Documentation**: Updates must include relevant docs

#### Review Checklist
- [ ] Code follows established patterns and conventions
- [ ] Tests provide adequate coverage and scenarios
- [ ] Documentation is updated and accurate
- [ ] No security vulnerabilities introduced
- [ ] Performance impact is acceptable
- [ ] Error handling is comprehensive

### Testing Workflow

#### Test Types and Requirements
- **Unit Tests**: 90%+ code coverage, fast execution
- **Integration Tests**: Test real opam interactions
- **End-to-End Tests**: Test complete user workflows
- **Performance Tests**: Verify startup and execution times

#### Test Execution Strategy
```bash
# Local development
npm test                    # Run all tests
npm run test:unit          # Unit tests only
npm run test:integration   # Integration tests
npm run test:coverage      # Coverage report

# CI/CD pipeline
- Unit tests on every commit
- Integration tests on PRs
- E2E tests on release branches
- Performance tests on release
```

### Deployment Process

#### NPM Package Deployment
1. **Version Bump**: Update package.json version (semantic versioning)
2. **Build**: Generate any compiled assets
3. **Test**: Run complete test suite
4. **Package**: Create npm package tarball
5. **Publish**: Deploy to NPM registry
6. **Tag**: Create git tag for version

#### Release Automation
- **GitHub Actions**: Automated testing and deployment
- **Semantic Release**: Automated version management
- **Changelog**: Auto-generated from commit messages
- **Notifications**: Alert team of successful deployments

## Documentation Structure

### Document Types and Locations

#### Project Documentation
- **README.md**: Quick start and overview (repo root)
- **npx-wrapper/README.md**: NPX package specific docs
- **docs/**: Comprehensive documentation
- **.spec-workflow/**: Specifications and design docs

#### Code Documentation
- **JSDoc Comments**: Inline API documentation
- **README per Module**: Complex modules get their own docs
- **Examples**: Working code examples in docs/examples/
- **Troubleshooting**: Common issues and solutions

### Documentation Standards
- **Keep It Updated**: Docs updated with every feature
- **Examples First**: Show usage before explaining theory
- **Multiple Audiences**: Beginner, intermediate, advanced sections
- **Searchable**: Clear headings and cross-references

### Spec Organization (MCP Workflow)
- **Requirements**: User stories and acceptance criteria
- **Design**: Architecture and component design
- **Tasks**: Implementation breakdown and tracking
- **Approval Process**: Review and approval workflow

## Team Conventions

### Communication Guidelines

#### Channels and Usage
- **GitHub Issues**: Bug reports, feature requests, discussions
- **Pull Requests**: Code changes, reviews, and approvals
- **Commit Messages**: Clear, descriptive, conventional format
- **Documentation**: Inline comments for complex logic

#### Commit Message Format
```
type(scope): brief description

More detailed explanation if needed

Closes #123
```

Types: feat, fix, docs, style, refactor, test, chore
Scopes: wrapper, server, docs, ci, etc.

### Decision-Making Process

#### Decision Types
- **Technical Decisions**: Architecture, tools, patterns
- **Product Decisions**: Features, priorities, roadmap
- **Process Decisions**: Workflow, quality standards, conventions

#### Decision Authority
- **Individual**: Small technical choices, code style
- **Team Consensus**: Major architecture, new tools
- **Maintainer**: Final decisions on conflicts or direction
- **Community Input**: Open source feedback and contributions

### Knowledge Sharing

#### Documentation Strategy
- **Architectural Decision Records**: Document major decisions
- **Runbooks**: Operational procedures and troubleshooting
- **Onboarding Guide**: New contributor setup and orientation
- **FAQ**: Common questions and answers

#### Learning Resources
- **Code Examples**: Working examples for common patterns
- **Video Walkthroughs**: Complex setup or debugging sessions
- **Blog Posts**: Share learnings and best practices
- **Conference Talks**: Present work to broader community

## Quality Assurance

### Code Quality Standards
- **Linting**: ESLint for JavaScript, OCamlformat for OCaml
- **Testing**: Comprehensive test coverage with multiple types
- **Type Safety**: JSDoc for JavaScript, native types for OCaml
- **Performance**: Regular performance testing and optimization

### Release Quality Gates
- [ ] All tests pass (unit, integration, e2e)
- [ ] Code coverage meets threshold (90%+)
- [ ] Security scan passes
- [ ] Documentation is updated
- [ ] Performance benchmarks are acceptable
- [ ] Manual testing completed

### Monitoring and Observability
- **Error Tracking**: Monitor runtime errors and crashes
- **Usage Analytics**: Track adoption and feature usage
- **Performance Monitoring**: Monitor startup and execution times
- **User Feedback**: Collect and analyze user feedback

## Maintenance and Evolution

### Regular Maintenance Tasks
- **Dependency Updates**: Keep dependencies current and secure
- **Security Patches**: Apply security updates promptly
- **Performance Optimization**: Regular performance reviews
- **Documentation Updates**: Keep docs synchronized with code

### Evolution Strategy
- **Backward Compatibility**: Maintain compatibility when possible
- **Deprecation Process**: Clear communication and migration paths
- **Feature Flags**: Safe rollout of new features
- **Community Engagement**: Gather feedback and contributions

This structure steering provides the organizational foundation for maintaining a high-quality, collaborative, and sustainable OCaml MCP project that scales with the team and community.