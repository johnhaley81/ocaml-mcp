/** @type {import('jest').Config} */
module.exports = {
  // Test environment
  testEnvironment: 'node',

  // Enable ES modules support
  preset: undefined,
  transform: {},
  transformIgnorePatterns: [
    'node_modules/'
  ],

  // Root directory for tests and modules
  rootDir: '.',

  // Test file patterns
  testMatch: ['**/__tests__/**/*.js', '**/*.test.js', '**/*.spec.js'],

  // Ignore patterns
  testPathIgnorePatterns: ['/node_modules/', '/coverage/', '/dist/', '/build/'],

  // Coverage configuration
  collectCoverage: true,
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'text-summary', 'html', 'lcov', 'json'],

  // Coverage thresholds (90% minimum)
  coverageThreshold: {
    global: {
      branches: 90,
      functions: 90,
      lines: 90,
      statements: 90
    }
  },

  // Files to collect coverage from
  collectCoverageFrom: [
    'lib/**/*.js',
    'bin/**/*.js',
    '!**/node_modules/**',
    '!**/coverage/**',
    '!**/dist/**',
    '!**/build/**',
    '!**/*.config.js',
    '!**/*.test.js',
    '!**/*.spec.js'
  ],

  // Setup and teardown
  setupFilesAfterEnv: [],

  // Module resolution
  moduleFileExtensions: ['js', 'json'],

  // Clear mocks between tests
  clearMocks: true,

  // Restore mocks after each test
  restoreMocks: true,

  // Reset mocks between tests
  resetMocks: true,

  // Verbose output for better debugging
  verbose: true,

  // Timeout for tests (10 seconds)
  testTimeout: 10000,

  // Error handling
  errorOnDeprecated: true,

  // Performance
  maxWorkers: '50%',

  // Watch plugins for interactive mode
  watchPlugins: [
    'jest-watch-typeahead/filename',
    'jest-watch-typeahead/testname'
  ]
};
