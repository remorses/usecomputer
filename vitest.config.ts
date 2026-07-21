// Vitest config for usecomputer parser and bridge unit tests.
// fileParallelism is disabled because listen tests use a global CGEventTap
// that captures all input events, including those from other test files.

import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
    fileParallelism: false,
  },
})
