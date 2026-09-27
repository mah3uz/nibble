import vue from '@vitejs/plugin-vue'
import inertia from '@inertiajs/vite'
import tailwindcss from '@tailwindcss/vite'
import { appendFileSync, existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { defineConfig, type Plugin } from 'vite'
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

// Vite's build errors, and errors in the browser sent over the HMR socket, join the log the developer tools read.
function devLog(): Plugin {
  const file = resolve(siteRoot, 'log/nibble-dev.jsonl')
  let last = 0
  let recent: number[] = []
  const plain = (text: unknown) =>
    String(text ?? '')
      .replace(/\u001b\[[0-9;]*m/g, '')
      .slice(0, 2000)
  const write = (event: Record<string, unknown>) => {
    const now = Date.now()
    recent = recent.filter((time) => time > now - 60_000)
    if (recent.length >= 60) return
    recent.push(now)
    last = Math.max(now * 1000, last + 1)
    try {
      appendFileSync(file, JSON.stringify({ ...event, id: last, time: new Date(now).toISOString() }) + '\n')
    } catch {
      // The log folder is missing until Rails first starts.
    }
  }
  return {
    name: 'nibble-dev-log',
    apply: 'serve',
    configureServer(server) {
      const logger = server.config.logger
      const error = logger.error.bind(logger)
      logger.error = (message, options) => {
        // Vite forwards the browser's console here too; the page reports those itself, with its URL and stack.
        if (plain(message).startsWith('[console.')) return error(message, options)
        const cause = options?.error as (Error & { id?: string; loc?: { file?: string; line?: number } }) | undefined
        const at = cause?.loc?.file ? `${cause.loc.file}:${cause.loc.line ?? ''}` : cause?.id
        write({
          kind: 'vite',
          message: plain(cause?.message ?? message),
          at,
          stack: cause?.stack?.split('\n').slice(0, 15),
        })
        error(message, options)
      }
      // Server-side rendering runs in this process in development; ssr/ssr.ts reports through this when it exists.
      ;(globalThis as { __nibbleSsrError?: unknown }).__nibbleSsrError = (
        cause: Error,
        page: { component?: string; url?: string; info?: string },
      ) => {
        server.ssrFixStacktrace(cause)
        const frame = cause.stack?.split('\n').find((line) => line.includes(siteRoot) && !line.includes('node_modules'))
        write({
          kind: 'ssr',
          component: page.component,
          url: plain(page.url),
          during: page.info,
          message: plain(cause.message),
          at: frame
            ?.trim()
            .replace(/^at .*?\(?(\/.*?)\)?$/, '$1')
            .replace(`${siteRoot}/`, ''),
          stack: cause.stack?.split('\n').slice(0, 15),
        })
      }
      server.ws.on('nibble:browser-error', (data: Record<string, unknown>) => {
        write({
          kind: 'browser',
          source: plain(data.source),
          message: plain(data.message),
          url: plain(data.url),
          stack: Array.isArray(data.stack) ? data.stack.slice(0, 15).map(plain) : undefined,
        })
      })
    },
  }
}

const theme = activeTheme()
// A site's own theme first, then one that ships with Nibble.
const themeDir =
  [resolve(siteRoot, 'site/themes', theme), resolve(import.meta.dirname, 'themes', theme)].find((dir) =>
    existsSync(dir),
  ) ?? resolve(siteRoot, 'site/themes', theme)

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
    devLog(),
    tailwindcss(),
    RubyPlugin(),
    inertia({ ssr: 'ssr/ssr.ts' }),
    vue({ template: { compilerOptions: { isCustomElement: (tag) => tag.startsWith('cropper-') } } }),
  ],
}))
