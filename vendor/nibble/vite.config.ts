import vue from '@vitejs/plugin-vue'
import inertia from '@inertiajs/vite'
import tailwindcss from '@tailwindcss/vite'
import { existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

const siteRoot = process.cwd()

// The order Nibble.config uses: the environment, then the site's settings. Tests follow the settings alone, as the
// Rails test environment does, so a shell's NIBBLE_THEME can't build one theme for tests of another.
function activeTheme(): string {
  const named = process.env.RAILS_ENV === 'test' ? '' : process.env.NIBBLE_THEME
  if (named) return named
  try {
    // Nibble's record of the site follows its settings in the same file, and names a theme of its own.
    const settings = readFileSync(resolve(siteRoot, 'config/nibble.yml'), 'utf8').split(/^# Written by Nibble/m)[0]
    const setting = settings.match(/^\s*theme:\s*["']?([a-z0-9_]+)["']?\s*$/m)
    if (setting) return setting[1]
  } catch {
    // Not installed yet.
  }
  return 'crumbs'
}

const theme = activeTheme()
// A site's own theme first, then one that ships with Nibble.
const themeDir =
  [resolve(siteRoot, 'site/themes', theme), resolve(import.meta.dirname, 'themes', theme)].find((dir) => existsSync(dir)) ??
  resolve(siteRoot, 'site/themes', theme)

export default defineConfig(({ command, isSsrBuild }) => ({
  resolve: {
    alias: {
      '@theme': themeDir,
      '@site': resolve(siteRoot, 'site'),
      '@nibble': resolve(import.meta.dirname, 'frontend/nibble'),
      '@nibble-cp': resolve(import.meta.dirname, 'frontend/nibble-cp'),
      '@': resolve(import.meta.dirname, 'frontend/nibble-cp'),
      // Find and replace has no regex mode, so its 868K RE2 engine is stubbed out rather than bundled.
      re2js: resolve(import.meta.dirname, 'frontend/nibble-cp/lib/stubs/re2js.ts'),
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
    {
      // The theme and site/ sit outside Vite's root, so a view or block added to them would otherwise stay invisible to
      // the page globs until the dev server restarts.
      name: 'nibble-watch-site',
      configureServer(server) {
        server.watcher.add([themeDir, resolve(siteRoot, 'site')])
      },
    },
    tailwindcss(),
    RubyPlugin(),
    inertia({ ssr: 'ssr/ssr.ts' }),
    vue({ template: { compilerOptions: { isCustomElement: (tag) => tag.startsWith('cropper-') } } }),
  ],
}))
