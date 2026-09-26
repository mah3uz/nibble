import { createInertiaApp } from '@inertiajs/vue3'
import { defineAsyncComponent } from 'vue'
import { installHistoryGuard } from '../nibble-cp/lib/history-guard'
import { inertiaDefaults, layoutFor } from '../nibble-cp/lib/inertia-shared'
import { resolvePage } from '../nibble-cp/lib/resolve-page'

// CMS layouts load on demand so public pages don't download the Control Plane (sidebar, reka-ui).
const CpLayout = defineAsyncComponent(() => import('../nibble-cp/layouts/CpLayout.vue'))
const AuthLayout = defineAsyncComponent(() => import('../nibble-cp/layouts/AuthLayout.vue'))

installHistoryGuard()

createInertiaApp({
  resolve: resolvePage,
  layout: layoutFor(CpLayout, AuthLayout),
  defaults: inertiaDefaults,
})
