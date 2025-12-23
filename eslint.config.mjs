// @ts-nocheck
import eslint from '@eslint/js'
import eslintPluginPrettierRecommended from 'eslint-plugin-prettier/recommended'
import globals from 'globals'
import tseslint from 'typescript-eslint'
import eslintPluginImport from 'eslint-plugin-import'
import eslintPluginJsdoc from 'eslint-plugin-jsdoc'
import path from 'path'
import { fileURLToPath } from 'url'
import { createRequire } from 'module'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const require = createRequire(import.meta.url)

const customRule = require('./scripts/eslint-rules/require-logger-in-catch.js')

// Define base rules
const baseRules = {
  // Import rules
  'import/order': [
    'error',
    {
      groups: ['builtin', 'external', 'internal', 'parent', 'sibling', 'index'],
      'newlines-between': 'always',
      alphabetize: {
        order: 'asc',
        caseInsensitive: true,
      },
    },
  ],
  'import/no-unresolved': 'error',
  'import/no-internal-modules': [
    'error',
    {
      allow: [
        // Allow imports from index files
        '**/index',
        '**/index.ts',
        '**/index.js',
        // Allow direct imports of module files
        '@*/**/*.module',
        '@*/**/*.module.ts',
        '@*/**/*.module.js',
        // Allow direct imports of service files
        '@*/**/*.service',
        '@*/**/*.service.ts',
        '@*/**/*.service.js',
        // Allow imports from specific patterns that should be allowed
        '@application/*',
        '@domain/*',
        '@infra/*',
        '@interfaces/*',
        '@config/*',
        '@common/*',
      ],
    },
  ],
  'no-duplicate-imports': 'error',
  // JSDoc rules
  'jsdoc/require-jsdoc': [
    'error',
    {
      publicOnly: true,
      require: {
        FunctionDeclaration: true,
        MethodDefinition: true,
        ClassDeclaration: true,
      },
    },
  ],
  'jsdoc/require-returns': 'error',
  'jsdoc/require-param': 'error',
  'jsdoc/require-param-description': 'error',
  'jsdoc/require-returns-description': 'error',
  // TypeScript rules
  '@typescript-eslint/no-unused-vars': 'error',
  '@typescript-eslint/no-explicit-any': 'error',
  '@typescript-eslint/prefer-nullish-coalescing': 'error',
  '@typescript-eslint/no-unsafe-assignment': 'error',
  '@typescript-eslint/no-unsafe-call': 'error',
  '@typescript-eslint/no-unsafe-member-access': 'error',
  '@typescript-eslint/no-unsafe-return': 'error',
  // Member ordering
  '@typescript-eslint/member-ordering': [
    'error',
    {
      default: {
        memberTypes: ['signature', 'field', 'constructor', 'method'],
        order: 'as-written',
      },
    },
  ],
  // Naming conventions
  '@typescript-eslint/naming-convention': [
    'error',
    {
      selector: 'interface',
      format: ['PascalCase'],
      filter: { regex: 'Repository$', match: true },
      custom: { regex: '^I[A-Z].*Repository$', match: true },
    },
    {
      selector: 'interface',
      format: ['PascalCase'],
      filter: { regex: 'Service$', match: true },
      custom: { regex: '^I[A-Z].*Service$', match: true },
    },
    {
      selector: 'interface',
      format: ['PascalCase'],
      filter: { regex: '^(?!.*(Repository|Service)$).*$', match: true },
      custom: { regex: '^I[A-Z]', match: false },
    },
    { selector: 'class', format: ['PascalCase'] },
    {
      selector: 'variable',
      modifiers: ['const', 'global'],
      format: ['UPPER_CASE'],
      custom: { regex: '^[A-Z0-9_]+$', match: true },
    },
    { selector: 'variable', format: ['camelCase'] },
    { selector: 'function', format: ['camelCase'] },
    { selector: 'objectLiteralProperty', format: ['camelCase', 'snake_case'] },
  ],
}

export default tseslint.config(
  {
    ignores: [
      'eslint.config.mjs',
      'scripts/**',
      'dist/**',
      'node_modules/**',
      'coverage/**',
      '*.js',
      '*.d.ts',
    ],
  },
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  eslintPluginPrettierRecommended,
  {
    languageOptions: {
      globals: {
        ...globals.node,
      },
      parserOptions: {
        project: './tsconfig.json',
        tsconfigRootDir: __dirname,
      },
    },
    plugins: {
      '@typescript-eslint': tseslint.plugin,
      import: eslintPluginImport,
      jsdoc: eslintPluginJsdoc,
      'require-logger-in-catch': {
        rules: {
          'require-logger-in-catch': customRule,
        },
      },
    },
    settings: {
      'import/resolver': {
        typescript: {
          alwaysTryTypes: true,
          project: './tsconfig.json',
        },
      },
    },
    rules: {
      ...baseRules,
      'require-logger-in-catch/require-logger-in-catch': 'error',
    },
  },
  {
    files: ['src/__tests__/**/*.ts'],
    rules: {
      ...baseRules,
      'jsdoc/require-jsdoc': 'off',
      'jsdoc/require-returns': 'off',
      'jsdoc/require-param': 'off',
      'jsdoc/require-param-description': 'off',
      'jsdoc/require-returns-description': 'off',
      'require-logger-in-catch/require-logger-in-catch': 'off',
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-unsafe-assignment': 'off',
      '@typescript-eslint/no-unsafe-call': 'off',
      '@typescript-eslint/no-unsafe-member-access': 'off',
      '@typescript-eslint/no-unsafe-return': 'off',
      '@typescript-eslint/member-ordering': 'off',
      '@typescript-eslint/naming-convention': 'off',
    },
  },
)
