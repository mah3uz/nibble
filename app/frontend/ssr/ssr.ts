import { createInertiaApp } from '@inertiajs/vue3'
import { createSSRApp, h } from 'vue'
import AdminLayout from '../nibble-admin/layouts/AdminLayout.vue'
import AuthLayout from '../nibble-admin/layouts/AuthLayout.vue'
import { inertiaDefaults, layoutFor } from '../nibble-admin/lib/inertia-shared'
import { resolvePage } from '../nibble-admin/lib/resolve-page'

// Wrapped by @inertiajs/vite into an SSR server; the layouts load eagerly here, not lazily.
createInertiaApp({
  resolve: resolvePage,
  layout: layoutFor(AdminLayout, AuthLayout),
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
})
