const globals = require('globals');

module.exports = {
  // Environment and parser options
  env: {
    node: true,
    es2022: true,
    jest: true
  },

  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'module'
  },

  // Global variables
  globals: {
    ...globals.node,
    ...globals.jest
  },

  // Extends
  extends: [
    'eslint:recommended',
    'plugin:node/recommended',
    'plugin:jest/recommended'
  ],

  // Plugins
  plugins: ['node', 'jest'],

  // Rules
  rules: {
    // Error prevention
    'no-console': 'off', // Allow console in CLI tools
    'no-unused-vars': [
      'error',
      {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_'
      }
    ],
    'no-undef': 'error',
    'no-unreachable': 'error',
    'no-duplicate-imports': 'error',

    // Code style
    indent: ['error', 2],
    quotes: ['error', 'single', { avoidEscape: true }],
    semi: ['error', 'always'],
    'comma-dangle': ['error', 'never'],
    'object-curly-spacing': ['error', 'always'],
    'array-bracket-spacing': ['error', 'never'],
    'space-before-function-paren': ['error', 'never'],
    'keyword-spacing': 'error',
    'space-infix-ops': 'error',
    'eol-last': 'error',
    'no-trailing-spaces': 'error',

    // Node.js specific
    'node/no-unpublished-require': 'off', // Allow dev dependencies in tests
    'node/no-missing-require': 'error',
    'node/no-extraneous-require': 'error',
    'node/prefer-global/process': 'error',
    'node/prefer-global/console': 'error',
    'node/prefer-promises/fs': 'error',
    'node/prefer-promises/dns': 'error',

    // Async/await best practices
    'require-await': 'error',
    'no-async-promise-executor': 'error',
    'no-await-in-loop': 'warn',
    'prefer-promise-reject-errors': 'error',

    // Jest specific rules
    'jest/expect-expect': 'error',
    'jest/no-disabled-tests': 'warn',
    'jest/no-focused-tests': 'error',
    'jest/no-identical-title': 'error',
    'jest/prefer-to-have-length': 'warn',
    'jest/valid-expect': 'error',
    'jest/no-conditional-expect': 'error',
    'jest/no-deprecated-functions': 'error',

    // Security
    'no-eval': 'error',
    'no-implied-eval': 'error',
    'no-new-func': 'error'
  },

  // Override rules for specific file patterns
  overrides: [
    {
      files: ['*.test.js', '*.spec.js', '**/__tests__/**/*.js'],
      env: {
        jest: true
      },
      parserOptions: {
        sourceType: 'commonjs'
      },
      rules: {
        'node/no-unpublished-require': 'off',
        'no-magic-numbers': 'off',
        'space-before-function-paren': 'off'
      }
    },
    {
      files: ['*.config.js', '*.cjs'],
      env: {
        node: true
      },
      parserOptions: {
        sourceType: 'commonjs'
      },
      rules: {
        'node/no-unpublished-require': 'off'
      }
    },
    {
      files: ['bin/**/*.js', 'lib/**/*.js'],
      parserOptions: {
        sourceType: 'module'
      },
      rules: {
        'node/no-unsupported-features/es-syntax': 'off',
        'node/no-unpublished-import': 'off'
      }
    }
  ],

  // Ignore patterns
  ignorePatterns: ['node_modules/', 'coverage/', 'dist/', 'build/', '*.min.js']
};
