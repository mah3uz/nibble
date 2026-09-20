import { createInertiaApp } from '@inertiajs/vue3'
import { defineAsyncComponent } from 'vue'
import { installHistoryGuard } from '../lib/history-guard'
import { isThemePage, resolvePage, themeLayout } from '../lib/resolve-page'

// CMS layouts load on demand so public pages don't download the admin UI (sidebar, reka-ui): 7.5.
const AdminLayout = defineAsyncComponent(() => import('../layouts/AdminLayout.vue'))
const AuthLayout = defineAsyncComponent(() => import('../layouts/AuthLayout.vue'))

installHistoryGuard()

createInertiaApp({
  resolve: resolvePage,
  // Theme views use the theme's layouts; CMS pages use the admin (or sign-in) layout.
  layout: (name, page) =>
    isThemePage(name) ? themeLayout(page) : name.startsWith('admin/auth/') ? AuthLayout : AdminLayout,

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => {
      return { queryStringArrayFormat: 'brackets' }
    },
  },
})
