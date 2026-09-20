import { usePage } from '@inertiajs/vue3'
import { computed } from 'vue'
import type { Link, SiteProps } from './types'

export function useSite() {
  const page = usePage<{ site: SiteProps }>()
  return computed(() => page.props.site)
}

export function useGlobals<T = Record<string, unknown>>(handle: string) {
  const site = useSite()
  return computed(() => (site.value?.globals?.[handle] ?? {}) as T)
}

export function useNavigation(handle: string) {
  const site = useSite()
  return computed<Link[]>(() => site.value?.navigation?.[handle] ?? [])
}

export function useLocale() {
  const site = useSite()
  return computed(() => site.value?.locale ?? 'en')
}
