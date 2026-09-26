import type { Page } from '@inertiajs/core'
import type { Component } from 'vue'
import { isThemePage, themeLayout } from './resolve-page'

// One app started twice: only the lazily loaded layouts differ.
export function layoutFor(cpLayout: Component, authLayout: Component) {
  return (name: string, page: Page) =>
    isThemePage(name) ? themeLayout(page) : name.startsWith('cp/auth/') ? authLayout : cpLayout
}

export const inertiaDefaults = {
  form: {
    forceIndicesArrayFormatInFormData: false,
    withAllErrors: true,
  },
  visitOptions: () => ({ queryStringArrayFormat: 'brackets' as const }),
}
