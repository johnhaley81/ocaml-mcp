# Testing Guide

This project uses Jest as the testing framework with comprehensive linting and formatting tools.

## Available Scripts

### Testing

- `npm test` - Run all tests with coverage
- `npm run test:coverage` - Run tests and generate detailed coverage report
- `npm run test:watch` - Run tests in watch mode for development

### Code Quality

- `npm run lint` - Check code with ESLint
- `npm run lint:fix` - Fix ESLint issues automatically
- `npm run format` - Format code with Prettier
- `npm run format:check` - Check if code is properly formatted

## Testing Configuration

### Jest Configuration

- **Environment**: Node.js
- **Test Patterns**: `**/*.test.js`, `**/*.spec.js`, `**/__tests__/**/*.js`
- **Coverage Threshold**: 90% for all metrics (branches, functions, lines, statements)
- **Coverage Directory**: `./coverage/`
- **Mock Support**: Automatic mocking with cleanup between tests

### ESLint Configuration

- **Environment**: Node.js with ES2022 support
- **Style**: Single quotes, semicolons, 2-space indentation
- **Plugins**: Node.js and Jest specific rules
- **Auto-fix**: Supports automatic fixing of style issues

### Prettier Configuration

- **Style**: Single quotes, no trailing commas, 2-space tabs
- **Line Width**: 80 characters
- **End of Line**: LF (Unix style)

## Writing Tests

### Basic Test Structure

```javascript
describe('Feature Name', () => {
  test('should do something specific', () => {
    // Arrange
    const input = 'test';

    // Act
    const result = someFunction(input);

    // Assert
    expect(result).toBe('expected');
  });
});
```

### Async Testing

```javascript
test('should handle async operations', async () => {
  const result = await asyncFunction();
  expect(result).toBeDefined();
});
```

### Mocking File System

```javascript
test('should mock fs operations', () => {
  const fs = require('fs');
  const mockReadFile = jest
    .spyOn(fs, 'readFileSync')
    .mockReturnValue('mocked content');

  const result = someFileOperation();

  expect(mockReadFile).toHaveBeenCalled();
  mockReadFile.mockRestore();
});
```

### Mocking Process

```javascript
test('should mock process properties', () => {
  const originalPlatform = process.platform;

  Object.defineProperty(process, 'platform', {
    value: 'test-platform',
    configurable: true
  });

  // Test code here

  // Restore
  Object.defineProperty(process, 'platform', {
    value: originalPlatform,
    configurable: true
  });
});
```

## Test Organization

- Place unit tests in `__tests__/` directory or alongside source files with `.test.js` suffix
- Use descriptive test names that explain the expected behavior
- Group related tests using `describe` blocks
- Use `beforeEach`/`afterEach` for setup/cleanup when needed

## Coverage Reports

Coverage reports are generated in the `coverage/` directory:

- `coverage/lcov-report/index.html` - HTML coverage report
- `coverage/lcov.info` - LCOV format for CI/CD integration
- `coverage/coverage-final.json` - JSON format for programmatic access

## Continuous Integration

The `prepack` script ensures all tests pass and code is properly formatted before publishing:

```bash
npm run prepack  # Runs: test + lint + format:check
```

## Best Practices

1. **Write tests first** (TDD approach)
2. **Test behavior, not implementation**
3. **Use descriptive test names**
4. **Keep tests simple and focused**
5. **Mock external dependencies**
6. **Maintain 90%+ code coverage**
7. **Run linting and formatting before commits**
