import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [vue()],
  test: { include: ['**/*.test.ts', '../themes/*/__tests__/**/*.test.ts'] },
})
