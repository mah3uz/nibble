import { createInertiaApp } from '@inertiajs/vue3'
import AdminLayout from '../layouts/AdminLayout.vue'
import AuthLayout from '../layouts/AuthLayout.vue'
import { isThemePage, resolvePage, themeLayout } from '../lib/resolve-page'

// Wrapped by the @inertiajs/vite plugin into an SSR server (production: `bin/vite ssr`;
// development: served by the Vite dev server). Keep page resolution identical to inertia.ts (which
// loads the CMS layouts lazily; the server imports them directly).
createInertiaApp({
  resolve: resolvePage,
  // Theme views use the theme's layouts; CMS pages use the admin (or sign-in) layout.
  layout: (name, page) =>
    isThemePage(name) ? themeLayout(page) : name.startsWith('admin/auth/') ? AuthLayout : AdminLayout,
})
