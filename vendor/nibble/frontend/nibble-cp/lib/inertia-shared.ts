import type { Page } from '@inertiajs/core'
import type { Component } from 'vue'
import { setFormatLocale } from './format'
import { isThemePage, themeLayout } from './resolve-page'

// One app started twice: only the lazily loaded layouts differ.
export function layoutFor(cpLayout: Component, authLayout: Component) {
  return (name: string, page: Page) => {
    if (isThemePage(name)) return themeLayout(page)
    setFormatLocale((page.props.cp as { format_locale?: string } | undefined)?.format_locale)
    return /^cp\/(auth|oauth)\//.test(name) ? authLayout : cpLayout
  }
}

export const inertiaDefaults = {
  form: {
    forceIndicesArrayFormatInFormData: false,
    withAllErrors: true,
  },
  visitOptions: () => ({ queryStringArrayFormat: 'brackets' as const }),
}
