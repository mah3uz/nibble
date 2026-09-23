import type { Page } from '@inertiajs/core'
import type { DefineComponent } from 'vue'
import { find, pickCpPage } from './pick-page'

const appPages = import.meta.glob<{ default: DefineComponent }>('../pages/**/*.vue')
const sitePages = import.meta.glob<{ default: DefineComponent }>('@site/cp/pages/**/*.vue')
const themeViews = import.meta.glob<{ default: DefineComponent }>(['@theme/views/**/*.vue', '!@theme/views/sets/**'])
const themeLayouts = import.meta.glob<DefineComponent>('@theme/layouts/*.vue', { eager: true, import: 'default' })
const themeSets = import.meta.glob<DefineComponent>('@theme/views/sets/*.vue', { eager: true, import: 'default' })

const THEME_PREFIX = 'theme/'

export function isThemePage(name: string) {
  return name.startsWith(THEME_PREFIX)
}

export async function resolvePage(name: string) {
  const loader = isThemePage(name)
    ? find(themeViews, `/views/${name.slice(THEME_PREFIX.length)}.vue`)
    : pickCpPage(name, sitePages, appPages)
  if (!loader) throw new Error(`Page not found: ${name}`)
  return (await loader()).default
}

export function resolveSet(type: string) {
  return find(themeSets, `/sets/${type}.vue`)
}

export function themeLayout(page: Page) {
  const layout = typeof page.props.layout === 'string' ? page.props.layout : 'default'
  return find(themeLayouts, `/layouts/${layout}.vue`) ?? find(themeLayouts, '/layouts/default.vue')
}
