import vue from '@vitejs/plugin-vue'
import inertia from '@inertiajs/vite'
import tailwindcss from '@tailwindcss/vite'
import { resolve } from 'node:path'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

const theme = process.env.NIBBLE_THEME || 'crumbs'

export default defineConfig(({ command, isSsrBuild }) => ({
  resolve: {
    alias: {
      '@theme': resolve(import.meta.dirname, 'themes', theme),
      '@site': resolve(import.meta.dirname, 'site'),
      '@nibble': resolve(import.meta.dirname, 'app/frontend/nibble'),
      '@nibble-admin': resolve(import.meta.dirname, 'app/frontend/nibble-admin'),
      re2js: resolve(import.meta.dirname, 'app/frontend/lib/stubs/re2js.ts'),
    },
  },
  ssr: {
    // Bundle dependencies into ssr.js for builds so the Docker image needs only the Node runtime, not node_modules.
    noExternal: command === 'build' ? true : undefined,
  },
  build: isSsrBuild
    ? undefined
    : {
        rolldownOptions: {
          output: {
            // Vue in its own chunk keeps shared bundler helpers out of admin UI chunks public pages would otherwise load.
            codeSplitting: {
              groups: [{ name: 'vue', test: /node_modules[\\/](@vue|vue)[\\/]/ }],
            },
          },
        },
      },
  plugins: [
    tailwindcss(),
    RubyPlugin(),
    inertia({ ssr: 'ssr/ssr.ts' }),
    vue({ template: { compilerOptions: { isCustomElement: (tag) => tag.startsWith('cropper-') } } }),
  ],
}))
