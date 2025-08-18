# Product Steering

## Vision & Mission

### Problem Statement
OCaml developers struggle with integrating AI coding assistants into their workflow due to the lack of accessible tooling that understands OCaml projects. While MCP (Model Context Protocol) provides a powerful framework for AI-context integration, existing OCaml MCP solutions require complex manual setup and deep OCaml ecosystem knowledge.

### Target Users
- **Primary**: OCaml developers using AI coding assistants (Claude, etc.)
- **Secondary**: AI researchers and teams working with OCaml codebases
- **Tertiary**: Developer tooling creators building OCaml-aware solutions

### Long-term Vision
Create the most accessible and powerful OCaml development experience for AI-assisted coding. Make OCaml projects as AI-friendly as JavaScript or Python projects, with zero-friction setup and deep language understanding.

## User Experience Principles

### Core UX Guidelines
- **Zero Configuration**: Tools should work immediately without setup
- **Developer Familiar**: Use patterns developers already know (NPX, opam, standard commands)
- **Progressive Enhancement**: Basic features work everywhere, advanced features when possible
- **Fail Gracefully**: Clear error messages with actionable solutions

### Design System Principles
- **Consistency**: All tools follow similar patterns and conventions
- **Transparency**: Users understand what's happening under the hood
- **Reliability**: Predictable behavior across different environments
- **Performance**: Fast execution, minimal overhead

### Accessibility Requirements
- Support multiple platforms (macOS, Linux, Windows with WSL)
- Work with different OCaml setups (opam switches, system installs)
- Clear documentation for different experience levels
- Offline-capable where possible

### Performance Standards
- NPX wrapper startup: < 2 seconds for cached installs
- MCP server response time: < 500ms for typical operations
- Memory usage: < 100MB for typical OCaml projects
- Auto-installation: Complete within 3 minutes on typical internet

## Feature Priorities

### Must-Have Features (MVP)
1. **NPX Wrapper**: Zero-config installation and execution
2. **Auto-Installation**: Automatic opam pin from repository
3. **Project Detection**: Intelligent OCaml project discovery
4. **Dune Integration**: Real-time build status and errors
5. **Module Signatures**: Extract and analyze OCaml modules
6. **MCP Compliance**: Full compatibility with MCP protocol

### Nice-to-Have Features (V2)
1. **Custom Repository Support**: Pin from any git repository
2. **Configuration Generation**: Auto-generate MCP client configs
3. **Multiple Projects**: Handle workspace with multiple OCaml projects
4. **Advanced Diagnostics**: Merlin integration for type checking
5. **Performance Optimization**: Caching and incremental updates

### Future Roadmap Items (V3+)
1. **VS Code Extension**: Direct IDE integration
2. **GitHub Actions**: CI/CD integration for OCaml projects
3. **Multi-language Support**: Support ReasonML, Dune polyglot projects
4. **Cloud Integration**: Remote development support
5. **Team Features**: Shared configurations and collaborative tools

## Success Metrics

### Key Performance Indicators
- **Adoption Rate**: NPX package downloads per month
- **Setup Success Rate**: % of installations that complete successfully
- **Time to First Success**: Average time from npx command to working MCP server
- **User Retention**: % of users who use the tool multiple times

### User Satisfaction Measures
- **GitHub Issues**: Bug reports vs. feature requests ratio
- **Documentation Feedback**: Clarity and completeness ratings
- **Community Engagement**: Discussions, contributions, forks
- **Support Load**: Number of support requests per user

### Business Metrics
- **Developer Productivity**: Reduction in OCaml development setup time
- **Ecosystem Growth**: Increase in OCaml MCP server adoption
- **Tool Integration**: Number of AI clients supporting our MCP server
- **Community Contribution**: External contributions to codebase

## Key Product Decisions

### Technology Philosophy
- **Leverage Existing Ecosystems**: Build on NPM for distribution, opam for OCaml
- **Minimal Dependencies**: Reduce external dependencies to improve reliability
- **Standard Patterns**: Follow established patterns from other successful dev tools
- **Open Source First**: Everything public, community-driven development

### Distribution Strategy
- **NPM as Primary**: Use NPX for discovery and initial installation
- **Opam for Runtime**: Actual server runs from opam ecosystem
- **Documentation Focus**: Comprehensive guides for different user types
- **Integration Examples**: Clear examples for popular AI clients

### Quality Standards
- **Test Coverage**: 90%+ code coverage with comprehensive integration tests
- **Documentation**: Every feature documented with examples
- **Error Handling**: Every error case has clear user-facing messages
- **Platform Support**: Works on all major development platforms

## Anti-Patterns to Avoid

### UX Anti-Patterns
- **Over-configuration**: Requiring users to specify obvious defaults
- **Silent Failures**: Failing without clear explanation or recovery steps
- **Platform Lock-in**: Creating dependencies on specific tools or vendors
- **Version Conflicts**: Breaking when users have different OCaml versions

### Technical Anti-Patterns
- **Heavy Dependencies**: Adding large dependencies for small features
- **Hard-coded Paths**: Assuming specific directory structures or locations
- **Global State**: Modifying global system state without user consent
- **Security Holes**: Executing untrusted code or exposing sensitive information

This product steering establishes our commitment to making OCaml AI-assisted development as smooth and accessible as possible, while maintaining the power and flexibility that OCaml developers expect.