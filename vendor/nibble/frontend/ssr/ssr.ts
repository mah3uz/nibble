import type { Page } from '@inertiajs/core'
import { createInertiaApp } from '@inertiajs/vue3'
import createServer from '@inertiajs/vue3/server'
import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import CpLayout from '../nibble-cp/layouts/CpLayout.vue'
import AuthLayout from '../nibble-cp/layouts/AuthLayout.vue'
import { inertiaDefaults, layoutFor } from '../nibble-cp/lib/inertia-shared'
import { resolvePage } from '../nibble-cp/lib/resolve-page'

// @inertiajs/vite would write this bootstrap for us, but only ever on its fixed port. We write it so the
// port can move, which is what lets the smoke test run while a dev server holds the usual one.
// Without page and render in the options, TypeScript picks the client overload, which returns void. On a
// server the same call returns the render function below.
type RenderPage = (page: Page, to: typeof renderToString) => Promise<{ head: string[]; body: string }>

const render = (await createInertiaApp({
  resolve: resolvePage,
  layout: layoutFor(CpLayout, AuthLayout),
  defaults: inertiaDefaults,

  // Vue drops only the subtree that threw, so say which view failed.
  setup({ App, props, plugin }) {
    const app = createSSRApp({ render: () => h(App, props) })
    app.use(plugin)
    app.config.errorHandler = (error, _instance, info) => {
      const page = props.initialPage
      console.error(`[ssr] ${page.component} failed while rendering ${page.url} (${info})`)
      console.error(error)
    }
    return app
  },
})) as unknown as RenderPage

declare const process: { env: Record<string, string | undefined> }

createServer((page) => render(page, renderToString), {
  port: Number(process.env.INERTIA_SSR_PORT) || 13714,
})
