import vue from '@vitejs/plugin-vue'
import inertia from '@inertiajs/vite'
import tailwindcss from '@tailwindcss/vite'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

// The order Nibble.config uses: the site's settings first, then the environment.
function activeTheme(): string {
  try {
    const settings = readFileSync(resolve(import.meta.dirname, 'config/nibble.yml'), 'utf8')
    const named = settings.match(/^\s*theme:\s*["']?([a-z0-9_]+)["']?\s*$/m)
    if (named) return named[1]
  } catch {
    // Not installed yet.
  }
  return process.env.NIBBLE_THEME || 'crumbs'
}

const theme = activeTheme()

export default defineConfig(({ command, isSsrBuild }) => ({
  resolve: {
    alias: {
      '@theme': resolve(import.meta.dirname, 'themes', theme),
      '@site': resolve(import.meta.dirname, 'site'),
      '@nibble': resolve(import.meta.dirname, 'app/frontend/nibble'),
      '@nibble-admin': resolve(import.meta.dirname, 'app/frontend/nibble-admin'),
      '@': resolve(import.meta.dirname, 'app/frontend/nibble-admin'),
      // Find and replace has no regex mode, so its 868K RE2 engine is stubbed out rather than bundled.
      re2js: resolve(import.meta.dirname, 'app/frontend/nibble-admin/lib/stubs/re2js.ts'),
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
