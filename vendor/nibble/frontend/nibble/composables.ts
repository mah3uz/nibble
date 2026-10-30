import { usePage } from '@inertiajs/vue3'
import { computed } from 'vue'
import type { NavigationItem, NavigationMenus, SiteProps } from './types'

export function useSite() {
  const page = usePage<{ site: SiteProps }>()
  return computed(() => page.props.site)
}

export function useGlobals<T = Record<string, unknown>>(handle: string) {
  const site = useSite()
  return computed(() => (site.value?.globals?.[handle] ?? {}) as T)
}

export function useNavigation<H extends string>(handle: H) {
  const site = useSite()
  return computed(
    () =>
      (site.value?.navigation?.[handle] ?? []) as (H extends keyof NavigationMenus
        ? NavigationMenus[H]
        : NavigationItem)[],
  )
}

export function useLocale() {
  const site = useSite()
  return computed(() => site.value?.locale ?? 'en')
}
