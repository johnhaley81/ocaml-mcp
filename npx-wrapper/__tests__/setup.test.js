/**
 * Setup test to verify Jest configuration
 */

describe('Jest Configuration Test', () => {
  test('should be able to run basic tests', () => {
    expect(true).toBe(true);
  });

  test('should support async/await patterns', async () => {
    const promise = Promise.resolve('test');
    const result = await promise;
    expect(result).toBe('test');
  });

  test('should have access to Node.js globals', () => {
    expect(process).toBeDefined();
    expect(global).toBeDefined();
    expect(console).toBeDefined();
  });

  test('should be able to mock modules', () => {
    const mockFn = jest.fn();
    mockFn('test');
    expect(mockFn).toHaveBeenCalledWith('test');
    expect(mockFn).toHaveBeenCalledTimes(1);
  });

  test('should support filesystem mocking', () => {
    const fs = require('fs');
    const mockReadFile = jest
      .spyOn(fs, 'readFileSync')
      .mockReturnValue('mocked content');

    const result = fs.readFileSync('/fake/path');
    expect(result).toBe('mocked content');
    expect(mockReadFile).toHaveBeenCalledWith('/fake/path');

    mockReadFile.mockRestore();
  });

  test('should support process mocking', () => {
    const originalPlatform = process.platform;
    const originalArgv = process.argv;

    // Mock process properties
    Object.defineProperty(process, 'platform', {
      value: 'test-platform',
      configurable: true
    });

    process.argv = ['node', 'test.js', '--test'];

    expect(process.platform).toBe('test-platform');
    expect(process.argv).toContain('--test');

    // Restore original values
    Object.defineProperty(process, 'platform', {
      value: originalPlatform,
      configurable: true
    });
    process.argv = originalArgv;
  });
});
