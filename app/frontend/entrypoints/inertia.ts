import { createInertiaApp } from '@inertiajs/vue3'
import { defineAsyncComponent } from 'vue'
import { installHistoryGuard } from '../nibble-admin/lib/history-guard'
import { inertiaDefaults, layoutFor } from '../nibble-admin/lib/inertia-shared'
import { resolvePage } from '../nibble-admin/lib/resolve-page'

// CMS layouts load on demand so public pages don't download the admin UI (sidebar, reka-ui): 7.5.
const AdminLayout = defineAsyncComponent(() => import('../nibble-admin/layouts/AdminLayout.vue'))
const AuthLayout = defineAsyncComponent(() => import('../nibble-admin/layouts/AuthLayout.vue'))

installHistoryGuard()

createInertiaApp({
  resolve: resolvePage,
  layout: layoutFor(AdminLayout, AuthLayout),
  defaults: inertiaDefaults,
})
