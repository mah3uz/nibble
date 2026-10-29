import vue from '@vitejs/plugin-vue'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [vue()],
  resolve: { alias: { '@': fileURLToPath(new URL('./nibble-cp', import.meta.url)) } },
  test: { include: ['**/*.test.ts', '../themes/*/__tests__/**/*.test.ts'] },
})
