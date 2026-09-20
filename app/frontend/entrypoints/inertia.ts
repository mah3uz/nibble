import { createInertiaApp } from '@inertiajs/vue3'
import { defineAsyncComponent } from 'vue'
import { installHistoryGuard } from '../lib/history-guard'
import { inertiaDefaults, layoutFor } from '../lib/inertia-shared'
import { resolvePage } from '../lib/resolve-page'

// CMS layouts load on demand so public pages don't download the admin UI (sidebar, reka-ui): 7.5.
const AdminLayout = defineAsyncComponent(() => import('../layouts/AdminLayout.vue'))
const AuthLayout = defineAsyncComponent(() => import('../layouts/AuthLayout.vue'))

installHistoryGuard()

createInertiaApp({
  resolve: resolvePage,
  layout: layoutFor(AdminLayout, AuthLayout),
  defaults: inertiaDefaults,
})
